log_message "Installing Caddy web server..."

# Install Caddy
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
apt-get update
apt-get install -y caddy

log_message "Configuring Caddy for telemetry services..."

# Create Caddyfile with reverse proxies for telemetry services
cat > /etc/caddy/Caddyfile << EOF
# Telemetry services reverse proxy configuration
# Domain is configured via DOMAIN environment variable

$DOMAIN {
    # Default homepage or API
    respond "Telemetry Gateway" 200
}

telemetry-prometheus.$DOMAIN {
    basicauth {
        $CADDY_USERNAME $CADDY_PASSWORD
    }
    reverse_proxy localhost:9090
}

telemetry-loki.$DOMAIN {
    basicauth {
        $CADDY_USERNAME $CADDY_PASSWORD
    }
    reverse_proxy localhost:3100
}

telemetry-tempo.\$DOMAIN {
    basicauth {
        \$CADDY_USERNAME \$CADDY_PASSWORD
    }
    reverse_proxy localhost:3200
}

telemetry-alloy.\$DOMAIN {
    basicauth {
        \$CADDY_USERNAME \$CADDY_PASSWORD
    }
    reverse_proxy localhost:12345
}
EOF

log_message "Enabling Caddy service (but not starting yet)..."
systemctl enable caddy

log_message "Caddy installation and configuration completed."
log_message "IMPORTANT: Before starting Caddy, ensure:"
log_message "1. Set environment variables: DOMAIN, CADDY_USERNAME, CADDY_PASSWORD"
log_message "2. Point your DNS records to this server's IP:"
log_message "   - A record: \$DOMAIN -> SERVER_IP"
log_message "   - A record: telemetry-prometheus.\$DOMAIN -> SERVER_IP"
log_message "   - A record: telemetry-loki.\$DOMAIN -> SERVER_IP"
log_message "   - A record: telemetry-tempo.\$DOMAIN -> SERVER_IP"
log_message "   - A record: telemetry-alloy.\$DOMAIN -> SERVER_IP"
log_message "3. Then start Caddy with: systemctl start caddy"
