#!/bin/bash
# modules/thp_disable.sh
# This module disables Transparent HugePages (THP) to improve memory latency:
# - Changes the value of /sys/kernel/mm/transparent_hugepage/enabled to "never".
# - Creates and enables a systemd service to apply the setting on each boot.
# Checks current state before applying changes.

# Module registration function
register_module() {
  MODULE_NAME="thp_disable"
  MODULE_DESCRIPTION="Disable Transparent HugePages (Memory Latency)"
  MODULE_VERSION="1.2.0"
  MODULE_CATEGORY="memory"
  MODULE_TIMEOUT=30
  MODULE_REQUIRES_REBOOT=false
  MODULE_ENVIRONMENT="host"
  MODULE_DEPENDENCIES=()
  MODULE_REQUIRED_PACKAGES=()
  MODULE_SUPPORTED_SYSTEMS=("debian,11" "debian,12" "ubuntu,20.04" "ubuntu,22.04" "ubuntu,24.04")
  MODULE_AUTHOR="AoC-Gamers"
  MODULE_DOCUMENTATION_URL="https://github.com/AoC-Gamers/L4D2-Optimizer"
  MODULE_GAME_IMPACT="Reduces memory allocation latency by disabling transparent huge pages"
  
  # Environment Variables Configuration
  MODULE_ENV_VARIABLES=("MEMORY_THP_MODE" "MEMORY_THP_SERVICE_CREATE")
  
  # Backup Configuration
  MODULE_REQUIRES_BACKUP=true
  MODULE_BACKUP_FILES=("/sys/kernel/mm/transparent_hugepage/enabled" "/etc/systemd/system/disable-thp.service")
  MODULE_BACKUP_COMMANDS=("cat /sys/kernel/mm/transparent_hugepage/enabled" "systemctl status disable-thp")
}

# Only execute if not being sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  MODULE_NAME="thp_disable"

log_message "$MODULE_NAME" "INFO" "Checking Transparent HugePages status"

thp_file="/sys/kernel/mm/transparent_hugepage/enabled"
if [[ ! -f "$thp_file" ]]; then
  log_message "$MODULE_NAME" "WARNING" "THP file not found, skipping module"
  exit 0
fi

current_thp=$(awk -F"[\[\]]" '{print $2}' $thp_file)
if [[ "$current_thp" == "never" ]]; then
  log_message "$MODULE_NAME" "INFO" "THP already disabled (never)"
else
  log_message "$MODULE_NAME" "INFO" "Disabling Transparent HugePages"
  echo never > $thp_file
  log_message "$MODULE_NAME" "SUCCESS" "THP disabled"
fi

# Create systemd service if it doesn't exist
service_file="/etc/systemd/system/disable-thp.service"
if [[ -f "$service_file" ]]; then
  log_message "$MODULE_NAME" "INFO" "disable-thp service already exists"
else
  log_message "$MODULE_NAME" "INFO" "Creating disable-thp service"
  cat <<EOF > $service_file
[Unit]
Description=Disable Transparent HugePages
After=sysinit.target local-fs.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo never > $thp_file'

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable disable-thp
  log_message "$MODULE_NAME" "SUCCESS" "disable-thp service created and enabled"
fi

log_message "$MODULE_NAME" "SUCCESS" "THP configuration completed"
exit 0
fi