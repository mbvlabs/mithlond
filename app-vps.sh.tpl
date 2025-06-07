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
USER_NAME=
SSH_PORT=

ADMIN_SSH_KEY=
USER_PASSWORD=

${base}
${fail2ban}
${docker}

log_message "Adding 'docker' admin groups..."
usermod -aG docker admin

systemctl daemon-reload

log_message "Finished VPS setup at $(date). The system will now reboot."
reboot
