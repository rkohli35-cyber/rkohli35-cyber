#!/bin/bash
# security_hardening.sh - Basic security hardening for Linux systems

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
if [[ $EUID -ne 0 ]]; then
   print_error "This script must be run as root"
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

# Update system
print_status "Updating system packages..."
if [ "$DISTRO" = "fedora" ]; then
    dnf update -y
elif [ "$DISTRO" = "ubuntu" ]; then
    apt update && apt upgrade -y
fi

# Configure automatic updates
print_status "Configuring automatic security updates..."
if [ "$DISTRO" = "fedora" ]; then
    dnf install -y dnf-automatic
    systemctl enable --now dnf-automatic-install.timer
    print_success "DNF automatic updates enabled"
elif [ "$DISTRO" = "ubuntu" ]; then
    apt install -y unattended-upgrades apt-listchanges
    echo 'Unattended-Upgrade::Automatic-Reboot "false";' >> /etc/apt/apt.conf.d/50unattended-upgrades
    echo 'Unattended-Upgrade::Remove-Unused-Dependencies "true";' >> /etc/apt/apt.conf.d/50unattended-upgrades
    systemctl enable --now unattended-upgrades
    print_success "Unattended upgrades configured"
fi

# Configure SSH security
print_status "Hardening SSH configuration..."
if [ -f /etc/ssh/sshd_config ]; then
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d)
    
    # SSH hardening configurations
    sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
    sed -i 's/#Protocol 2/Protocol 2/' /etc/ssh/sshd_config
    sed -i 's/#MaxAuthTries 6/MaxAuthTries 3/' /etc/ssh/sshd_config
    sed -i 's/#ClientAliveInterval 0/ClientAliveInterval 300/' /etc/ssh/sshd_config
    sed -i 's/#ClientAliveCountMax 3/ClientAliveCountMax 2/' /etc/ssh/sshd_config
    
    # Add these if they don't exist
    if ! grep -q "^PermitEmptyPasswords" /etc/ssh/sshd_config; then
        echo "PermitEmptyPasswords no" >> /etc/ssh/sshd_config
    fi
    
    if ! grep -q "^X11Forwarding" /etc/ssh/sshd_config; then
        echo "X11Forwarding no" >> /etc/ssh/sshd_config
    fi
    
    systemctl restart sshd
    print_success "SSH hardened successfully"
else
    print_warning "SSH config file not found, skipping SSH hardening"
fi

# Configure firewall
print_status "Configuring firewall..."
if command -v firewall-cmd &> /dev/null; then
    # Fedora/RHEL firewalld
    systemctl enable --now firewalld
    firewall-cmd --set-default-zone=public
    firewall-cmd --permanent --add-service=ssh
    firewall-cmd --reload
    print_success "Firewalld configured"
elif command -v ufw &> /dev/null; then
    # Ubuntu UFW
    ufw --force enable
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh
    print_success "UFW configured"
else
    print_warning "No supported firewall found"
fi

# Configure fail2ban
print_status "Installing and configuring fail2ban..."
if [ "$DISTRO" = "fedora" ]; then
    dnf install -y fail2ban
elif [ "$DISTRO" = "ubuntu" ]; then
    apt install -y fail2ban
fi

if command -v fail2ban-client &> /dev/null; then
    # Create local jail configuration
    cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
backend = systemd

[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s
EOF
    
    systemctl enable --now fail2ban
    print_success "Fail2ban configured and started"
fi

# Set up log monitoring
print_status "Configuring log monitoring..."
if [ "$DISTRO" = "fedora" ]; then
    dnf install -y logwatch
elif [ "$DISTRO" = "ubuntu" ]; then
    apt install -y logwatch
fi

# Configure kernel parameters for security
print_status "Configuring kernel security parameters..."
cat > /etc/sysctl.d/99-security.conf << EOF
# IP Spoofing protection
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.rp_filter = 1

# Ignore ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# Ignore send redirects
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Disable source packet routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# Log Martians
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# Ignore ICMP ping requests
net.ipv4.icmp_echo_ignore_all = 1

# Ignore Directed pings
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Disable IPv6 if not needed
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOF

sysctl -p /etc/sysctl.d/99-security.conf
print_success "Kernel security parameters configured"

# Set up file permissions for sensitive files
print_status "Setting secure file permissions..."
chmod 700 /root
chmod 600 /etc/ssh/sshd_config
chmod 644 /etc/passwd
chmod 600 /etc/shadow
chmod 644 /etc/group

if [ -f /etc/gshadow ]; then
    chmod 600 /etc/gshadow
fi

print_success "File permissions secured"

# Display security status
print_status "Security hardening completed!"
echo
print_success "Security Status Summary:"
echo "- Automatic updates: Enabled"
echo "- SSH hardening: Applied"
echo "- Firewall: Configured"
echo "- Fail2ban: Installed and configured"
echo "- Kernel security parameters: Applied"
echo "- File permissions: Secured"
echo
print_warning "Important: Please ensure you have SSH key-based authentication set up before logging out!"
print_warning "Password authentication has been disabled for SSH."