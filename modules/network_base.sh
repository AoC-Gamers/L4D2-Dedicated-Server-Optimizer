#!/bin/bash
# modules/network_base.sh
# This module applies base network settings to ensure UDP connectivity and performance:
# - Configures kernel buffers (rmem_max, wmem_max).
# - Adjusts network backlog (netdev_max_backlog).
# - Checks current state before applying changes.

# Module registration function
register_module() {
  MODULE_NAME="network_base"
  MODULE_DESCRIPTION="Base Network Configuration (Buffers, Backlog)"
  MODULE_VERSION="1.1.0"
  MODULE_CATEGORY="network"
  MODULE_TIMEOUT=45
  MODULE_REQUIRES_REBOOT=false
  MODULE_DEPENDENCIES=()
  MODULE_REQUIRED_PACKAGES=()
  MODULE_SUPPORTED_OS=("debian" "ubuntu")
  MODULE_SUPPORTED_VERSIONS=("11" "12" "20.04" "22.04" "24.04")
  MODULE_AUTHOR="AoC-Gamers"
  MODULE_DOCUMENTATION_URL="https://github.com/AoC-Gamers/L4D2-Optimizer"
  MODULE_GAME_IMPACT="Optimizes network buffers for reduced packet loss and improved UDP performance"
  
  # Environment Variables Configuration
  MODULE_ENV_VARIABLES=("NETWORK_RMEM_MAX" "NETWORK_WMEM_MAX" "NETWORK_NETDEV_BACKLOG")
  
  # Backup Configuration
  MODULE_REQUIRES_BACKUP=true
  MODULE_BACKUP_FILES=("/etc/sysctl.conf" "/proc/sys/net/core/rmem_max" "/proc/sys/net/core/wmem_max" "/proc/sys/net/core/netdev_max_backlog")
  MODULE_BACKUP_COMMANDS=("sysctl -a | grep -E '(rmem_max|wmem_max|netdev_max_backlog)'" "ss -tuln" "netstat -i")
}

# Only execute if not being sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  MODULE_NAME="network_base"

log_message "$MODULE_NAME" "INFO" "Checking base network parameters"

# Core parameters rmem_max and wmem_max
for param in rmem_max wmem_max; do
  current=$(sysctl -n net.core.${param})
  desired=262144
  if [[ "$current" -eq $desired ]]; then
    log_message "$MODULE_NAME" "INFO" "net.core.${param} already set to $desired"
  else
    log_message "$MODULE_NAME" "INFO" "Setting net.core.${param} to $desired"
    sysctl -w net.core.${param}=$desired
    sed -i "/^net.core.${param}=/d" /etc/sysctl.conf
    echo "net.core.${param}=$desired" >> /etc/sysctl.conf
    log_message "$MODULE_NAME" "SUCCESS" "net.core.${param} configured to $desired"
  fi
done

# Parameter netdev_max_backlog
current_backlog=$(sysctl -n net.core.netdev_max_backlog)
desired_backlog=5000
if [[ "$current_backlog" -eq $desired_backlog ]]; then
  log_message "$MODULE_NAME" "INFO" "net.core.netdev_max_backlog already set to $desired_backlog"
else
  log_message "$MODULE_NAME" "INFO" "Setting net.core.netdev_max_backlog to $desired_backlog"
  sysctl -w net.core.netdev_max_backlog=$desired_backlog
  sed -i "/^net.core.netdev_max_backlog=/d" /etc/sysctl.conf
  echo "net.core.netdev_max_backlog=$desired_backlog" >> /etc/sysctl.conf
  log_message "$MODULE_NAME" "SUCCESS" "net.core.netdev_max_backlog configured to $desired_backlog"
fi

log_message "$MODULE_NAME" "SUCCESS" "Base network parameters completed"
exit 0
fi