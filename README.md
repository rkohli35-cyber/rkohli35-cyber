# 🐧 Linux Expert - Fedora & Ubuntu Specialist

👋 **Welcome!** I'm @rkohli35-cyber, your dedicated Linux Expert specializing in **Fedora** and **Ubuntu** distributions.

## 🎯 About This Repository

This repository serves as a comprehensive guide for Linux system administration, configuration, and automation. Whether you're a beginner or an experienced user, you'll find detailed instructions, scripts, and best practices for both Fedora and Ubuntu systems.

## 📋 Quick Navigation

- [🔴 Fedora Linux](#-fedora-linux)
- [🟠 Ubuntu Linux](#-ubuntu-linux)
- [⚙️ Common Scripts](#️-common-scripts)
- [🛠️ System Administration](#️-system-administration)
- [🔧 Troubleshooting](#-troubleshooting)
- [📚 Resources](#-resources)

---

## 🔴 Fedora Linux

### 📦 Package Management

#### DNF Package Manager
```bash
# Update system
sudo dnf update -y

# Install packages
sudo dnf install -y package_name

# Search for packages
dnf search keyword

# Remove packages
sudo dnf remove package_name

# List installed packages
dnf list installed

# Clean package cache
sudo dnf clean all
```

#### Enable RPM Fusion Repositories
```bash
# Enable free and non-free repositories
sudo dnf install -y \
  https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
  https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
```

### 🛡️ Firewall Configuration (firewalld)
```bash
# Check firewall status
sudo firewall-cmd --state

# List all zones
sudo firewall-cmd --get-zones

# Get active zones
sudo firewall-cmd --get-active-zones

# Add service to firewall
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload

# Open specific port
sudo firewall-cmd --permanent --add-port=8080/tcp
sudo firewall-cmd --reload
```

### 🎛️ SELinux Management
```bash
# Check SELinux status
sestatus

# Set SELinux to permissive mode (temporarily)
sudo setenforce 0

# Set SELinux to enforcing mode
sudo setenforce 1

# View SELinux context
ls -Z /path/to/file

# Restore default SELinux context
sudo restorecon -R /path/to/directory
```

### 💾 Fedora System Services
```bash
# Enable and start services
sudo systemctl enable --now service_name

# Check service status
sudo systemctl status service_name

# Restart service
sudo systemctl restart service_name

# View service logs
sudo journalctl -u service_name -f
```

---

## 🟠 Ubuntu Linux

### 📦 Package Management

#### APT Package Manager
```bash
# Update package lists
sudo apt update

# Upgrade all packages
sudo apt upgrade -y

# Full system upgrade
sudo apt full-upgrade -y

# Install packages
sudo apt install -y package_name

# Remove packages
sudo apt remove package_name

# Remove packages and configuration files
sudo apt purge package_name

# Clean package cache
sudo apt autoremove && sudo apt autoclean
```

#### Snap Package Management
```bash
# Install snap package
sudo snap install package_name

# List installed snaps
snap list

# Update all snaps
sudo snap refresh

# Remove snap package
sudo snap remove package_name
```

### 🛡️ Firewall Configuration (ufw)
```bash
# Enable UFW
sudo ufw enable

# Check UFW status
sudo ufw status verbose

# Allow specific service
sudo ufw allow ssh
sudo ufw allow http
sudo ufw allow https

# Allow specific port
sudo ufw allow 8080/tcp

# Deny access
sudo ufw deny from 192.168.1.100

# Reset UFW rules
sudo ufw --force reset
```

### 🎛️ AppArmor Management
```bash
# Check AppArmor status
sudo aa-status

# Put profile in complain mode
sudo aa-complain /path/to/profile

# Put profile in enforce mode
sudo aa-enforce /path/to/profile

# Reload AppArmor profiles
sudo systemctl reload apparmor
```

### 💾 Ubuntu System Services
```bash
# Enable and start services
sudo systemctl enable --now service_name

# Check service status
sudo systemctl status service_name

# Restart service
sudo systemctl restart service_name

# View service logs
sudo journalctl -u service_name -f
```

---

## ⚙️ Common Scripts

### 🗂️ Available Scripts

This repository includes practical automation scripts in the [`scripts/`](scripts/) directory:

| Script | Purpose | Usage |
|--------|---------|-------|
| [`system_init.sh`](scripts/system_init.sh) | Universal system initialization | `./scripts/system_init.sh` |
| [`security_hardening.sh`](scripts/security_hardening.sh) | Security hardening automation | `sudo ./scripts/security_hardening.sh` |
| [`install_docker.sh`](scripts/install_docker.sh) | Docker installation | `./scripts/install_docker.sh` |
| [`system_monitor.sh`](scripts/system_monitor.sh) | System health monitoring | `./scripts/system_monitor.sh` |

📖 **Detailed documentation**: [Scripts README](scripts/README.md)

### 🚀 System Initialization Script

Create a comprehensive system setup script for both distributions:

```bash
#!/bin/bash
# system_init.sh - Universal Linux system initialization script

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Detect distribution
if [ -f /etc/fedora-release ]; then
    DISTRO="fedora"
    PKG_MANAGER="dnf"
elif [ -f /etc/lsb-release ] && grep -q "Ubuntu" /etc/lsb-release; then
    DISTRO="ubuntu"
    PKG_MANAGER="apt"
else
    echo -e "${RED}Unsupported distribution${NC}"
    exit 1
fi

echo -e "${GREEN}Detected distribution: $DISTRO${NC}"

# Update system
echo -e "${YELLOW}Updating system...${NC}"
if [ "$DISTRO" = "fedora" ]; then
    sudo dnf update -y
elif [ "$DISTRO" = "ubuntu" ]; then
    sudo apt update && sudo apt upgrade -y
fi

# Install essential packages
echo -e "${YELLOW}Installing essential packages...${NC}"
if [ "$DISTRO" = "fedora" ]; then
    sudo dnf install -y curl wget git vim htop tree unzip
elif [ "$DISTRO" = "ubuntu" ]; then
    sudo apt install -y curl wget git vim htop tree unzip
fi

echo -e "${GREEN}System initialization completed!${NC}"
```

### 🔐 Security Hardening Script

```bash
#!/bin/bash
# security_hardening.sh - Basic security hardening for Linux systems

# Update system
echo "Updating system packages..."
if command -v dnf &> /dev/null; then
    sudo dnf update -y
elif command -v apt &> /dev/null; then
    sudo apt update && sudo apt upgrade -y
fi

# Configure automatic updates
echo "Configuring automatic security updates..."
if command -v dnf &> /dev/null; then
    sudo dnf install -y dnf-automatic
    sudo systemctl enable --now dnf-automatic-install.timer
elif command -v apt &> /dev/null; then
    sudo apt install -y unattended-upgrades
    sudo dpkg-reconfigure -plow unattended-upgrades
fi

# Configure SSH security
echo "Hardening SSH configuration..."
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
sudo sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart sshd

# Configure firewall
echo "Configuring firewall..."
if command -v firewall-cmd &> /dev/null; then
    sudo firewall-cmd --set-default-zone=public
    sudo firewall-cmd --permanent --add-service=ssh
    sudo firewall-cmd --reload
elif command -v ufw &> /dev/null; then
    sudo ufw --force enable
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow ssh
fi

echo "Security hardening completed!"
```

### 🐳 Docker Installation Script

```bash
#!/bin/bash
# install_docker.sh - Install Docker on Fedora/Ubuntu

# Detect distribution
if [ -f /etc/fedora-release ]; then
    echo "Installing Docker on Fedora..."
    sudo dnf remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-selinux docker-engine-selinux docker-engine
    sudo dnf install -y dnf-plugins-core
    sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
    sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
elif [ -f /etc/lsb-release ] && grep -q "Ubuntu" /etc/lsb-release; then
    echo "Installing Docker on Ubuntu..."
    sudo apt remove -y docker docker-engine docker.io containerd runc
    sudo apt update
    sudo apt install -y ca-certificates curl gnupg lsb-release
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
fi

# Start and enable Docker
sudo systemctl enable --now docker

# Add current user to docker group
sudo usermod -aG docker $USER

echo "Docker installation completed! Please log out and log back in for group changes to take effect."
```

---

## 🛠️ System Administration

### 📊 System Monitoring Commands

```bash
# System resource usage
htop                    # Interactive process viewer
top                     # Process viewer
free -h                 # Memory usage
df -h                   # Disk usage
lsblk                   # Block devices
lscpu                   # CPU information
lsusb                   # USB devices
lspci                   # PCI devices

# Network monitoring
ss -tuln                # Network connections
netstat -tuln           # Network connections (legacy)
iftop                   # Network bandwidth usage
nload                   # Network traffic monitoring

# Log monitoring
sudo journalctl -f      # Follow system logs
sudo tail -f /var/log/syslog    # Follow syslog (Ubuntu)
sudo tail -f /var/log/messages  # Follow messages (Fedora)
```

### 🔄 Service Management

```bash
# Systemd service management
sudo systemctl start service_name      # Start service
sudo systemctl stop service_name       # Stop service
sudo systemctl restart service_name    # Restart service
sudo systemctl reload service_name     # Reload service
sudo systemctl enable service_name     # Enable at boot
sudo systemctl disable service_name    # Disable at boot
sudo systemctl status service_name     # Check status
sudo systemctl list-units --type=service   # List all services
```

### 🗂️ File System Management

```bash
# Mount operations
sudo mount /dev/sdb1 /mnt/usb          # Mount device
sudo umount /mnt/usb                   # Unmount device
sudo mount -a                          # Mount all fstab entries

# Disk operations
sudo fdisk -l                          # List all disks
sudo parted -l                         # List partitions
sudo fsck /dev/sdb1                    # Check filesystem
sudo resize2fs /dev/sdb1               # Resize ext filesystem

# File permissions
chmod 755 file_or_directory            # Set permissions
chown user:group file_or_directory     # Change ownership
find /path -type f -perm 777           # Find files with specific permissions
```

---

## 📁 Configuration Files

The [`configs/`](configs/) directory contains ready-to-use configuration files:

| Configuration | Purpose | Usage |
|---------------|---------|-------|
| [`sshd_config_hardened`](configs/sshd_config_hardened) | Hardened SSH configuration | Copy to `/etc/ssh/sshd_config` |
| [`fail2ban_jail.local`](configs/fail2ban_jail.local) | Fail2ban jail configuration | Copy to `/etc/fail2ban/jail.local` |
| [`docker_daemon.json`](configs/docker_daemon.json) | Docker daemon optimization | Copy to `/etc/docker/daemon.json` |

⚠️ **Important**: Always backup original configuration files before applying changes.

---

## 🔧 Troubleshooting

### 🚨 Common Issues and Solutions

#### Boot Issues
```bash
# Check boot logs
sudo journalctl -b                     # Current boot logs
sudo journalctl -b -1                  # Previous boot logs

# GRUB issues (Ubuntu)
sudo update-grub                       # Update GRUB configuration
sudo grub-install /dev/sda             # Reinstall GRUB

# GRUB issues (Fedora)
sudo grub2-mkconfig -o /boot/grub2/grub.cfg    # Update GRUB config
sudo grub2-install /dev/sda                    # Reinstall GRUB
```

#### Network Issues
```bash
# Restart network services
sudo systemctl restart NetworkManager  # NetworkManager
sudo systemctl restart networking      # Ubuntu networking

# Check network configuration
ip addr show                           # Show IP addresses
ip route show                          # Show routing table
cat /etc/resolv.conf                   # Check DNS settings

# Reset network configuration
sudo nmcli connection reload           # Reload NetworkManager connections
sudo nmcli connection up connection_name   # Bring up connection
```

#### Package Manager Issues
```bash
# Fix broken packages (Ubuntu)
sudo apt --fix-broken install
sudo dpkg --configure -a

# Clear package cache
sudo apt clean                         # Ubuntu
sudo dnf clean all                     # Fedora

# Fix GPG key issues (Ubuntu)
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys KEY_ID
```

#### Performance Issues
```bash
# Check system load
uptime                                 # System uptime and load
w                                      # Who is logged in and what they're doing

# Check for high CPU/memory usage
ps aux --sort=-%cpu | head            # Top CPU processes
ps aux --sort=-%mem | head            # Top memory processes

# Check disk I/O
iostat -x 1                           # Disk I/O statistics
iotop                                 # I/O usage by process
```

---

## 📚 Resources

### 📖 Official Documentation
- [Fedora Documentation](https://docs.fedoraproject.org/)
- [Ubuntu Documentation](https://help.ubuntu.com/)
- [Red Hat Enterprise Linux Documentation](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/)

### 🎓 Learning Resources
- [Linux Academy](https://linuxacademy.com/)
- [The Linux Foundation Training](https://training.linuxfoundation.org/)
- [DigitalOcean Community Tutorials](https://www.digitalocean.com/community/tutorials)

### 🛠️ Useful Tools
- **System Monitoring**: htop, iotop, netstat, ss
- **Text Editors**: vim, nano, emacs
- **File Managers**: mc (Midnight Commander), ranger
- **Network Tools**: curl, wget, nmap, tcpdump

---

## 🤝 Contributing

Feel free to contribute to this repository by:
- Adding new scripts and configurations
- Improving existing documentation
- Reporting issues or suggesting enhancements
- Sharing best practices and tips

## 📧 Contact

- 💼 **Specialization**: Linux System Administration (Fedora & Ubuntu)
- 🎯 **Focus Areas**: Security Hardening, Automation, DevOps
- 📫 **Collaboration**: Open to Linux-related projects and consultations

---

*Last updated: September 22, 2024*

<!---
This repository serves as a comprehensive Linux Expert resource for Fedora and Ubuntu distributions.
Maintained by @rkohli35-cyber - Your go-to Linux specialist!
--->