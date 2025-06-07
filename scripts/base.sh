# Update package lists and upgrade existing packages
log_message "Updating packages..."
apt-get update
apt-get -y upgrade

# Set the timezone
log_message "Setting timezone to Europe/Copenhagen..."
timedatectl set-timezone Europe/Copenhagen

# Create the 'admin' user
log_message "Creating user 'admin'..."
useradd -m -u 1000 -s /bin/bash $USER_NAME
usermod -aG sudo $USER_NAME || log_message "Failed to add user to sudo group"

# Generate a strong random password for the admin user
log_message "Setting a strong random password for admin user. Please save this password:"
echo "Admin Password: $USER_PASSWORD"
echo "$USER_NAME:$USER_PASSWORD" | chpasswd

# Configure sudo for 'admin' user
log_message "Configuring sudo for 'admin' (password required for sudo)..."

# For a production server, it's recommended to require a password for sudo.
# If you absolutely need NOPASSWD for specific commands, refine this rule.
echo "$USER_NAME ALL=(ALL) ALL" > /etc/sudoers.d/$USER_NAME
# echo "$USER ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/$USER_NAME

if [ "$ADMIN_SSH_KEY" != "[INSERT]" ]; then
  log_message "Adding SSH key for 'admin'..."
  mkdir -p /home/$USER_NAME/.ssh
  echo "$ADMIN_SSH_KEY" > /home/$USER_NAME/.ssh/authorized_keys
  chown -R $USER_NAME:$USER_NAME /home/$USER_NAME/.ssh
  chmod 700 /home/$USER_NAME/.ssh
  chmod 600 /home/$USER_NAME/.ssh/authorized_keys
else
  log_message "WARNING: No SSH key provided for 'admin'. You will need to add one manually."
fi

# Install essential packages
log_message "Installing essential packages..."
apt update && apt upgrade -y
apt-get -y install curl ca-certificates gnupg debian-keyring debian-archive-keyring apt-transport-https net-tools openssh-server

log_message "Writing configuration files..."

cat > /etc/ssh/sshd_config << EOF
Port $SSH_PORT
AddressFamily inet
Protocol 2
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key
UsePrivilegeSeparation yes
KeyRegenerationInterval 3600
SyslogFacility AUTH
LogLevel VERBOSE
LoginGraceTime 30
PermitRootLogin no
StrictModes yes
RSAAuthentication yes
PubkeyAuthentication yes
IgnoreRhosts yes
RhostsRSAAuthentication no
HostbasedAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no
PasswordAuthentication no
X11Forwarding no
X11DisplayOffset 10
PrintMotd no
PrintLastLog yes
TCPKeepAlive yes
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
UsePAM yes
AllowUsers $USER_NAME
MaxAuthTries 3
MaxSessions 2
ClientAliveInterval 300
ClientAliveCountMax 2
EOF

log_message "Attempting to restart SSH service to apply new configuration on port $SSH_PORT..."
# Attempt to restart sshd, providing more specific feedback
if systemctl restart ssh; then
    log_message "SSH service restarted successfully on port $SSH_PORT."
    # You can add an extra sleep here if you want to be extra cautious,
    # but usually not necessary for service restarts.
    # sleep 2
else
    log_message "ERROR: Failed to restart SSH service."
    log_message "Please check systemctl status sshd for details."
    log_message "You may need to manually restart it or check /var/log/auth.log or journalctl -u sshd for errors."
    exit 1 # Exit the script if SSH service fails to restart
fi

systemctl enable ssh
systemctl start ssh

# Configure firewall
log_message "Configuring firewall..."
ufw allow $SSH_PORT/tcp     # SSH
ufw allow 80,443/tcp  # HTTP/HTTPS for Caddy

ufw enable
ufw reload
log_message "Firewall enabled."

log_message "Installing btop..."
snap install btop

log_message "Finished base setup at $(date)."

