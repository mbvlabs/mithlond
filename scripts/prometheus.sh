#!/bin/bash

set -euo pipefail

PROMETHEUS_VERSION="${PROMETHEUS_VERSION:-latest}"
PROMETHEUS_USER="prometheus"
PROMETHEUS_GROUP="prometheus"
PROMETHEUS_HOME="/var/lib/prometheus"
PROMETHEUS_CONFIG_DIR="/etc/prometheus"
PROMETHEUS_BIN_DIR="/usr/local/bin"
PROMETHEUS_SERVICE_FILE="/etc/systemd/system/prometheus.service"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1" >&2
    exit 1
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
    fi
}

get_latest_version() {
    if [[ "$PROMETHEUS_VERSION" == "latest" ]]; then
        log "Fetching latest Prometheus version..."
        PROMETHEUS_VERSION=$(curl -s https://api.github.com/repos/prometheus/prometheus/releases/latest | grep '"tag_name":' | cut -d'"' -f4 | sed 's/^v//')
        log "Latest version: $PROMETHEUS_VERSION"
    fi
}

create_user() {
    log "Creating prometheus user and group..."
    if ! getent group $PROMETHEUS_GROUP >/dev/null 2>&1; then
        groupadd --system $PROMETHEUS_GROUP
    fi
    
    if ! getent passwd $PROMETHEUS_USER >/dev/null 2>&1; then
        useradd -r -g $PROMETHEUS_GROUP -d $PROMETHEUS_HOME -s /sbin/nologin $PROMETHEUS_USER
    fi
}

create_directories() {
    log "Creating directories..."
    mkdir -p $PROMETHEUS_CONFIG_DIR
    mkdir -p $PROMETHEUS_HOME
    mkdir -p $PROMETHEUS_CONFIG_DIR/consoles
    mkdir -p $PROMETHEUS_CONFIG_DIR/console_libraries
    
    chown $PROMETHEUS_USER:$PROMETHEUS_GROUP $PROMETHEUS_CONFIG_DIR
    chown $PROMETHEUS_USER:$PROMETHEUS_GROUP $PROMETHEUS_HOME
}

download_prometheus() {
    log "Downloading Prometheus v$PROMETHEUS_VERSION..."
    
    local download_url="https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz"
    local temp_dir="/tmp/prometheus-install"
    
    mkdir -p $temp_dir
    cd $temp_dir
    
    wget -q "$download_url" -O prometheus.tar.gz || error "Failed to download Prometheus"
    tar -xzf prometheus.tar.gz --strip-components=1 || error "Failed to extract Prometheus"
}

install_binaries() {
    log "Installing Prometheus binaries..."
    
    cp prometheus $PROMETHEUS_BIN_DIR/
    cp promtool $PROMETHEUS_BIN_DIR/
    
    chown $PROMETHEUS_USER:$PROMETHEUS_GROUP $PROMETHEUS_BIN_DIR/prometheus
    chown $PROMETHEUS_USER:$PROMETHEUS_GROUP $PROMETHEUS_BIN_DIR/promtool
    
    chmod +x $PROMETHEUS_BIN_DIR/prometheus
    chmod +x $PROMETHEUS_BIN_DIR/promtool
    
    cp -r consoles/* $PROMETHEUS_CONFIG_DIR/consoles/
    cp -r console_libraries/* $PROMETHEUS_CONFIG_DIR/console_libraries/
    
    chown -R $PROMETHEUS_USER:$PROMETHEUS_GROUP $PROMETHEUS_CONFIG_DIR/consoles
    chown -R $PROMETHEUS_USER:$PROMETHEUS_GROUP $PROMETHEUS_CONFIG_DIR/console_libraries
}

create_config() {
    log "Creating default Prometheus configuration..."
    
    cat > $PROMETHEUS_CONFIG_DIR/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
EOF
    
    chown $PROMETHEUS_USER:$PROMETHEUS_GROUP $PROMETHEUS_CONFIG_DIR/prometheus.yml
}

create_systemd_service() {
    log "Creating systemd service..."
    
    cat > $PROMETHEUS_SERVICE_FILE << EOF
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=$PROMETHEUS_USER
Group=$PROMETHEUS_GROUP
Type=simple
Restart=on-failure
RestartSec=5s
ExecStart=$PROMETHEUS_BIN_DIR/prometheus \\
    --config.file=$PROMETHEUS_CONFIG_DIR/prometheus.yml \\
    --storage.tsdb.path=$PROMETHEUS_HOME \\
    --web.console.templates=$PROMETHEUS_CONFIG_DIR/consoles \\
    --web.console.libraries=$PROMETHEUS_CONFIG_DIR/console_libraries \\
    --web.listen-address=0.0.0.0:9090 \\
    --web.enable-lifecycle

[Install]
WantedBy=multi-user.target
EOF
}

start_service() {
    log "Starting Prometheus service..."
    
    systemctl daemon-reload
    systemctl enable prometheus
    systemctl start prometheus
    
    sleep 3
    
    if systemctl is-active --quiet prometheus; then
        log "Prometheus service started successfully"
        log "Prometheus is available at http://localhost:9090"
    else
        error "Failed to start Prometheus service"
    fi
}

cleanup() {
    log "Cleaning up..."
    rm -rf /tmp/prometheus-install
}

main() {
    log "Starting Prometheus installation..."
    
    check_root
    get_latest_version
    create_user
    create_directories
    download_prometheus
    install_binaries
    create_config
    create_systemd_service
    start_service
    cleanup
    
    log "Prometheus installation completed successfully!"
    log "Version: $PROMETHEUS_VERSION"
    log "Service status: $(systemctl is-active prometheus)"
}

main "$@"

