#!/bin/bash
# modules/disk_opt.sh
# This module optimizes the storage subsystem:
# - Automatically detects the main disk.
# - Adjusts I/O scheduler to mq-deadline for low latency on SSD/HDD drives.
# - Persists the elevator=mq-deadline parameter in /etc/default/grub.
# Checks current state before applying changes.

# Module registration function
register_module() {
  MODULE_NAME="disk_optimization"
  MODULE_DESCRIPTION="Disk I/O Scheduler Optimization (mq-deadline)"
  MODULE_VERSION="1.2.0"
  MODULE_CATEGORY="disk"
  MODULE_TIMEOUT=60
  MODULE_REQUIRES_REBOOT=false
  MODULE_ENVIRONMENT="host"
  MODULE_DEPENDENCIES=()
  MODULE_REQUIRED_PACKAGES=()
  MODULE_SUPPORTED_SYSTEMS=("debian,11" "debian,12" "ubuntu,20.04" "ubuntu,22.04" "ubuntu,24.04")
  MODULE_AUTHOR="AoC-Gamers"
  MODULE_DOCUMENTATION_URL="https://github.com/AoC-Gamers/L4D2-Optimizer"
  MODULE_GAME_IMPACT="Optimizes disk I/O scheduler for reduced latency and better game loading times"
  
  # Environment Variables Configuration
  MODULE_ENV_VARIABLES=("DISK_SCHEDULER" "DISK_TARGET_DEVICE" "DISK_UPDATE_GRUB")
  
  # Backup Configuration
  MODULE_REQUIRES_BACKUP=true
  MODULE_BACKUP_FILES=("/etc/default/grub" "/sys/block/*/queue/scheduler")
  MODULE_BACKUP_COMMANDS=("lsblk -o NAME,TYPE,FSTYPE,SIZE,MOUNTPOINT" "cat /sys/block/*/queue/scheduler" "grep GRUB_CMDLINE /etc/default/grub")
}

# Only execute if not being sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  MODULE_NAME="disk_optimization"

log_message "$MODULE_NAME" "INFO" "Checking scheduler and elevator"

# Detect main disk
device=$(lsblk -ndo NAME,TYPE | awk '$2 == "disk" {print "/dev/"$1; exit}')
elevator_file="/sys/block/$(basename $device)/queue/scheduler"

# Scheduler = mq-deadline
current_scheduler=$(cat "$elevator_file" | tr -d '[]')
if [[ "$current_scheduler" == "mq-deadline" ]]; then
  log_message "$MODULE_NAME" "INFO" "Scheduler already set to mq-deadline"
else
  log_message "$MODULE_NAME" "INFO" "Setting scheduler to mq-deadline"
  echo mq-deadline > "$elevator_file"
  # Persist in grub
  if grep -q "elevator=" /etc/default/grub; then
    sed -i 's/elevator=[^ ]*/elevator=mq-deadline/' /etc/default/grub
  else
    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="elevator=mq-deadline /' /etc/default/grub
  fi
  update-grub
  log_message "$MODULE_NAME" "SUCCESS" "Scheduler configured to mq-deadline"
fi

log_message "$MODULE_NAME" "SUCCESS" "Disk optimization completed"
exit 0
fi