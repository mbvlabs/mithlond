# Install Grafana Loki
log_message "Starting Loki installation..."

# Set default version if not provided
LOKI_VERSION=${LOKI_VERSION:-"3.4.1"}

log_message "Installing Loki version $LOKI_VERSION..."

# Create system user for Loki
log_message "Creating loki system user..."
useradd --system --no-create-home --shell /bin/false loki

# Create directories
log_message "Creating Loki directories..."
mkdir -p /opt/loki
mkdir -p /var/lib/loki/chunks
mkdir -p /var/lib/loki/rules
mkdir -p /etc/loki

# Download and install Loki binary
log_message "Downloading Loki binary..."
cd /tmp
wget "https://github.com/grafana/loki/releases/download/v${LOKI_VERSION}/loki-linux-amd64.zip"
unzip loki-linux-amd64.zip
mv loki-linux-amd64 /opt/loki/loki
chmod +x /opt/loki/loki
rm loki-linux-amd64.zip

# Create configuration file
log_message "Creating Loki configuration..."
cat > /etc/loki/loki.yaml << EOF
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096
  log_level: info

common:
  instance_addr: 127.0.0.1
  path_prefix: /var/lib/loki
  storage:
    filesystem:
      chunks_directory: /var/lib/loki/chunks
      rules_directory: /var/lib/loki/rules
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory

query_range:
  results_cache:
    cache:
      embedded_cache:
        enabled: true
        max_size_mb: 100

limits_config:
  retention_period: 744h
  ingestion_rate_mb: 16
  ingestion_burst_size_mb: 32
  per_stream_rate_limit: 3MB
  per_stream_rate_limit_burst: 15MB

schema_config:
  configs:
    - from: 2020-10-24
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h

ruler:
  storage:
    type: local
    local:
      directory: /var/lib/loki/rules
  rule_path: /var/lib/loki/rules
  ring:
    kvstore:
      store: inmemory
  enable_api: true
EOF

# Set ownership
log_message "Setting file permissions..."
chown -R loki:loki /opt/loki
chown -R loki:loki /var/lib/loki
chown -R loki:loki /etc/loki

# Create systemd service
log_message "Creating systemd service..."
cat > /etc/systemd/system/loki.service << EOF
[Unit]
Description=Loki log aggregation system
Documentation=https://grafana.com/docs/loki/
After=network.target

[Service]
Type=simple
User=loki
Group=loki
ExecStart=/opt/loki/loki -config.file=/etc/loki/loki.yaml
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal
SyslogIdentifier=loki
KillMode=mixed
KillSignal=SIGTERM

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
log_message "Enabling and starting Loki service..."
systemctl daemon-reload
systemctl enable loki
systemctl start loki

# Wait a moment for service to start
sleep 3

# Check service status
if systemctl is-active --quiet loki; then
    log_message "Loki service started successfully"
    log_message "Loki is listening on localhost:3100"
else
    log_message "ERROR: Failed to start Loki service"
    log_message "Check service status with: systemctl status loki"
    log_message "Check logs with: journalctl -u loki -f"
    exit 1
fi

log_message "Finished Loki installation at $(date)."
