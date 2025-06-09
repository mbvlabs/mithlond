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

${base}

${fail2ban}

${node_exporter}

${tempo}

${loki}

${prometheus}

${alloy}

${caddy}

systemctl daemon-reload

log_message "Finished VPS setup at $(date). The system will now reboot."
reboot
