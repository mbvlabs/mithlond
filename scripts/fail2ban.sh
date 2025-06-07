log_message "Installing package..."
apt-get -y install fail2ban

log_message "Writing configuration files..."

cat > /etc/fail2ban/jail.local << EOF
[sshd]
enabled = true
port = $SSH_PORT
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
EOF

systemctl enable --now fail2ban

log_message "Finished fail2ban setup at $(date)."
