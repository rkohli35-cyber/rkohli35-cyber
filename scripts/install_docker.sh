#!/bin/bash
# install_docker.sh - Install Docker on Fedora/Ubuntu

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if script is run as root
if [[ $EUID -eq 0 ]]; then
   print_error "This script should not be run as root"
   exit 1
fi

# Detect distribution
if [ -f /etc/fedora-release ]; then
    DISTRO="fedora"
elif [ -f /etc/lsb-release ] && grep -q "Ubuntu" /etc/lsb-release; then
    DISTRO="ubuntu"
elif [ -f /etc/os-release ]; then
    source /etc/os-release
    if [[ "$ID" == "ubuntu" ]]; then
        DISTRO="ubuntu"
    elif [[ "$ID" == "fedora" ]]; then
        DISTRO="fedora"
    else
        print_error "Unsupported distribution: $ID"
        exit 1
    fi
else
    print_error "Unable to detect distribution"
    exit 1
fi

print_success "Detected distribution: $DISTRO"

# Remove old Docker installations
print_status "Removing old Docker installations..."
if [ "$DISTRO" = "fedora" ]; then
    sudo dnf remove -y docker docker-client docker-client-latest docker-common \
        docker-latest docker-latest-logrotate docker-logrotate docker-selinux \
        docker-engine-selinux docker-engine
elif [ "$DISTRO" = "ubuntu" ]; then
    sudo apt remove -y docker docker-engine docker.io containerd runc
fi

# Install Docker
if [ "$DISTRO" = "fedora" ]; then
    print_status "Installing Docker on Fedora..."
    
    # Install prerequisites
    sudo dnf install -y dnf-plugins-core
    
    # Add Docker repository
    sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
    
    # Install Docker Engine
    sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
elif [ "$DISTRO" = "ubuntu" ]; then
    print_status "Installing Docker on Ubuntu..."
    
    # Update package index
    sudo apt update
    
    # Install prerequisites
    sudo apt install -y ca-certificates curl gnupg lsb-release
    
    # Add Docker's official GPG key
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Set up repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Update package index again
    sudo apt update
    
    # Install Docker Engine
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
fi

# Verify installation
if command -v docker &> /dev/null; then
    print_success "Docker installed successfully"
else
    print_error "Docker installation failed"
    exit 1
fi

# Start and enable Docker service
print_status "Starting and enabling Docker service..."
sudo systemctl enable --now docker

# Add current user to docker group
print_status "Adding user $USER to docker group..."
sudo usermod -aG docker $USER

# Install Docker Compose (standalone)
print_status "Installing Docker Compose..."
DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Create symbolic link for docker-compose
sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

# Verify Docker Compose installation
if command -v docker-compose &> /dev/null; then
    print_success "Docker Compose installed successfully"
else
    print_warning "Docker Compose installation may have failed"
fi

# Configure Docker daemon (optional optimizations)
print_status "Configuring Docker daemon..."
sudo mkdir -p /etc/docker
cat << EOF | sudo tee /etc/docker/daemon.json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2"
}
EOF

# Restart Docker to apply configuration
sudo systemctl restart docker

# Test Docker installation
print_status "Testing Docker installation..."
if sudo docker run --rm hello-world >/dev/null 2>&1; then
    print_success "Docker test completed successfully"
else
    print_warning "Docker test failed, but installation may still be working"
fi

# Display installation summary
echo
print_success "Docker Installation Summary:"
echo "- Docker Engine: $(docker --version 2>/dev/null || echo "Not accessible without group membership")"
echo "- Docker Compose: $(docker-compose --version 2>/dev/null || echo "Installed but may need PATH update")"
echo "- Docker service status: $(sudo systemctl is-active docker)"
echo
print_warning "IMPORTANT: Please log out and log back in for group changes to take effect!"
print_status "After logging back in, you can test Docker with: docker run hello-world"

# Create useful Docker aliases
print_status "Creating useful Docker aliases..."
cat << 'EOF' >> ~/.bashrc

# Docker aliases
alias dps='docker ps'
alias dpa='docker ps -a'
alias di='docker images'
alias dcp='docker-compose'
alias dcup='docker-compose up -d'
alias dcdown='docker-compose down'
alias dclogs='docker-compose logs -f'
alias dexec='docker exec -it'
alias dstop='docker stop $(docker ps -q)'
alias drm='docker rm $(docker ps -aq)'
alias drmi='docker rmi $(docker images -q)'
EOF

print_success "Docker aliases added to ~/.bashrc"
print_status "Installation completed! Please log out and log back in to use Docker without sudo."