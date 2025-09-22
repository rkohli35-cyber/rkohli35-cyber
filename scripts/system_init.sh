#!/bin/bash
# system_init.sh - Universal Linux system initialization script

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
    PKG_MANAGER="dnf"
elif [ -f /etc/lsb-release ] && grep -q "Ubuntu" /etc/lsb-release; then
    DISTRO="ubuntu"
    PKG_MANAGER="apt"
elif [ -f /etc/os-release ]; then
    source /etc/os-release
    if [[ "$ID" == "ubuntu" ]]; then
        DISTRO="ubuntu"
        PKG_MANAGER="apt"
    elif [[ "$ID" == "fedora" ]]; then
        DISTRO="fedora"
        PKG_MANAGER="dnf"
    else
        print_error "Unsupported distribution: $ID"
        exit 1
    fi
else
    print_error "Unable to detect distribution"
    exit 1
fi

print_success "Detected distribution: $DISTRO"

# Update system
print_status "Updating system packages..."
if [ "$DISTRO" = "fedora" ]; then
    sudo dnf update -y
elif [ "$DISTRO" = "ubuntu" ]; then
    sudo apt update && sudo apt upgrade -y
fi

if [ $? -eq 0 ]; then
    print_success "System updated successfully"
else
    print_error "Failed to update system"
    exit 1
fi

# Install essential packages
print_status "Installing essential packages..."
ESSENTIAL_PACKAGES="curl wget git vim htop tree unzip zip"

if [ "$DISTRO" = "fedora" ]; then
    sudo dnf install -y $ESSENTIAL_PACKAGES neofetch
elif [ "$DISTRO" = "ubuntu" ]; then
    sudo apt install -y $ESSENTIAL_PACKAGES neofetch
fi

if [ $? -eq 0 ]; then
    print_success "Essential packages installed successfully"
else
    print_warning "Some packages may have failed to install"
fi

# Install development tools
read -p "Do you want to install development tools? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_status "Installing development tools..."
    if [ "$DISTRO" = "fedora" ]; then
        sudo dnf groupinstall -y "Development Tools" "C Development Tools and Libraries"
        sudo dnf install -y python3-pip nodejs npm
    elif [ "$DISTRO" = "ubuntu" ]; then
        sudo apt install -y build-essential python3-pip nodejs npm
    fi
    print_success "Development tools installed"
fi

# Configure Git if not already configured
if ! git config --global user.name >/dev/null 2>&1; then
    read -p "Enter your Git username: " git_username
    read -p "Enter your Git email: " git_email
    git config --global user.name "$git_username"
    git config --global user.email "$git_email"
    print_success "Git configured successfully"
fi

# Enable automatic updates
read -p "Do you want to enable automatic security updates? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_status "Configuring automatic updates..."
    if [ "$DISTRO" = "fedora" ]; then
        sudo dnf install -y dnf-automatic
        sudo systemctl enable --now dnf-automatic-install.timer
    elif [ "$DISTRO" = "ubuntu" ]; then
        sudo apt install -y unattended-upgrades
        echo 'Unattended-Upgrade::Automatic-Reboot "false";' | sudo tee -a /etc/apt/apt.conf.d/50unattended-upgrades
    fi
    print_success "Automatic updates configured"
fi

# Display system information
print_status "System initialization completed!"
echo
print_success "System Information:"
neofetch