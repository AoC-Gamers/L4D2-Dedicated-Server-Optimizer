#!/bin/bash
# modules/network_advanced.sh
# This module applies advanced QDisc and MTU settings:
# - Configures qdisc fq_codel to mitigate bufferbloat.
# - Increases MTU to 9000 for jumbo frames if network supports it.
# - Disables GRO/GSO/TSO on the interface.
# Checks current state before applying changes.

# Module registration function
register_module() {
  MODULE_NAME="network_advanced"
  MODULE_DESCRIPTION="Advanced Network Settings (QDisc, MTU, Offloads)"
  MODULE_VERSION="1.2.0"
  MODULE_CATEGORY="network"
  MODULE_TIMEOUT=60
  MODULE_REQUIRES_REBOOT=false
  MODULE_ENVIRONMENT="host"
  MODULE_DEPENDENCIES=()
  MODULE_REQUIRED_PACKAGES=("iproute2" "ethtool")
  MODULE_SUPPORTED_SYSTEMS=("debian,11" "debian,12" "ubuntu,20.04" "ubuntu,22.04" "ubuntu,24.04")
  MODULE_AUTHOR="AoC-Gamers"
  MODULE_DOCUMENTATION_URL="https://github.com/AoC-Gamers/L4D2-Optimizer"
  MODULE_GAME_IMPACT="Applies advanced network optimizations for reduced bufferbloat and improved throughput"
  
  # Environment Variables Configuration
  MODULE_ENV_VARIABLES=("NETWORK_QDISC_TYPE" "NETWORK_MTU_SIZE" "NETWORK_DISABLE_OFFLOADS" "NETWORK_TARGET_INTERFACE")
  
  # Backup Configuration
  MODULE_REQUIRES_BACKUP=true
  MODULE_BACKUP_FILES=("/sys/class/net/*/mtu" "/sys/class/net/*/queues/*/qdisc")
  MODULE_BACKUP_COMMANDS=("ip route get 8.8.8.8" "tc qdisc show" "ethtool -k \$(ip route get 8.8.8.8 | awk '{print \$5; exit}')" "ip link show")
}

# Only execute if not being sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  MODULE_NAME="network_advanced"

log_message "$MODULE_NAME" "INFO" "Starting advanced network settings"

# Detect interface
IFACE=$(ip route get 8.8.8.8 2>/dev/null | awk '{print $5; exit}')
if [[ -z "$IFACE" ]]; then
  log_message "$MODULE_NAME" "WARNING" "Could not detect interface, skipping module"
  exit 0
fi

# QDisc fq_codel
current_qdisc=$(tc qdisc show dev $IFACE | grep -o 'fq_codel' || true)
if [[ "$current_qdisc" == "fq_codel" ]]; then
  log_message "$MODULE_NAME" "INFO" "qdisc fq_codel already applied"
else
  log_message "$MODULE_NAME" "INFO" "Applying qdisc fq_codel"
  tc qdisc del dev $IFACE root 2>/dev/null
  tc qdisc add dev $IFACE root fq_codel
  log_message "$MODULE_NAME" "SUCCESS" "qdisc fq_codel configured"
fi

# Jumbo Frames MTU=9000
current_mtu=$(ip link show $IFACE | grep -o 'mtu [0-9]\+' | awk '{print $2}')
desired_mtu=9000
if [[ "$current_mtu" -eq $desired_mtu ]]; then
  log_message "$MODULE_NAME" "INFO" "MTU already set to $desired_mtu"
else
  log_message "$MODULE_NAME" "INFO" "Setting MTU to $desired_mtu"
  ip link set dev $IFACE mtu $desired_mtu
  log_message "$MODULE_NAME" "SUCCESS" "MTU configured to $desired_mtu"
fi

# Disable UDP offloads
log_message "$MODULE_NAME" "INFO" "Disabling GRO/GSO/TSO"
ethtool -K $IFACE gro off gso off tso off
log_message "$MODULE_NAME" "SUCCESS" "Offloads disabled"

log_message "$MODULE_NAME" "SUCCESS" "Advanced network settings completed"
exit 0
fi