log_message "Installing Caddy web server..."

# Install Caddy
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
apt-get update
apt-get install -y caddy

log_message "Configuring Caddy for telemetry services..."

# Create example Caddyfile template
cat > /etc/caddy/Caddyfile << 'EOF'
# Telemetry services reverse proxy configuration
# Replace 'your-domain.com' with your actual domain
# Replace 'your-username' and 'your-hashed-password' with actual credentials

# your-domain.com {
#     # Default homepage or API
#     respond "Telemetry Gateway" 200
# }

# telemetry-prometheus.your-domain.com {
#     basic_auth {
#         your-username your-hashed-password
#     }
#     reverse_proxy localhost:9090
# }

# telemetry-loki.your-domain.com {
#     basic_auth {
#         your-username your-hashed-password
#     }
#     reverse_proxy localhost:3100
# }

# telemetry-tempo.your-domain.com {
#     basic_auth {
#         your-username your-hashed-password
#     }
#     reverse_proxy localhost:3200
# }

# telemetry-alloy.your-domain.com {
#     basic_auth {
#         your-username your-hashed-password
#     }
#     reverse_proxy localhost:12345
# }
EOF

log_message "Enabling Caddy service (but not starting yet)..."
systemctl enable caddy

log_message "Caddy installation and configuration completed."
log_message "IMPORTANT: Before rebooting, ensure:"
log_message "1. Edit /etc/caddy/Caddyfile with your domain and credentials"
log_message "2. Generate hashed password with: caddy hash-password"
log_message "3. Point your DNS records to this server's IP"
log_message "4. Uncomment and configure the routes in Caddyfile"
log_message "5. Caddy will start automatically after reboot"
