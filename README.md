# Application Server Setup

This guide walks you through setting up an application server that can host and manage Docker containers with automatic SSL certificates and domain routing.

## Prerequisites

1. **Cloudflare Account**: You need a domain managed by Cloudflare
2. **Cloudflare API Key**: Global API key from your Cloudflare profile
3. **DigitalOcean Account**: For VPS hosting (or modify for other providers)
4. **Terraform**: Install Terraform on your local machine
5. **Go Binary**: Build the manager binary first

## Step 1: Build the Manager Binary

```bash
cd manager/
go build -o ../bin/manager .
```

## Step 2: Configure Variables

Create a `terraform.tfvars` file with your configuration:

```hcl
# VPS Configuration
user_name     = "your-username"
user_password = "your-secure-password"
ssh_port      = 2222
ssh_key       = "ssh-rsa AAAAB3NzaC1yc2E... your-public-key"

# Cloud Provider
do_token = "your-digitalocean-token"

# Manager Service Configuration
manager_domain   = "manager.yourdomain.com"
manager_password = "your-manager-api-password"

# Cloudflare Configuration
cloudflare_email   = "your-email@example.com"
cloudflare_api_key = "your-cloudflare-global-api-key"
```

## Step 3: Deploy the Server

```bash
terraform init
terraform plan
terraform apply
```

This will:
- Create a VPS with Docker and security hardening
- Install the manager binary as a systemd service
- Set up Traefik reverse proxy with Cloudflare DNS challenge
- Configure SSL certificates automatically
- Set up domain routing for the manager service

## Step 4: Post-Deployment Configuration

After deployment, you need to:

1. **Configure DNS**: Point your manager domain to the server IP
2. **Start Services**: SSH into the server and start the services

```bash
# SSH into your server
ssh -p 2222 your-username@your-server-ip

# Start Traefik
cd ~/traefik
docker compose up -d

# Configure and start manager service
sudo systemctl edit manager.service

# Add your actual credentials:
[Service]
Environment=API_USERNAME=your-api-username
Environment=API_PASSWORD=your-api-password
Environment=DOCKER_USERNAME=your-docker-username
Environment=DOCKER_PASSWORD=your-docker-password

# Start the manager service
sudo systemctl start manager.service
sudo systemctl status manager.service
```

## Step 5: Using the Manager API

The manager service provides a REST API for container management:

```bash
curl -X POST https://manager.yourdomain.com/services \
  -u manager:your-manager-password \
  -H "Content-Type: application/json" \
  -d '{
    "service_name": "my-app",
    "docker_compose_content": "version: '\''3.8'\''\nservices:\n  app:\n    image: nginx:latest\n    ports:\n      - \"3000:80\""
  }'
```

### Create a Service
```bash
curl -X POST https://manager.yourdomain.com/services \
  -u manager:your-manager-password \
  -H "Content-Type: application/json" \
  -d '{
    "service_name": "my-app",
    "docker_compose_content": "version: '\''3.8'\''\nservices:\n  app:\n    image: nginx:latest\n    ports:\n      - \"3000:80\""
  }'
```

### Start a Service
```bash
curl -X POST https://manager.yourdomain.com/services/my-app/start \
  -u manager:your-manager-password \
  -H "Content-Type: application/json" \
  -d '{"is_private": false}'
```

### Remove a Service
```bash
curl -X DELETE https://manager.yourdomain.com/services/my-app \
  -u manager:your-manager-password
```

### Deploy (Update) a Service
```bash
curl -X PUT https://manager.yourdomain.com/services/my-app/deploy \
  -u manager:your-manager-password \
  -H "Content-Type: application/json" \
  -d '{"is_private": false}'
```

## Step 6: Adding Custom Applications to Traefik

To expose your applications through Traefik, add labels to your docker-compose.yml:

```yaml
services:
  my-app:
    image: my-app:latest
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.my-app.rule=Host(`whoami.mbvlabs.com`)"
      - "traefik.http.routers.my-app.entrypoints=websecure"
      - "traefik.http.routers.my-app.tls.certresolver=letsencrypt"
      - "traefik.http.services.my-app.loadbalancer.server.port=3000"
    networks:
      - traefik

networks:
  traefik:
    external: true
```

## Monitoring and Logs

- **Traefik Dashboard**: Access at `https://traefik.yourdomain.com` (configure domain in traefik config)
- **Manager Logs**: `sudo journalctl -u manager.service -f`
- **Traefik Logs**: `cd ~/traefik && docker compose logs -f`

## Security Notes

1. **Change Default Passwords**: Always change the default passwords in the systemd service
2. **SSH Key Only**: The server is configured for SSH key authentication only
3. **Fail2ban**: Automatic IP blocking for failed login attempts
4. **SSL/TLS**: All traffic is automatically encrypted with Let's Encrypt certificates
5. **Basic Auth**: Manager API is protected with basic authentication

## Troubleshooting

### Manager Service Won't Start
```bash
sudo journalctl -u manager.service -n 50
```

### SSL Certificates Not Working
```bash
cd ~/traefik
docker compose logs traefik | grep -i error
```

### Domain Not Resolving
- Check DNS configuration in Cloudflare
- Verify domain points to server IP
- Ensure Cloudflare proxy is set to "DNS only" (gray cloud)

## File Structure

```
/home/your-username/
├── traefik/
│   ├── docker-compose.yml
│   ├── traefik.yml
│   ├── .env (Cloudflare credentials)
│   └── dynamic/
│       ├── manager.yml (Manager service routing)
│       └── example.yml
├── service1/
│   └── docker-compose.yml
└── service2/
    └── docker-compose.yml
```

## What You Get

- **Secure VPS**: Hardened Ubuntu server with fail2ban and SSH key auth
- **Container Management**: REST API for deploying and managing Docker containers
- **Automatic SSL**: Let's Encrypt certificates via Cloudflare DNS challenge
- **Reverse Proxy**: Traefik automatically routes traffic to your applications
- **Monitoring Ready**: Node exporter installed for Prometheus monitoring
- **Production Ready**: Systemd services, proper logging, and restart policies
