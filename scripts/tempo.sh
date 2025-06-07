# Install Grafana Tempo
log_message "Installing Grafana Tempo..."

# Set default version if not specified
TEMPO_VERSION=${TEMPO_VERSION:-"2.6.1"}

# Create tempo user
log_message "Creating tempo user..."
useradd --system --shell /bin/false --home-dir /var/lib/tempo tempo || log_message "User tempo already exists"

# Create necessary directories
log_message "Creating tempo directories..."
mkdir -p /etc/tempo
mkdir -p /var/lib/tempo
mkdir -p /var/log/tempo
chown -R tempo:tempo /var/lib/tempo
chown -R tempo:tempo /var/log/tempo
chown -R tempo:tempo /etc/tempo

# Download and install Tempo binary
log_message "Downloading Grafana Tempo v${TEMPO_VERSION}..."
cd /tmp
wget -q https://github.com/grafana/tempo/releases/download/v${TEMPO_VERSION}/tempo_${TEMPO_VERSION}_linux_amd64.tar.gz

if [ $? -ne 0 ]; then
    log_message "ERROR: Failed to download Tempo binary"
    exit 1
fi

log_message "Extracting and installing Tempo..."
tar -xzf tempo_${TEMPO_VERSION}_linux_amd64.tar.gz
mv tempo-linux-amd64 /usr/local/bin/tempo
chmod +x /usr/local/bin/tempo
rm -f tempo_${TEMPO_VERSION}_linux_amd64.tar.gz

# Create Tempo configuration
log_message "Creating Tempo configuration..."
cat > /etc/tempo/tempo.yml << EOF
server:
  http_listen_port: 3200
  grpc_listen_port: 9095

distributor:
  receivers:
    otlp:
      protocols:
        grpc:
          endpoint: 0.0.0.0:4317
        http:
          endpoint: 0.0.0.0:4318

ingester:
  max_block_duration: 5m

compactor:
  compaction:
    block_retention: 1h

storage:
  trace:
    backend: local
    local:
      path: /var/lib/tempo/blocks
    wal:
      path: /var/lib/tempo/wal
    pool:
      max_workers: 100
      queue_depth: 10000

query_frontend:
  search:
    duration_slo: 5s
    throughput_bytes_slo: 1.073741824e+09
  trace_by_id:
    duration_slo: 5s

metrics_generator:
  registry:
    external_labels:
      source: tempo
      cluster: docker-compose
  storage:
    path: /var/lib/tempo/generator/wal
    remote_write:
      - url: http://localhost:9090/api/v1/write
        send_exemplars: true
EOF

chown tempo:tempo /etc/tempo/tempo.yml

# Create systemd service
log_message "Creating Tempo systemd service..."
cat > /etc/systemd/system/tempo.service << EOF
[Unit]
Description=Grafana Tempo
Documentation=https://grafana.com/docs/tempo/
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=tempo
Group=tempo
ExecStart=/usr/local/bin/tempo -config.file=/etc/tempo/tempo.yml
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=tempo
KillMode=mixed
KillSignal=SIGINT

[Install]
WantedBy=multi-user.target
EOF

# Note: Tempo ports will be handled by reverse proxy, no firewall rules needed

# Enable and start Tempo service
log_message "Enabling and starting Tempo service..."
systemctl daemon-reload
systemctl enable tempo
systemctl start tempo

# Verify installation
log_message "Verifying Tempo installation..."
sleep 5
if systemctl is-active --quiet tempo; then
    log_message "Tempo service is running successfully"
    log_message "Tempo API available at: http://localhost:3200"
else
    log_message "ERROR: Tempo service failed to start"
    systemctl status tempo
    exit 1
fi

log_message "Finished Grafana Tempo installation at $(date)."