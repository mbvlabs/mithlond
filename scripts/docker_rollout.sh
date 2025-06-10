set -euo pipefail

# Setup Docker Rollout plugin
log "Setting up Docker Rollout plugin..."

# Create directory for Docker cli plugins
log "Creating Docker cli plugins directory..."
mkdir -p /home/$USER_NAME/.docker/cli-plugins

# Download docker-rollout script to Docker cli plugins directory
log "Downloading docker-rollout plugin..."
curl https://raw.githubusercontent.com/wowu/docker-rollout/main/docker-rollout -o ~/.docker/cli-plugins/docker-rollout

# Make the script executable
log "Making docker-rollout executable..."
chmod +x ~/.docker/cli-plugins/docker-rollout

log "Finished docker-rollout setup at $(date)."
