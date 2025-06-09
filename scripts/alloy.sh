#!/bin/bash

log_message() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1"
}

ALLOY_VERSION=${ALLOY_VERSION:-"1.9.1"} # Default Alloy version

log_message "Starting Grafana Alloy installation script..."

log_message "Creating alloy group and user..."

groupadd --system alloy 2>/dev/null || true
useradd --system --no-create-home --shell /bin/false --gid alloy alloy 2>/dev/null || true
if ! id -u alloy >/dev/null 2>&1; then
    log_message "ERROR: Failed to create user alloy. Exiting."
    exit 1
else
    log_message "User alloy created or already exists."
fi


log_message "Creating alloy base directories and setting permissions..."
mkdir -p /etc/alloy
mkdir -p /var/lib/alloy/data
mkdir -p /var/log/alloy


log_message "Setting ownership and permissions for alloy directories..."
chown -R alloy:alloy /etc/alloy
chown -R alloy:alloy /var/lib/alloy
chown -R alloy:alloy /var/log/alloy


chmod 755 /etc/alloy
chmod 755 /var/lib/alloy
chmod 755 /var/lib/alloy/data
chmod 755 /var/log/alloy

chmod g+w /var/lib/alloy/data

log_message "Downloading Grafana Alloy v${ALLOY_VERSION}..."
cd /tmp || { log_message "ERROR: Failed to change directory to /tmp. Exiting."; exit 1; }

wget -q "https://github.com/grafana/alloy/releases/download/v${ALLOY_VERSION}/alloy-linux-amd64.zip"

if [ $? -ne 0 ]; then
    log_message "ERROR: Failed to download Alloy binary from v${ALLOY_VERSION}. Please check version and network connectivity."
    exit 1
fi

log_message "Extracting and installing Alloy..."
unzip -q alloy-linux-amd64.zip
sudo mv alloy-linux-amd64 /usr/local/bin/alloy
sudo chmod +x /usr/local/bin/alloy # Make the binary executable
rm -f alloy-linux-amd64.zip

# 5. Create Alloy configuration file
log_message "Creating Alloy configuration file at /etc/alloy/config.alloy..."
cat > /etc/alloy/config.alloy << 'EOF'
otelcol.receiver.otlp "default" {
  grpc {
    endpoint = "localhost:4320"
  }
  http {
    endpoint = "localhost:4321"
  }

  output {
    metrics = [otelcol.processor.batch.default.input]
    traces  = [otelcol.processor.batch.default.input]
  }
}

otelcol.processor.batch "default" {
  output {
    metrics = [otelcol.exporter.prometheus.default.input]
    traces  = [otelcol.exporter.otlp.tempo.input]
  }
}

otelcol.exporter.prometheus "default" {
  forward_to = [prometheus.remote_write.default.receiver]
}

prometheus.remote_write "default" {
  endpoint {
    url = "http://localhost:9090/api/v1/write"
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
EOF

# Set ownership of the config file to alloy user
sudo chown alloy:alloy /etc/alloy/config.alloy
# Set permissions for the config file (read/write for owner, read-only for group/others)
sudo chmod 644 /etc/alloy/config.alloy

# 6. Create systemd service file
log_message "Creating Alloy systemd service file at /etc/systemd/system/alloy.service..."
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
# Ensure --storage.path points to the directory we configured permissions for
ExecStart=/usr/local/bin/alloy run --storage.path=/var/lib/alloy/data /etc/alloy/config.alloy
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

# 7. Enable and start Alloy service
log_message "Reloading systemd daemon, enabling, and starting Alloy service..."
sudo systemctl daemon-reload
sudo systemctl enable alloy
# sudo systemctl start alloy
#
# # 8. Verify installation
# log_message "Verifying Alloy installation..."
# sleep 5 # Give some time for the service to start
#
# if systemctl is-active --quiet alloy; then
#     log_message "SUCCESS: Alloy service is running successfully!"
#     log_message "Alloy is configured to collect telemetry data and forward to backends."
#     log_message "OTLP endpoints available at: grpc://localhost:4317, http://localhost:4318"
#     log_message "Check logs with: journalctl -u alloy -f"
# else
#     log_message "ERROR: Alloy service failed to start."
#     log_message "Displaying Alloy service status for debugging:"
#     sudo systemctl status alloy
#     exit 1
# fi

log_message "Finished Grafana Alloy installation at $(date)."
