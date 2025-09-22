#!/bin/bash
# system_monitor.sh - Comprehensive system monitoring script

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_header() {
    echo -e "${CYAN}==== $1 ====${NC}"
}

print_info() {
    echo -e "${BLUE}$1${NC}"
}

print_warning() {
    echo -e "${YELLOW}$1${NC}"
}

print_error() {
    echo -e "${RED}$1${NC}"
}

print_success() {
    echo -e "${GREEN}$1${NC}"
}

# System Information
print_header "SYSTEM INFORMATION"
echo "Hostname: $(hostname)"
echo "Uptime: $(uptime -p)"
echo "Current Time: $(date)"
echo "Kernel: $(uname -r)"
echo "Architecture: $(uname -m)"

if [ -f /etc/os-release ]; then
    source /etc/os-release
    echo "OS: $PRETTY_NAME"
fi

echo

# CPU Information
print_header "CPU INFORMATION"
echo "CPU Model: $(lscpu | grep 'Model name' | cut -d: -f2 | xargs)"
echo "CPU Cores: $(nproc)"
echo "CPU Usage:"
top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print "  " 100 - $1 "%"}'

# Load Average
load_avg=$(uptime | awk -F'load average:' '{print $2}')
echo "Load Average: $load_avg"

# CPU Temperature (if available)
if command -v sensors &> /dev/null; then
    temp=$(sensors | grep -E "(Core|Package)" | head -1 | awk '{print $3}')
    if [ ! -z "$temp" ]; then
        echo "CPU Temperature: $temp"
    fi
fi

echo

# Memory Information
print_header "MEMORY INFORMATION"
free -h | while read line; do
    if [[ $line == Mem:* ]]; then
        echo "Physical Memory:"
        echo "  $line" | awk '{printf "  Total: %s, Used: %s, Free: %s, Available: %s\n", $2, $3, $4, $7}'
    elif [[ $line == Swap:* ]]; then
        echo "Swap Memory:"
        echo "  $line" | awk '{printf "  Total: %s, Used: %s, Free: %s\n", $2, $3, $4}'
    fi
done

# Memory usage percentage
mem_usage=$(free | awk 'NR==2{printf "%.1f%%", $3*100/$2}')
echo "Memory Usage: $mem_usage"

echo

# Disk Information
print_header "DISK INFORMATION"
echo "Disk Usage:"
df -h | grep -E '^/dev/' | while read line; do
    usage=$(echo $line | awk '{print $5}' | sed 's/%//')
    if [ $usage -gt 90 ]; then
        print_error "  $line"
    elif [ $usage -gt 75 ]; then
        print_warning "  $line"
    else
        echo "  $line"
    fi
done

echo
echo "Disk I/O (if iostat available):"
if command -v iostat &> /dev/null; then
    iostat -d 1 1 | tail -n +4
fi

echo

# Network Information
print_header "NETWORK INFORMATION"
echo "Network Interfaces:"
ip -4 addr show | grep -E '^[0-9]+:' -A2 | while read line; do
    if [[ $line =~ ^[0-9]+: ]]; then
        interface=$(echo $line | cut -d: -f2 | xargs)
        echo "  Interface: $interface"
    elif [[ $line =~ inet ]]; then
        ip=$(echo $line | awk '{print $2}')
        echo "    IP: $ip"
    fi
done

echo
echo "Network Connections:"
ss_output=$(ss -tuln 2>/dev/null | grep LISTEN | wc -l)
echo "  Listening ports: $ss_output"

# Check for common services
echo "  Common services:"
for port in 22 80 443 3306 5432; do
    if ss -tuln | grep -q ":$port "; then
        case $port in
            22) service="SSH" ;;
            80) service="HTTP" ;;
            443) service="HTTPS" ;;
            3306) service="MySQL" ;;
            5432) service="PostgreSQL" ;;
        esac
        print_success "    $service (port $port): Running"
    fi
done

echo

# Process Information
print_header "PROCESS INFORMATION"
echo "Running Processes: $(ps aux | wc -l)"
echo "Active Users: $(who | wc -l)"

echo
echo "Top 5 CPU consuming processes:"
ps aux --sort=-%cpu | head -6 | tail -5 | while read line; do
    echo "  $line" | awk '{printf "  %-10s %5s%% %s\n", $1, $3, $11}'
done

echo
echo "Top 5 Memory consuming processes:"
ps aux --sort=-%mem | head -6 | tail -5 | while read line; do
    echo "  $line" | awk '{printf "  %-10s %5s%% %s\n", $1, $4, $11}'
done

echo

# System Services Status
print_header "SYSTEM SERVICES STATUS"
services=("ssh" "nginx" "apache2" "mysql" "postgresql" "docker" "firewalld" "ufw")

for service in "${services[@]}"; do
    if systemctl list-unit-files | grep -q "^$service.service"; then
        status=$(systemctl is-active $service 2>/dev/null)
        if [ "$status" = "active" ]; then
            print_success "  $service: $status"
        else
            echo "  $service: $status"
        fi
    fi
done

echo

# Security Status
print_header "SECURITY STATUS"

# Check firewall status
if command -v firewall-cmd &> /dev/null; then
    fw_status=$(firewall-cmd --state 2>/dev/null)
    if [ "$fw_status" = "running" ]; then
        print_success "  Firewalld: $fw_status"
    else
        print_warning "  Firewalld: $fw_status"
    fi
elif command -v ufw &> /dev/null; then
    ufw_status=$(ufw status | head -1 | awk '{print $2}')
    if [ "$ufw_status" = "active" ]; then
        print_success "  UFW: $ufw_status"
    else
        print_warning "  UFW: $ufw_status"
    fi
fi

# Check for fail2ban
if systemctl is-active fail2ban &> /dev/null; then
    print_success "  Fail2ban: active"
else
    echo "  Fail2ban: not active"
fi

# Check SELinux (Fedora/RHEL)
if command -v sestatus &> /dev/null; then
    selinux_status=$(sestatus | grep "SELinux status" | awk '{print $3}')
    echo "  SELinux: $selinux_status"
fi

# Check AppArmor (Ubuntu)
if command -v aa-status &> /dev/null; then
    apparmor_profiles=$(aa-status --enabled 2>/dev/null | wc -l)
    echo "  AppArmor: $apparmor_profiles profiles loaded"
fi

echo

# Log Analysis
print_header "LOG ANALYSIS (Last 24 hours)"

# System errors
error_count=$(journalctl --since "24 hours ago" --priority=err | wc -l)
if [ $error_count -gt 0 ]; then
    print_warning "  System errors: $error_count"
else
    print_success "  System errors: $error_count"
fi

# Failed login attempts
if [ -f /var/log/auth.log ]; then
    failed_logins=$(grep "Failed password" /var/log/auth.log | grep "$(date +%Y-%m-%d)" | wc -l)
elif [ -f /var/log/secure ]; then
    failed_logins=$(grep "Failed password" /var/log/secure | grep "$(date +%b)" | wc -l)
else
    failed_logins="N/A"
fi

if [ "$failed_logins" != "N/A" ] && [ $failed_logins -gt 10 ]; then
    print_warning "  Failed login attempts: $failed_logins"
else
    echo "  Failed login attempts: $failed_logins"
fi

echo

# System Health Summary
print_header "SYSTEM HEALTH SUMMARY"

# CPU usage check
cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
if (( $(echo "$cpu_usage > 80" | bc -l) )); then
    print_warning "  ⚠️  High CPU usage: ${cpu_usage}%"
else
    print_success "  ✅ CPU usage normal: ${cpu_usage}%"
fi

# Memory usage check
mem_usage_num=$(free | awk 'NR==2{printf "%.1f", $3*100/$2}')
if (( $(echo "$mem_usage_num > 80" | bc -l) )); then
    print_warning "  ⚠️  High memory usage: ${mem_usage_num}%"
else
    print_success "  ✅ Memory usage normal: ${mem_usage_num}%"
fi

# Disk usage check
max_disk_usage=$(df -h | grep -E '^/dev/' | awk '{print $5}' | sed 's/%//' | sort -nr | head -1)
if [ $max_disk_usage -gt 90 ]; then
    print_error "  🔴 Critical disk usage: ${max_disk_usage}%"
elif [ $max_disk_usage -gt 75 ]; then
    print_warning "  ⚠️  High disk usage: ${max_disk_usage}%"
else
    print_success "  ✅ Disk usage normal: ${max_disk_usage}%"
fi

# Load average check
load_1min=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
cpu_cores=$(nproc)
if (( $(echo "$load_1min > $cpu_cores" | bc -l) )); then
    print_warning "  ⚠️  High system load: $load_1min (cores: $cpu_cores)"
else
    print_success "  ✅ System load normal: $load_1min (cores: $cpu_cores)"
fi

echo
print_info "Monitoring completed at $(date)"