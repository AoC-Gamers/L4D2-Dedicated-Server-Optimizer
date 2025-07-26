#!/bin/bash
# modules/ipv6_disable.sh
# This module disables IPv6 to improve network performance and avoid connectivity issues:
# - Disables IPv6 via sysctl parameters (net.ipv6.conf.all.disable_ipv6)
# - Disables IPv6 on loopback and default interface
# - Persists changes in /etc/sysctl.conf
# - Optionally adds ipv6.disable=1 to GRUB for complete disabling
# Checks current state before applying changes.

# Module registration function
register_module() {
  MODULE_NAME="ipv6_disable"
  MODULE_DESCRIPTION="Disable IPv6 Protocol (Network Performance)"
  MODULE_VERSION="1.2.0"
  MODULE_CATEGORY="network"
  MODULE_TIMEOUT=45
  MODULE_REQUIRES_REBOOT=false
  MODULE_ENVIRONMENT="both"
  MODULE_DEPENDENCIES=()
  MODULE_REQUIRED_PACKAGES=()
  MODULE_SUPPORTED_SYSTEMS=("debian,11" "debian,12" "ubuntu,20.04" "ubuntu,22.04" "ubuntu,24.04")
  MODULE_AUTHOR="AoC-Gamers"
  MODULE_DOCUMENTATION_URL="https://github.com/AoC-Gamers/L4D2-Optimizer"
  MODULE_GAME_IMPACT="Disables IPv6 to reduce network complexity and potential connection issues"
  
  # Environment Variables Configuration
  MODULE_ENV_VARIABLES=("NETWORK_IPV6_DISABLE_METHOD" "NETWORK_IPV6_GRUB_UPDATE")
  
  # Backup Configuration
  MODULE_REQUIRES_BACKUP=true
  MODULE_BACKUP_FILES=("/etc/sysctl.conf" "/etc/default/grub" "/proc/sys/net/ipv6/conf/all/disable_ipv6")
  MODULE_BACKUP_COMMANDS=("ip -6 addr show" "sysctl -a | grep ipv6" "grep ipv6 /etc/default/grub")
}

# Only execute if not being sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  MODULE_NAME="ipv6_disable"

log_message "$MODULE_NAME" "INFO" "Starting IPv6 disabling process"

# Check if IPv6 is already disabled globally
current_ipv6_all=$(sysctl -n net.ipv6.conf.all.disable_ipv6 2>/dev/null || echo "0")
if [[ "$current_ipv6_all" -eq 1 ]]; then
  log_message "$MODULE_NAME" "INFO" "IPv6 already disabled globally"
else
  log_message "$MODULE_NAME" "INFO" "Disabling IPv6 globally"
  sysctl -w net.ipv6.conf.all.disable_ipv6=1
  sed -i '/^net.ipv6.conf.all.disable_ipv6=/d' /etc/sysctl.conf
  echo 'net.ipv6.conf.all.disable_ipv6=1' >> /etc/sysctl.conf
  log_message "$MODULE_NAME" "SUCCESS" "IPv6 disabled globally"
fi

# Check if IPv6 is disabled on default interface
current_ipv6_default=$(sysctl -n net.ipv6.conf.default.disable_ipv6 2>/dev/null || echo "0")
if [[ "$current_ipv6_default" -eq 1 ]]; then
  log_message "$MODULE_NAME" "INFO" "IPv6 already disabled on default interface"
else
  log_message "$MODULE_NAME" "INFO" "Disabling IPv6 on default interface"
  sysctl -w net.ipv6.conf.default.disable_ipv6=1
  sed -i '/^net.ipv6.conf.default.disable_ipv6=/d' /etc/sysctl.conf
  echo 'net.ipv6.conf.default.disable_ipv6=1' >> /etc/sysctl.conf
  log_message "$MODULE_NAME" "SUCCESS" "IPv6 disabled on default interface"
fi

# Check if IPv6 is disabled on loopback
current_ipv6_lo=$(sysctl -n net.ipv6.conf.lo.disable_ipv6 2>/dev/null || echo "0")
if [[ "$current_ipv6_lo" -eq 1 ]]; then
  log_message "$MODULE_NAME" "INFO" "IPv6 already disabled on loopback"
else
  log_message "$MODULE_NAME" "INFO" "Disabling IPv6 on loopback"
  sysctl -w net.ipv6.conf.lo.disable_ipv6=1
  sed -i '/^net.ipv6.conf.lo.disable_ipv6=/d' /etc/sysctl.conf
  echo 'net.ipv6.conf.lo.disable_ipv6=1' >> /etc/sysctl.conf
  log_message "$MODULE_NAME" "SUCCESS" "IPv6 disabled on loopback"
fi

# Check and configure GRUB for complete IPv6 disabling
if [[ -f /etc/default/grub ]]; then
  if grep -q "ipv6.disable=1" /etc/default/grub; then
    log_message "$MODULE_NAME" "INFO" "IPv6 already disabled in GRUB"
  else
    log_message "$MODULE_NAME" "INFO" "Adding IPv6 disable parameter to GRUB"
    if grep -q "GRUB_CMDLINE_LINUX_DEFAULT=" /etc/default/grub; then
      sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="ipv6.disable=1 /' /etc/default/grub
    else
      echo 'GRUB_CMDLINE_LINUX_DEFAULT="ipv6.disable=1"' >> /etc/default/grub
    fi
    update-grub
    log_message "$MODULE_NAME" "SUCCESS" "IPv6 disable parameter added to GRUB"
  fi
else
  log_message "$MODULE_NAME" "WARNING" "GRUB configuration file not found, skipping GRUB modification"
fi

# Verify IPv6 status
ipv6_status=$(ip -6 addr show 2>/dev/null | wc -l)
if [[ "$ipv6_status" -eq 0 ]]; then
  log_message "$MODULE_NAME" "SUCCESS" "IPv6 successfully disabled - no IPv6 addresses found"
else
  log_message "$MODULE_NAME" "INFO" "IPv6 addresses still present, reboot may be required for complete disabling"
fi

log_message "$MODULE_NAME" "SUCCESS" "IPv6 disabling process completed"
exit 0
fi
