# 🛠️ Linux Expert Scripts

This directory contains practical scripts for Linux system administration, security, and automation.

## 📁 Available Scripts

### 🚀 system_init.sh
**Purpose**: Universal Linux system initialization script  
**Description**: Automatically detects Fedora/Ubuntu and performs initial system setup including:
- System updates
- Essential package installation
- Development tools (optional)
- Git configuration
- Automatic security updates setup
- System information display

**Usage**:
```bash
./system_init.sh
```

**Requirements**: 
- Run as regular user (not root)
- Sudo privileges required

---

### 🔐 security_hardening.sh
**Purpose**: Basic security hardening for Linux systems  
**Description**: Implements security best practices including:
- Automatic security updates
- SSH hardening (disable root login, password auth)
- Firewall configuration
- Fail2ban installation and setup
- Kernel security parameters
- Secure file permissions
- Log monitoring setup

**Usage**:
```bash
sudo ./security_hardening.sh
```

**Requirements**: 
- Run as root
- ⚠️ **Warning**: Disables SSH password authentication - ensure SSH keys are set up first!

---

### 🐳 install_docker.sh
**Purpose**: Docker installation script for Fedora/Ubuntu  
**Description**: Comprehensive Docker setup including:
- Clean removal of old Docker installations
- Official Docker repository setup
- Docker Engine and Docker Compose installation
- User group configuration
- Docker daemon optimization
- Useful Docker aliases

**Usage**:
```bash
./install_docker.sh
```

**Requirements**: 
- Run as regular user (not root)
- Sudo privileges required
- Internet connection for downloading packages

**Post-installation**: Log out and log back in for group changes to take effect

---

### 📊 system_monitor.sh
**Purpose**: Comprehensive system monitoring and health check  
**Description**: Provides detailed system information including:
- System and hardware information
- CPU, memory, and disk usage
- Network interface status
- Running processes and services
- Security status (firewall, fail2ban, SELinux/AppArmor)
- Log analysis for errors and failed logins
- System health summary with warnings

**Usage**:
```bash
./system_monitor.sh
```

**Requirements**: 
- Run as regular user
- Some features require specific tools (sensors, iostat, bc)

---

## 🎯 Quick Start Guide

1. **First-time setup** (new system):
   ```bash
   ./system_init.sh
   ```

2. **Security hardening** (ensure SSH keys are configured first):
   ```bash
   sudo ./security_hardening.sh
   ```

3. **Install Docker** (for containerization):
   ```bash
   ./install_docker.sh
   ```

4. **Monitor system** (anytime):
   ```bash
   ./system_monitor.sh
   ```

## 📋 Prerequisites

### Common Requirements
- Bash shell
- Sudo privileges (for most scripts)
- Internet connection (for package downloads)

### Distribution Support
- ✅ Fedora (all recent versions)
- ✅ Ubuntu (18.04 LTS and later)
- ⚠️ Other distributions may work but are not officially supported

### Optional Tools (for enhanced functionality)
```bash
# Fedora
sudo dnf install -y lm_sensors sysstat bc

# Ubuntu  
sudo apt install -y lm-sensors sysstat bc
```

## ⚠️ Important Notes

### Security Considerations
- **Always review scripts before running them**
- **Test scripts in a safe environment first**
- **Backup important configurations before running security hardening**
- **Ensure SSH key authentication is working before running security_hardening.sh**

### Script Execution Order
1. Run `system_init.sh` first on new systems
2. Set up SSH keys if not already configured
3. Run `security_hardening.sh` for security improvements
4. Install Docker with `install_docker.sh` if needed
5. Use `system_monitor.sh` for ongoing monitoring

## 🔧 Customization

All scripts are designed to be modular and can be customized:
- Edit variables at the top of each script
- Comment out sections you don't need
- Add additional packages or configurations as needed

## 📝 Logging

Scripts provide colored output for easy reading:
- 🔵 **Blue**: Information messages
- 🟢 **Green**: Success messages  
- 🟡 **Yellow**: Warning messages
- 🔴 **Red**: Error messages

## 🆘 Troubleshooting

### Common Issues

1. **Permission denied**:
   ```bash
   chmod +x script_name.sh
   ```

2. **Script not found**:
   ```bash
   ./script_name.sh  # Include the ./
   ```

3. **Sudo password prompts**:
   - Some scripts require sudo privileges
   - You'll be prompted for your password

4. **Network issues**:
   - Ensure internet connectivity for package downloads
   - Check DNS resolution if downloads fail

### Getting Help

If you encounter issues:
1. Check the script output for specific error messages
2. Ensure all prerequisites are met
3. Run individual commands manually to identify the problem
4. Check system logs: `sudo journalctl -n 50`

## 📚 Additional Resources

- [Linux System Administration Guide](../README.md)
- [Fedora Documentation](https://docs.fedoraproject.org/)
- [Ubuntu Documentation](https://help.ubuntu.com/)
- [Docker Documentation](https://docs.docker.com/)

---

*These scripts are part of the Linux Expert repository maintained by @rkohli35-cyber*