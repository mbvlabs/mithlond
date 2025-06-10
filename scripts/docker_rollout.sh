# Setup Docker Rollout plugin
log_message "Setting up Docker Rollout plugin..."

# Create directory for Docker cli plugins
log_message "Creating Docker cli plugins directory..."
mkdir -p ~/.docker/cli-plugins

# Download docker-rollout script to Docker cli plugins directory
log_message "Downloading docker-rollout plugin..."
curl https://raw.githubusercontent.com/wowu/docker-rollout/main/docker-rollout -o ~/.docker/cli-plugins/docker-rollout

# Make the script executable
log_message "Making docker-rollout executable..."
chmod +x ~/.docker/cli-plugins/docker-rollout

log_message "Finished docker-rollout setup at $(date)."