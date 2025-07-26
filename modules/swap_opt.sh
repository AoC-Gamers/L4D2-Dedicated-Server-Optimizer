#!/bin/bash
# modules/swap_opt.sh
# This module adjusts virtual memory parameters:
# - vm.swappiness: controls kernel tendency to use swap.
# - vm.overcommit_memory: allows memory overcommitment.
# Checks if they are already at desired values before applying.

# Module registration function
register_module() {
  MODULE_NAME="swap_optimization"
  MODULE_DESCRIPTION="Virtual Memory Optimization (Swappiness, Overcommit)"
  MODULE_VERSION="1.2.0"
  MODULE_CATEGORY="memory"
  MODULE_TIMEOUT=30
  MODULE_REQUIRES_REBOOT=false
  MODULE_DEPENDENCIES=()
  MODULE_REQUIRED_PACKAGES=()
  MODULE_SUPPORTED_OS=("debian" "ubuntu")
  MODULE_SUPPORTED_VERSIONS=("11" "12" "20.04" "22.04" "24.04")
  MODULE_AUTHOR="AoC-Gamers"
  MODULE_DOCUMENTATION_URL="https://github.com/AoC-Gamers/L4D2-Optimizer"
  MODULE_GAME_IMPACT="Improves memory management and reduces swap usage for better game performance"
  
  # Environment variables used by this module
  MODULE_ENV_VARIABLES=("MEMORY_SWAPPINESS" "MEMORY_OVERCOMMIT_MEMORY")
  
  # Backup Configuration
  MODULE_REQUIRES_BACKUP=true
  MODULE_BACKUP_FILES=("/etc/sysctl.conf" "/proc/sys/vm/swappiness" "/proc/sys/vm/overcommit_memory")
  MODULE_BACKUP_COMMANDS=("sysctl -a | grep -E '(swappiness|overcommit)'" "free -h" "cat /proc/meminfo | grep -E '(Swap|Commit)'")
}

# Only execute if not being sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  MODULE_NAME="swap_optimization"

log_message "$MODULE_NAME" "INFO" "Starting virtual memory parameters check"

# Swappiness = 10
current_swappiness=$(sysctl -n vm.swappiness)
if [[ "$current_swappiness" -eq 10 ]]; then
  log_message "$MODULE_NAME" "INFO" "vm.swappiness already set to 10"
else
  log_message "$MODULE_NAME" "INFO" "Setting vm.swappiness to 10"
  sysctl -w vm.swappiness=10
  sed -i '/^vm.swappiness=/d' /etc/sysctl.conf
  echo 'vm.swappiness=10' >> /etc/sysctl.conf
  log_message "$MODULE_NAME" "SUCCESS" "vm.swappiness configured to 10"
fi

# Overcommit = 1
current_overcommit=$(sysctl -n vm.overcommit_memory)
if [[ "$current_overcommit" -eq 1 ]]; then
  log_message "$MODULE_NAME" "INFO" "vm.overcommit_memory already set to 1"
else
  log_message "$MODULE_NAME" "INFO" "Setting vm.overcommit_memory to 1"
  sysctl -w vm.overcommit_memory=1
  sed -i '/^vm.overcommit_memory=/d' /etc/sysctl.conf
  echo 'vm.overcommit_memory=1' >> /etc/sysctl.conf
  log_message "$MODULE_NAME" "SUCCESS" "vm.overcommit_memory configured to 1"
fi

log_message "$MODULE_NAME" "SUCCESS" "Virtual memory optimizations completed"
exit 0
fi