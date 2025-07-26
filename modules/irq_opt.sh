#!/bin/bash
# modules/irq_opt.sh
# This module optimizes network and CPU interrupt distribution:
# - Checks and installs irqbalance, enabling it.
# - Configures RPS/XPS to distribute network load across CPUs.
# - Verifies current state before applying changes.

# Module registration function
register_module() {
  MODULE_NAME="irq_optimization"
  MODULE_DESCRIPTION="IRQ and CPU Affinity Optimization (IRQBalance, RPS/XPS)"
  MODULE_VERSION="1.2.0"
  MODULE_CATEGORY="cpu"
  MODULE_TIMEOUT=60
  MODULE_REQUIRES_REBOOT=false
  MODULE_DEPENDENCIES=()
  MODULE_REQUIRED_PACKAGES=("irqbalance")
  MODULE_SUPPORTED_SYSTEMS=("debian,11" "debian,12" "ubuntu,20.04" "ubuntu,22.04" "ubuntu,24.04")
  MODULE_AUTHOR="AoC-Gamers"
  MODULE_DOCUMENTATION_URL="https://github.com/AoC-Gamers/L4D2-Optimizer"
  MODULE_GAME_IMPACT="Optimizes interrupt distribution across CPU cores for better performance"
  
  # Environment variables used by this module
  MODULE_ENV_VARIABLES=("CPU_IRQ_BALANCE_ENABLED" "CPU_RPS_ENABLED")
  
  # Backup Configuration
  MODULE_REQUIRES_BACKUP=true
  MODULE_BACKUP_FILES=("/proc/interrupts" "/sys/class/net/*/queues/rx-*/rps_cpus")
  MODULE_BACKUP_COMMANDS=("systemctl status irqbalance" "cat /proc/interrupts" "lscpu | grep -E 'CPU|Core|Thread'")
}

# Only execute if not being sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  MODULE_NAME="irq_optimization"

log_message "$MODULE_NAME" "INFO" "Starting IRQ and CPU affinity optimization"

# Detect active network interface
log_message "$MODULE_NAME" "INFO" "Detecting network interface"
IFACE=$(ip route get 8.8.8.8 2>/dev/null | awk '{print $5; exit}')
if [[ -z "$IFACE" ]]; then
  log_message "$MODULE_NAME" "WARNING" "Could not detect interface, skipping module"
  exit 0
fi

# Check irqbalance
log_message "$MODULE_NAME" "INFO" "Checking irqbalance"
if ! command -v irqbalance &> /dev/null; then
  log_message "$MODULE_NAME" "INFO" "irqbalance not installed, installing..."
  apt update && apt install -y irqbalance
  systemctl enable irqbalance
  systemctl start irqbalance
  log_message "$MODULE_NAME" "SUCCESS" "irqbalance installed and enabled"
else
  log_message "$MODULE_NAME" "INFO" "irqbalance already installed and enabled"
fi

# Configure RPS/XPS
CPUS=$(nproc)
MASK=$(printf '%x' $(( (1 << CPUS) - 1 )))
# RPS on rx-0
RPS_FILE="/sys/class/net/$IFACE/queues/rx-0/rps_cpus"
if [[ -f "$RPS_FILE" ]]; then
  current_mask=$(cat "$RPS_FILE")
  if [[ "$current_mask" == "$MASK" ]]; then
    log_message "$MODULE_NAME" "INFO" "RPS already configured with mask $MASK"
  else
    log_message "$MODULE_NAME" "INFO" "Configuring RPS to mask $MASK"
    echo "$MASK" > "$RPS_FILE"
    log_message "$MODULE_NAME" "SUCCESS" "RPS configured with mask $MASK"
  fi
else
  log_message "$MODULE_NAME" "WARNING" "RPS file does not exist, skipping RPS configuration"
fi

log_message "$MODULE_NAME" "SUCCESS" "IRQ optimization completed"
exit 0
fi