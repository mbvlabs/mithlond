# Install Grafana Alloy
log_message "Installing Grafana Alloy..."

# Set default version if not provided
ALLOY_VERSION=${ALLOY_VERSION:-"1.9.1"}

# Create alloy user
log_message "Creating alloy user..."
useradd --system --no-create-home --shell /bin/false alloy || log_message "User alloy already exists"

# Create necessary directories
log_message "Creating alloy directories..."
mkdir -p /etc/alloy
mkdir -p /var/lib/alloy
mkdir -p /var/log/alloy
chown -R alloy:alloy /var/lib/alloy
chown -R alloy:alloy /var/log/alloy
chown -R alloy:alloy /etc/alloy

# Download and install Alloy binary
log_message "Downloading Grafana Alloy v${ALLOY_VERSION}..."
cd /tmp
wget -q https://github.com/grafana/alloy/releases/download/v${ALLOY_VERSION}/alloy-linux-amd64.zip

if [ $? -ne 0 ]; then
    log_message "ERROR: Failed to download Alloy binary"
    exit 1
fi

log_message "Extracting and installing Alloy..."
unzip -q alloy-linux-amd64.zip
mv alloy-linux-amd64 /usr/local/bin/alloy
chmod +x /usr/local/bin/alloy
rm -f alloy-linux-amd64.zip

# Create Alloy configuration
log_message "Creating Alloy configuration..."
cat > /etc/alloy/config.alloy << 'EOF'
// Alloy configuration for telemetry collection and forwarding

// Prometheus metrics scraping and forwarding
prometheus.scrape "default" {
  targets = [
    {"__address__" = "localhost:9090"},
    {"__address__" = "localhost:9100"},
    {"__address__" = "localhost:3100"},
    {"__address__" = "localhost:3200"},
  ]
  forward_to = [prometheus.remote_write.default.receiver]
}

prometheus.remote_write "default" {
  endpoint {
    url = "http://localhost:9090/api/v1/write"
  }
}

// Loki log collection and forwarding
loki.source.file "default" {
  targets = [
    {__path__ = "/var/log/*.log"},
    {__path__ = "/var/log/syslog"},
    {__path__ = "/var/log/auth.log"},
  ]
  forward_to = [loki.write.default.receiver]
}

loki.write "default" {
  endpoint {
    url = "http://localhost:3100/loki/api/v1/push"
  }
}

// OTLP receiver for traces
otelcol.receiver.otlp "default" {
  grpc {
    endpoint = "0.0.0.0:4317"
  }
  http {
    endpoint = "0.0.0.0:4318"
  }
  output {
    traces  = [otelcol.exporter.otlp.tempo.input]
  }
}

otelcol.exporter.otlp "tempo" {
  client {
    endpoint = "http://localhost:4317"
    tls {
      insecure = true
    }
  }
}

// System metrics collection
prometheus.exporter.unix "default" {
}

prometheus.scrape "unix" {
  targets    = prometheus.exporter.unix.default.targets
  forward_to = [prometheus.remote_write.default.receiver]
}
EOF

chown alloy:alloy /etc/alloy/config.alloy

# Create systemd service
log_message "Creating Alloy systemd service..."
cat > /etc/systemd/system/alloy.service << EOF
[Unit]
Description=Grafana Alloy
Documentation=https://grafana.com/docs/alloy/
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=alloy
Group=alloy
ExecStart=/usr/local/bin/alloy run /etc/alloy/config.alloy
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=alloy
KillMode=mixed
KillSignal=SIGINT

[Install]
WantedBy=multi-user.target
EOF

# Enable and start Alloy service
log_message "Enabling and starting Alloy service..."
systemctl daemon-reload
systemctl enable alloy
systemctl start alloy

# Verify installation
log_message "Verifying Alloy installation..."
sleep 5
if systemctl is-active --quiet alloy; then
    log_message "Alloy service is running successfully"
    log_message "Alloy is collecting telemetry data and forwarding to backends"
    log_message "OTLP endpoints available at: grpc://localhost:4317, http://localhost:4318"
else
    log_message "ERROR: Alloy service failed to start"
    systemctl status alloy
    exit 1
fi

log_message "Finished Grafana Alloy installation at $(date)."
