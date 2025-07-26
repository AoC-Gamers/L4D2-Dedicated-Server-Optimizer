#!/bin/bash
# modules/tcp_udp_params.sh
# Additional TCP/UDP parameters:
# - net.ipv4.tcp_congestion_control=bbr
# - net.ipv4.tcp_mtu_probing=1
# - net.core.optmem_max
# - net.ipv4.udp_mem, udp_rmem_min, udp_wmem_min
# With prior verification.

# Module registration function
register_module() {
  MODULE_NAME="tcp_udp_optimization"
  MODULE_DESCRIPTION="TCP/UDP Advanced Parameters (BBR, MTU, UDP Memory)"
  MODULE_VERSION="1.2.0"
  MODULE_CATEGORY="network"
  MODULE_TIMEOUT=45
  MODULE_REQUIRES_REBOOT=false
  MODULE_DEPENDENCIES=()
  MODULE_REQUIRED_PACKAGES=()
  MODULE_SUPPORTED_SYSTEMS=("debian,11" "debian,12" "ubuntu,20.04" "ubuntu,22.04" "ubuntu,24.04")
  MODULE_AUTHOR="AoC-Gamers"
  MODULE_DOCUMENTATION_URL="https://github.com/AoC-Gamers/L4D2-Optimizer"
  MODULE_GAME_IMPACT="Optimizes TCP congestion control and UDP memory for better network performance"
  
  # Environment Variables Configuration
  MODULE_ENV_VARIABLES=("NETWORK_TCP_CONGESTION" "NETWORK_TCP_MTU_PROBING" "NETWORK_OPTMEM_MAX" "NETWORK_UDP_MEM" "NETWORK_UDP_RMEM_MIN" "NETWORK_UDP_WMEM_MIN")
  
  # Backup Configuration
  MODULE_REQUIRES_BACKUP=true
  MODULE_BACKUP_FILES=("/etc/sysctl.conf" "/proc/sys/net/ipv4/tcp_congestion_control" "/proc/sys/net/core/optmem_max")
  MODULE_BACKUP_COMMANDS=("sysctl -a | grep -E '(tcp_congestion|tcp_mtu|optmem|udp_mem|udp_rmem|udp_wmem)'" "lsmod | grep bbr")
}

# Only execute if not being sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  MODULE_NAME="tcp_udp_optimization"

log_message "$MODULE_NAME" "INFO" "Starting TCP/UDP settings"

# TCP
curr=$(sysctl -n net.ipv4.tcp_congestion_control)
if [[ "$curr" != "bbr" ]]; then
    sysctl -w net.ipv4.tcp_congestion_control=bbr
    sed -i '/^net.ipv4.tcp_congestion_control=/d' /etc/sysctl.conf
    echo 'net.ipv4.tcp_congestion_control=bbr' >> /etc/sysctl.conf
    log_message "$MODULE_NAME" "SUCCESS" "TCP congestion_control configured to BBR"
else
    log_message "$MODULE_NAME" "INFO" "TCP congestion_control already set to BBR"
fi

curr=$(sysctl -n net.ipv4.tcp_mtu_probing)
if [[ "$curr" != 1 ]]; then
    sysctl -w net.ipv4.tcp_mtu_probing=1
    sed -i '/^net.ipv4.tcp_mtu_probing=/d' /etc/sysctl.conf
    echo 'net.ipv4.tcp_mtu_probing=1' >> /etc/sysctl.conf
    log_message "$MODULE_NAME" "SUCCESS" "TCP mtu_probing enabled"
else
    log_message "$MODULE_NAME" "INFO" "TCP mtu_probing already enabled"
fi

# optmem_max
curr=$(sysctl -n net.core.optmem_max)
des=262144
if [[ "$curr" -ne $des ]]; then
    sysctl -w net.core.optmem_max=$des
    sed -i '/^net.core.optmem_max=/d' /etc/sysctl.conf
    echo "net.core.optmem_max=$des" >> /etc/sysctl.conf
    log_message "$MODULE_NAME" "SUCCESS" "optmem_max set to $des"
else
    log_message "$MODULE_NAME" "INFO" "optmem_max already set to $des"
fi

# UDP
curr_udp_mem=$(sysctl -n net.ipv4.udp_mem)
if [[ "$curr_udp_mem" != "65536 131072 262144" ]]; then
    sysctl -w net.ipv4.udp_mem="65536 131072 262144"
    sed -i '/^net.ipv4.udp_mem=/d' /etc/sysctl.conf
    echo 'net.ipv4.udp_mem=65536 131072 262144' >> /etc/sysctl.conf
    log_message "$MODULE_NAME" "SUCCESS" "udp_mem configured"
else
    log_message "$MODULE_NAME" "INFO" "udp_mem already configured"
fi

curr_udp_rmem=$(sysctl -n net.ipv4.udp_rmem_min)
if [[ "$curr_udp_rmem" -ne 8192 ]]; then
    sysctl -w net.ipv4.udp_rmem_min=8192
    sed -i '/^net.ipv4.udp_rmem_min=/d' /etc/sysctl.conf
    echo 'net.ipv4.udp_rmem_min=8192' >> /etc/sysctl.conf
    log_message "$MODULE_NAME" "SUCCESS" "udp_rmem_min set to 8192"
else
    log_message "$MODULE_NAME" "INFO" "udp_rmem_min already set to 8192"
fi

curr_udp_wmem=$(sysctl -n net.ipv4.udp_wmem_min)
if [[ "$curr_udp_wmem" -ne 8192 ]]; then
    sysctl -w net.ipv4.udp_wmem_min=8192
    sed -i '/^net.ipv4.udp_wmem_min=/d' /etc/sysctl.conf
    echo 'net.ipv4.udp_wmem_min=8192' >> /etc/sysctl.conf
    log_message "$MODULE_NAME" "SUCCESS" "udp_wmem_min set to 8192"
else
    log_message "$MODULE_NAME" "INFO" "udp_wmem_min already set to 8192"
fi

log_message "$MODULE_NAME" "SUCCESS" "TCP/UDP optimizations completed"
exit 0
fi