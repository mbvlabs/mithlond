#!/bin/bash

# This script sets up a production-ready VPS with Prometheus monitoring.
# It includes security hardening, service configuration, and monitoring.
# It is designed to be run on a fresh Ubuntu/Debian system.

# Exit immediately if a command exits with a non-zero status.
set -e

# Use a log file for better tracking of the installation process
LOG_FILE="/var/log/vps_setup.log"
exec > >(tee -i $LOG_FILE) 2>&1
echo "Starting VPS setup at $(date)"
echo "Logging to $LOG_FILE"

# Function to display messages and log them
log_message() {
  echo "$(date) - $1"
}

# Define variables
USER_NAME="${user_name}"
SSH_PORT=${ssh_port}
SSH_KEY="${ssh_key}"
USER_PASSWORD=${user_password}
DOMAIN="${manager_domain}"
CLOUDFLARE_EMAIL=${cloudflare_email}

${base}

${fail2ban}

${docker}


# Generate basic auth hash for manager (username: manager, password: ${manager_password})
MANAGER_AUTH_HASH=$(echo -n "${manager_password}" | openssl passwd -apr1 -stdin)
MANAGER_AUTH_STRING="manager:$MANAGER_AUTH_HASH"

# Manager binary will be uploaded by Terraform provisioner
log_message "Manager binary will be installed by Terraform provisioner"

# Create systemd service file for manager
log_message "Creating systemd service file for manager"
cat > /etc/systemd/system/manager.service << EOF
[Unit]
Description=Application Manager Service
After=network.target docker.service
Requires=docker.service
StartLimitIntervalSec=0

[Service]
Type=simple
Restart=always
RestartSec=1
User=$USER_NAME
Group=$USER_NAME
ExecStart=/usr/local/bin/manager
Environment=API_USERNAME=${manager_username}
Environment=API_PASSWORD=${manager_password}
Environment=DOCKER_USERNAME=${docker_username}
Environment=DOCKER_PASSWORD=${docker_password}
WorkingDirectory=/home/$USER_NAME

[Install]
WantedBy=multi-user.target
EOF

# Enable manager service (but don't start it yet)
log_message "Enabling manager service"
systemctl daemon-reload
systemctl enable manager.service

sudo ufw allow 9090/tcp

${traefik}

# Configure Cloudflare environment variables for Traefik
log_message "Setting up Cloudflare environment for Traefik"
cat > "/home/$USER_NAME/traefik/.env" << EOF
CLOUDFLARE_EMAIL=${cloudflare_email}
CLOUDFLARE_API_KEY=${cloudflare_api_key}
MANAGER_AUTH_STRING=$MANAGER_AUTH_STRING
EOF
chown "$USER_NAME:$USER_NAME" "/home/$USER_NAME/traefik/.env"

# Configure manager service in Traefik
log_message "Configuring manager service routing in Traefik"
# Replace placeholders in all dynamic config files
for config_file in "/home/$USER_NAME/traefik/dynamic"/*.yml; do
    if [ -f "$config_file" ]; then
        sed -i "s|MANAGER_DOMAIN_PLACEHOLDER|$DOMAIN|g" "$config_file"
        sed -i "s|MANAGER_AUTH_PLACEHOLDER|$MANAGER_AUTH_STRING|g" "$config_file"
        chown "$USER_NAME:$USER_NAME" "$config_file"
    fi
done
log_message "Manager service configured for domain: $DOMAIN"

${docker_rollout}

log_message "Finished VPS setup at $(date). Remember to update configs and then reboot."
