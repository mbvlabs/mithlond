#!/bin/bash

set -euo pipefail

TRAEFIK_VERSION="${TRAEFIK_VERSION:-latest}"
TRAEFIK_DIR="/home/$USER_NAME/traefik"
TRAEFIK_CONFIG_FILE="$TRAEFIK_DIR/traefik.yml"
TRAEFIK_COMPOSE_FILE="$TRAEFIK_DIR/docker-compose.yml"
TRAEFIK_DYNAMIC_DIR="$TRAEFIK_DIR/dynamic"

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
      tlsChallenge: {}
      email: changeme@example.com
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
EOF
    
    chown "$USER_NAME:$USER_NAME" "$TRAEFIK_CONFIG_FILE"
}

create_docker_compose() {
    log "Creating Docker Compose configuration..."
    
    cat > "$TRAEFIK_COMPOSE_FILE" << EOF
version: '3.8'

services:
  traefik:
    image: traefik:${TRAEFIK_VERSION}
    container_name: traefik
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"  # Dashboard
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./traefik.yml:/etc/traefik/traefik.yml:ro
      - ./dynamic:/etc/traefik/dynamic:ro
      - traefik-data:/data
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.dashboard.rule=Host(\`traefik.localhost\`)"
      - "traefik.http.routers.dashboard.entrypoints=websecure"
      - "traefik.http.routers.dashboard.tls.certresolver=letsencrypt"
      - "traefik.http.routers.dashboard.service=api@internal"
      - "traefik.http.routers.dashboard.middlewares=auth"
      - "traefik.http.middlewares.auth.basicauth.users=admin:\$\$2y\$\$10\$\$DmX3XwNS4QZ8ZwUf2Qcjy.9sP6yfNfM7YJY5X0Q4J2xVf8E0G8lKa"
    networks:
      - traefik

networks:
  traefik:
    external: true

volumes:
  traefik-data:
EOF
    
    chown "$USER_NAME:$USER_NAME" "$TRAEFIK_COMPOSE_FILE"
}

create_dynamic_config() {
    log "Creating dynamic configuration example..."
    
    cat > "$TRAEFIK_DYNAMIC_DIR/example.yml" << 'EOF'
# Example dynamic configuration
# Add your custom routes here

http:
  routers:
    # Example router (uncomment and modify as needed)
    # my-app:
    #   rule: "Host(`myapp.example.com`)"
    #   entrypoints:
    #     - websecure
    #   service: my-app-service
    #   tls:
    #     certResolver: letsencrypt

  services:
    # Example service (uncomment and modify as needed)
    # my-app-service:
    #   loadBalancer:
    #     servers:
    #       - url: "http://localhost:3000"
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

start_traefik() {
    log "Starting Traefik..."
    
    cd "$TRAEFIK_DIR"
    
    # Use docker compose if available, otherwise docker-compose
    if docker compose version >/dev/null 2>&1; then
        sudo -u "$USER_NAME" docker compose up -d
    else
        sudo -u "$USER_NAME" docker-compose up -d
    fi
    
    sleep 3
    
    if docker ps | grep -q "traefik"; then
        log "Traefik started successfully"
        log "Dashboard available at http://localhost:8080 (user: admin, pass: admin)"
        log "Or at https://traefik.localhost (if DNS configured)"
    else
        error "Failed to start Traefik"
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
    labels:
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

Let's Encrypt is configured for automatic SSL certificates. Update the email in `traefik.yml`.
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
    start_traefik
    create_usage_info
    
    log "Traefik installation completed successfully!"
    log "Directory: $TRAEFIK_DIR"
    log "Dashboard: http://localhost:8080"
    log "See $TRAEFIK_DIR/README.md for usage instructions"
}

main "$@"

