log_message "Updating packages..."

apt-get update

log_message "Setting timezone to Europe/Copenhagen..."
timedatectl set-timezone Europe/Copenhagen

log_message "Creating user 'admin'..."
useradd -m -u 1000 -s /bin/bash $USER_NAME
usermod -aG sudo $USER_NAME || log_message "Failed to add user to sudo group"

log_message "Setting a strong random password for admin user. Please save this password:"
echo "Admin Password: $USER_PASSWORD"
echo "$USER_NAME:$USER_PASSWORD" | chpasswd

echo "$USER_NAME ALL=(ALL) ALL" > /etc/sudoers.d/$USER_NAME

if [ "$SSH_KEY" != "[INSERT]" ]; then
  log_message "Adding SSH key for 'admin'..."
  mkdir -p /home/$USER_NAME/.ssh
  echo "$SSH_KEY" > /home/$USER_NAME/.ssh/authorized_keys
  chown -R $USER_NAME:$USER_NAME /home/$USER_NAME/.ssh
  chmod 700 /home/$USER_NAME/.ssh
  chmod 600 /home/$USER_NAME/.ssh/authorized_keys
else
  log_message "WARNING: No SSH key provided for 'admin'. You will need to add one manually."
fi

log_message "Installing essential packages..."
apt-get -y install curl ca-certificates gnupg debian-keyring debian-archive-keyring apt-transport-https net-tools

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
AllowUsers root $USER_NAME
MaxAuthTries 3
MaxSessions 2
ClientAliveInterval 300
ClientAliveCountMax 2
EOF

log_message "Attempting to restart SSH service to apply new configuration on port $SSH_PORT..."
if systemctl restart ssh; then
    log_message "SSH service restarted successfully on port $SSH_PORT."
else
    log_message "ERROR: Failed to restart SSH service."
    log_message "Please check systemctl status sshd for details."
    log_message "You may need to manually restart it or check /var/log/auth.log or journalctl -u sshd for errors."
    exit 1
fi

systemctl enable ssh
systemctl start ssh

log_message "Configuring firewall..."
ufw allow $SSH_PORT/tcp
ufw allow 80,443/tcp

echo y | ufw enable
ufw reload
log_message "Firewall enabled."

log_message "Installing btop..."
snap install btop

log_message "Finished base setup at $(date)."
