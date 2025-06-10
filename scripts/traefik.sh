#!/bin/bash

set -euo pipefail

TRAEFIK_VERSION="${TRAEFIK_VERSION:-latest}"
TRAEFIK_DIR="/home/$USER_NAME/traefik"
TRAEFIK_CONFIG_FILE="$TRAEFIK_DIR/traefik.yml"
TRAEFIK_COMPOSE_FILE="$TRAEFIK_DIR/docker-compose.yml"
TRAEFIK_DYNAMIC_DIR="$TRAEFIK_DIR/dynamic"
# CLOUDFLARE_EMAIL="${cloudflare_email}"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1" >&2
    exit 1
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
    fi
}

check_user_exists() {
    if ! getent passwd "$USER_NAME" >/dev/null 2>&1; then
        error "User $USER_NAME does not exist"
    fi
}

check_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        error "Docker is not installed. Please install Docker first"
    fi
    
    if ! command -v docker-compose >/dev/null 2>&1 && ! docker compose version >/dev/null 2>&1; then
        error "Docker Compose is not installed. Please install Docker Compose first"
    fi
}

create_directories() {
    log "Creating Traefik directories..."
    
    mkdir -p "$TRAEFIK_DIR"
    mkdir -p "$TRAEFIK_DYNAMIC_DIR"
    
    chown -R "$USER_NAME:$USER_NAME" "$TRAEFIK_DIR"
}

create_traefik_config() {
    log "Creating Traefik static configuration..."
    
    cat > "$TRAEFIK_CONFIG_FILE" << 'EOF'
api:
  dashboard: true
  debug: true

entryPoints:
  web:
    address: ":80"
  websecure:
    address: ":443"

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
    network: traefik
  file:
    directory: /etc/traefik/dynamic
    watch: true

certificatesResolvers:
  letsencrypt:
    acme:
      dnsChallenge:
        provider: cloudflare
        delayBeforeCheck: 0
      email: cloudflare_email
      storage: /data/acme.json

# Global redirect to https
http:
  routers:
    web-to-websecure:
      rule: hostregexp(`{host:.+}`)
      entrypoints:
        - web
      middlewares:
        - redirect-to-https
      service: api@internal

  middlewares:
    redirect-to-https:
      redirectScheme:
        scheme: https
        permanent: true

metrics:
  prometheus:
    addEntryPointsLabels: true
    addRoutersLabels: true
    addServicesLabels: true
    manualRouting: true
EOF
    
    chown "$USER_NAME:$USER_NAME" "$TRAEFIK_CONFIG_FILE"
    
	sed -i "s/cloudflare_email/$CLOUDFLARE_EMAIL/g" "$TRAEFIK_CONFIG_FILE"
}

create_docker_compose() {
    log "Creating Docker Compose configuration..."

	if [ -z "$DOMAIN" ]; then
    	log "ERROR: DOMAIN variable is not set"
		DOMAIN=${DOMAIN:-"mbvlabs.com"}
	fi
    
    cat > "$TRAEFIK_COMPOSE_FILE" << 'EOF'
services:
  traefik:
    image: traefik:latest
    container_name: traefik
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"
    env_file:
      - .env
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./traefik.yml:/etc/traefik/traefik.yml:ro
      - ./dynamic:/etc/traefik/dynamic:ro
      - traefik-data:/data
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.dashboard.entrypoints=websecure"
	  - "traefik.http.routers.dashboard.rule=Host(`traefik.DOMAIN_PLACEHOLDER`)"
      - "traefik.http.routers.dashboard.tls.certresolver=letsencrypt"
      - "traefik.http.routers.dashboard.service=api@internal"
      - "traefik.http.routers.dashboard.middlewares=auth"
	  - "traefik.http.middlewares.auth.basicauth.users=${MANAGER_AUTH_STRING}"
    networks:
      - traefik

networks:
  traefik:
    external: true

volumes:
  traefik-data:
EOF
    
    # Replace placeholders
    sed -i "s/DOMAIN_PLACEHOLDER/$DOMAIN/g" "$TRAEFIK_COMPOSE_FILE"
    chown "$USER_NAME:$USER_NAME" "$TRAEFIK_COMPOSE_FILE"
}

create_dynamic_config() {
    log "Creating dynamic configurations..."
# Create manager service dynamic configuration template
cat > "$TRAEFIK_DYNAMIC_DIR/manager.yml" << 'EOF'
# Manager service configuration
# This routes traffic to the manager API service

http:
  routers:
    manager:
      rule: "Host(`apps-manager.MANAGER_DOMAIN_PLACEHOLDER`)"
      entrypoints:
        - websecure
      service: manager-service
      tls:
        certResolver: letsencrypt
      middlewares:
        - manager-auth

  services:
    manager-service:
      loadBalancer:
        servers:
          - url: "http://ip:9090"

  middlewares:
    manager-auth:
      basicAuth:
        users:
            - MANAGER_AUTH_PLACEHOLDER
EOF
    
# Create metrics service dynamic configuration template
cat > "$TRAEFIK_DYNAMIC_DIR/metrics.yml" << 'EOF'
# Metrics service configuration
# This exposes metrics from traefik
http:
    middlewares:
      metrics-auth:
        basicAuth:
          users:
            - MANAGER_AUTH_PLACEHOLDER

    routers:
      metrics:
        entryPoints:
          - websecure
        rule: "Host(`traefik.MANAGER_DOMAIN_PLACEHOLDER`) && PathPrefix(`/metrics`)"
        service: prometheus@internal
        tls:
          certResolver: letsencrypt
        middlewares:
          - metrics-auth
EOF

# Create node exporter service dynamic configuration template
cat > "$TRAEFIK_DYNAMIC_DIR/node_exporter.yml" << 'EOF'
# Node exporter service configuration
# This exposes node exporter from traefik
http:
  routers:
    nodeexporter:
      rule: "Host(`apps-node-exporter.MANAGER_DOMAIN_PLACEHOLDER`)"
      entrypoints:
        - websecure
      service: nodexporter-service
      tls:
        certResolver: letsencrypt
      middlewares:
        - manager-auth

  services:
    nodexporter-service:
      loadBalancer:
        servers:
          - url: "http://ip:9100"


  middlewares:
    manager-auth:
      basicAuth:
        users:
          - MANAGER_AUTH_PLACEHOLDER
EOF
    
chown -R "$USER_NAME:$USER_NAME" "$TRAEFIK_DYNAMIC_DIR"
}

create_traefik_network() {
    log "Creating Traefik network..."
    
    if ! docker network ls | grep -q "traefik"; then
        docker network create traefik
        log "Created Traefik network"
    else
        log "Traefik network already exists"
    fi
}


create_usage_info() {
    log "Creating usage information..."
    
    cat > "$TRAEFIK_DIR/README.md" << 'EOF'
# Traefik Setup

This directory contains the Traefik reverse proxy configuration.

## Usage

### Starting/Stopping Traefik
```bash
cd ~/traefik
docker compose up -d    # Start
docker compose down     # Stop
docker compose logs -f  # View logs
```

### Adding Services

To expose a Docker service through Traefik, add these labels to your docker-compose.yml:

```yaml
services:
  your-app:
    image: your-app:latest
 \   labels:
      - "traefik.enable=true"
      - "traefik.http.routers.your-app.rule=Host(`your-app.localhost`)"
      - "traefik.http.routers.your-app.entrypoints=websecure"
      - "traefik.http.routers.your-app.tls.certresolver=letsencrypt"
      - "traefik.http.services.your-app.loadbalancer.server.port=3000"
    networks:
      - traefik

networks:
  traefik:
    external: true
```

### Configuration Files

- `traefik.yml` - Static configuration
- `dynamic/` - Dynamic configuration files
- `docker-compose.yml` - Container orchestration

### Dashboard Access

- Local: http://localhost:8080
- Domain: https://traefik.localhost (requires DNS setup)
- Credentials: admin/admin

### SSL Certificates

Let's Encrypt is configured for automatic SSL certificates using Cloudflare DNS challenge.
Configure your Cloudflare credentials in the `.env` file:

```
CLOUDFLARE_EMAIL=your-email@example.com
CLOUDFLARE_API_KEY=your-global-api-key
```

### Manager Service

The manager service is automatically configured and accessible at your specified domain.
Access it using the configured manager credentials.
EOF
    
    chown "$USER_NAME:$USER_NAME" "$TRAEFIK_DIR/README.md"
}

main() {
    log "Starting Traefik installation..."
    
    check_root
    check_user_exists
    check_docker
    create_directories
    create_traefik_config
    create_docker_compose
    create_dynamic_config
    create_traefik_network
    create_usage_info
    
    log "Traefik setup completed successfully!"
    log "Directory: $TRAEFIK_DIR"
    log "To start Traefik: cd $TRAEFIK_DIR && docker compose up -d"
    log "See $TRAEFIK_DIR/README.md for usage instructions"
}

main "$@"

