# Install Node Exporter
log_message "Installing Node Exporter..."

# Set default version if not provided
NODE_EXPORTER_VERSION=${NODE_EXPORTER_VERSION:-"1.8.2"}

# Create node_exporter user
log_message "Creating node_exporter user..."
useradd --no-create-home --shell /bin/false node_exporter

# Download and install Node Exporter
log_message "Downloading Node Exporter v${NODE_EXPORTER_VERSION}..."
cd /tmp
wget https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz

if [ $? -ne 0 ]; then
    log_message "ERROR: Failed to download Node Exporter v${NODE_EXPORTER_VERSION}"
    exit 1
fi

log_message "Extracting Node Exporter..."
tar xvf node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz

# Install binary
log_message "Installing Node Exporter binary..."
cp node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter /usr/local/bin/
chown node_exporter:node_exporter /usr/local/bin/node_exporter

# Clean up
rm -rf /tmp/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64*

# Create systemd service file
log_message "Creating Node Exporter systemd service..."
cat > /etc/systemd/system/node_exporter.service << EOF
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and start service
log_message "Starting Node Exporter service..."
systemctl daemon-reload
systemctl enable node_exporter
systemctl start node_exporter

# Check if service started successfully
if systemctl is-active --quiet node_exporter; then
    log_message "Node Exporter service started successfully"
else
    log_message "ERROR: Node Exporter service failed to start"
    systemctl status node_exporter
    exit 1
fi

# Note: Port 9100 not opened to internet for security
# Node Exporter will be accessible locally for Prometheus to scrape

log_message "Node Exporter installation completed successfully!"
log_message "Node Exporter is running on port 9100"
log_message "Metrics available at: http://localhost:9100/metrics"