#!/bin/bash
# linux_expert_demo.sh - Demonstration of Linux Expert capabilities

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

print_banner() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                    🐧 LINUX EXPERT DEMO 🐧                   ║"
    echo "║                 Fedora & Ubuntu Specialist                    ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_section() {
    echo -e "\n${PURPLE}═══ $1 ═══${NC}"
}

print_command() {
    echo -e "${YELLOW}➜${NC} $1"
}

print_output() {
    echo -e "${GREEN}  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Main demo
print_banner

echo -e "${CYAN}Welcome to the Linux Expert demonstration!${NC}"
echo -e "This script showcases the capabilities and knowledge base"
echo -e "for both Fedora and Ubuntu Linux distributions.\n"

# System Detection Demo
print_section "SYSTEM DETECTION"
print_command "Detecting current Linux distribution..."

if [ -f /etc/fedora-release ]; then
    DISTRO="Fedora"
    VERSION=$(cat /etc/fedora-release)
    PKG_MANAGER="DNF"
    FIREWALL="firewalld"
    SECURITY="SELinux"
elif [ -f /etc/lsb-release ] && grep -q "Ubuntu" /etc/lsb-release; then
    DISTRO="Ubuntu"
    VERSION=$(lsb_release -d | cut -f2)
    PKG_MANAGER="APT"
    FIREWALL="UFW"
    SECURITY="AppArmor"
elif [ -f /etc/os-release ]; then
    source /etc/os-release
    DISTRO="$NAME"
    VERSION="$VERSION"
    if [[ "$ID" == "ubuntu" ]]; then
        PKG_MANAGER="APT"
        FIREWALL="UFW"
        SECURITY="AppArmor"
    elif [[ "$ID" == "fedora" ]]; then
        PKG_MANAGER="DNF"
        FIREWALL="firewalld"
        SECURITY="SELinux"
    else
        PKG_MANAGER="Unknown"
        FIREWALL="Unknown"
        SECURITY="Unknown"
    fi
else
    DISTRO="Unknown"
    VERSION="Unknown"
    PKG_MANAGER="Unknown"
    FIREWALL="Unknown"
    SECURITY="Unknown"
fi

print_output "Distribution: $DISTRO"
print_output "Version: $VERSION"
print_output "Package Manager: $PKG_MANAGER"
print_output "Firewall: $FIREWALL"
print_output "Security Framework: $SECURITY"

# Package Management Demo
print_section "PACKAGE MANAGEMENT COMMANDS"

if [[ "$PKG_MANAGER" == "DNF" ]]; then
    print_info "Fedora/DNF Commands:"
    print_command "sudo dnf update -y              # Update system"
    print_command "sudo dnf install package_name   # Install package"
    print_command "sudo dnf search keyword         # Search packages"
    print_command "sudo dnf remove package_name    # Remove package"
    print_command "sudo dnf clean all              # Clean cache"
elif [[ "$PKG_MANAGER" == "APT" ]]; then
    print_info "Ubuntu/APT Commands:"
    print_command "sudo apt update && sudo apt upgrade -y  # Update system"
    print_command "sudo apt install package_name           # Install package"
    print_command "apt search keyword                      # Search packages"
    print_command "sudo apt remove package_name            # Remove package"
    print_command "sudo apt autoremove && sudo apt clean   # Clean cache"
else
    print_info "Package management commands would be shown based on detected distribution"
fi

# Firewall Demo
print_section "FIREWALL CONFIGURATION"

if [[ "$FIREWALL" == "firewalld" ]]; then
    print_info "Fedora firewalld Commands:"
    print_command "sudo firewall-cmd --state                    # Check status"
    print_command "sudo firewall-cmd --get-active-zones         # Show active zones"
    print_command "sudo firewall-cmd --permanent --add-service=http  # Allow HTTP"
    print_command "sudo firewall-cmd --reload                   # Reload rules"
elif [[ "$FIREWALL" == "UFW" ]]; then
    print_info "Ubuntu UFW Commands:"
    print_command "sudo ufw status                 # Check status"
    print_command "sudo ufw enable                 # Enable firewall"
    print_command "sudo ufw allow ssh              # Allow SSH"
    print_command "sudo ufw allow 80/tcp           # Allow HTTP"
else
    print_info "Firewall commands would be shown based on detected distribution"
fi

# Security Framework Demo
print_section "SECURITY FRAMEWORK"

if [[ "$SECURITY" == "SELinux" ]]; then
    print_info "Fedora SELinux Commands:"
    print_command "sestatus                        # Check SELinux status"
    print_command "sudo setenforce 0               # Set permissive mode"
    print_command "sudo setenforce 1               # Set enforcing mode"
    print_command "ls -Z /path/to/file             # View SELinux context"
elif [[ "$SECURITY" == "AppArmor" ]]; then
    print_info "Ubuntu AppArmor Commands:"
    print_command "sudo aa-status                  # Check AppArmor status"
    print_command "sudo aa-complain /path/profile  # Set complain mode"
    print_command "sudo aa-enforce /path/profile   # Set enforce mode"
    print_command "sudo systemctl reload apparmor  # Reload profiles"
else
    print_info "Security framework commands would be shown based on detected distribution"
fi

# Available Scripts Demo
print_section "AVAILABLE AUTOMATION SCRIPTS"
print_info "This repository includes practical scripts:"

if [ -d "scripts" ]; then
    for script in scripts/*.sh; do
        if [ -f "$script" ]; then
            script_name=$(basename "$script")
            case "$script_name" in
                "system_init.sh")
                    print_command "./$script  # Universal system initialization"
                    ;;
                "security_hardening.sh")
                    print_command "sudo ./$script  # Security hardening automation"
                    ;;
                "install_docker.sh")
                    print_command "./$script  # Docker installation"
                    ;;
                "system_monitor.sh")
                    print_command "./$script  # System health monitoring"
                    ;;
                *)
                    print_command "./$script  # $(echo $script_name | sed 's/.sh$//' | tr '_' ' ')"
                    ;;
            esac
        fi
    done
else
    print_command "./scripts/system_init.sh       # Universal system initialization"
    print_command "sudo ./scripts/security_hardening.sh  # Security hardening"
    print_command "./scripts/install_docker.sh    # Docker installation"
    print_command "./scripts/system_monitor.sh    # System monitoring"
fi

# System Information Demo
print_section "CURRENT SYSTEM STATUS"
print_command "Basic system information:"

print_output "Hostname: $(hostname)"
print_output "Uptime: $(uptime -p 2>/dev/null || uptime | awk '{print $3,$4}')"
print_output "Kernel: $(uname -r)"
print_output "Architecture: $(uname -m)"

if command -v free &> /dev/null; then
    memory_usage=$(free | awk 'NR==2{printf "%.1f%%", $3*100/$2}')
    print_output "Memory Usage: $memory_usage"
fi

if command -v df &> /dev/null; then
    disk_usage=$(df -h / | awk 'NR==2{print $5}')
    print_output "Root Disk Usage: $disk_usage"
fi

# Conclusion
print_section "LINUX EXPERT CAPABILITIES"
echo -e "${GREEN}✅ Distribution Detection${NC}        - Automatic Fedora/Ubuntu identification"
echo -e "${GREEN}✅ Package Management${NC}           - DNF and APT command expertise"
echo -e "${GREEN}✅ Security Configuration${NC}       - Firewall, SELinux, AppArmor setup"
echo -e "${GREEN}✅ System Administration${NC}        - Service management, monitoring"
echo -e "${GREEN}✅ Automation Scripts${NC}           - Ready-to-use bash scripts"
echo -e "${GREEN}✅ Configuration Files${NC}          - Pre-configured security templates"
echo -e "${GREEN}✅ Troubleshooting Guides${NC}       - Common issue resolution"
echo -e "${GREEN}✅ Best Practices${NC}               - Security hardening recommendations"

echo -e "\n${CYAN}🎯 Ready to assist with your Linux administration needs!${NC}"
echo -e "${BLUE}📚 Full documentation available in README.md${NC}"
echo -e "${YELLOW}🛠️  Scripts available in the scripts/ directory${NC}"
echo -e "${PURPLE}⚙️  Configuration templates in configs/ directory${NC}\n"