#!/bin/bash
# modules/docker_networking.sh
# Docker Network Stack Optimization for L4D2 Competitive Gaming
# This module optimizes container networking for high-tickrate servers
# Focuses on reducing latency and improving packet processing within containers

# =============================================================================
# MODULE REGISTRATION FUNCTION (REQUIRED)
# =============================================================================
register_module() {
  # Basic Information (REQUIRED)
  MODULE_NAME="docker_networking_optimization"
  MODULE_DESCRIPTION="Container Network Stack and Buffer Optimization"
  MODULE_VERSION="1.0.0"
  
  # Category Selection (REQUIRED - choose one)
  MODULE_CATEGORY="network"
  
  # Execution Configuration (OPTIONAL)
  MODULE_TIMEOUT=45  # Network changes are quick
  MODULE_REQUIRES_REBOOT=false
  
  # Environment Compatibility (REQUIRED)
  MODULE_ENVIRONMENT="docker"
  
  # Dependencies and Requirements (OPTIONAL)
  MODULE_DEPENDENCIES=()
  MODULE_REQUIRED_PACKAGES=("iproute2" "procps" "net-tools")
  
  # System Compatibility (REQUIRED)
  MODULE_SUPPORTED_SYSTEMS=("debian,11" "debian,12" "ubuntu,20.04" "ubuntu,22.04" "ubuntu,24.04")
  
  # Documentation and Metadata (OPTIONAL)
  MODULE_AUTHOR="AoC-Gamers"
  MODULE_DOCUMENTATION_URL="https://github.com/AoC-Gamers/L4D2-Optimizer"
  
  # Gaming Impact Information (OPTIONAL)
  MODULE_GAME_IMPACT="Reduces network latency inside containers, optimizes buffer sizes for 100 tickrate, improves packet processing efficiency for competitive L4D2 servers"
  
  # Environment Variables Configuration (OPTIONAL)
  MODULE_ENV_VARIABLES=("DOCKER_NET_BUFFER_SIZE" "DOCKER_NET_ENABLE_FASTOPEN" "DOCKER_NET_OPTIMIZE_QUEUES" "DOCKER_NET_DISABLE_OFFLOAD")
  
  # Backup Configuration (OPTIONAL)
  MODULE_REQUIRES_BACKUP=true
  MODULE_BACKUP_FILES=("/proc/sys/net/core/*" "/proc/sys/net/ipv4/*")
  MODULE_BACKUP_COMMANDS=("ss -tuln" "netstat -i" "cat /proc/net/dev")
}

# =============================================================================
# NETWORK OPTIMIZATION FUNCTIONS
# =============================================================================

# Function to get available network interfaces
get_network_interfaces() {
  local interfaces=()
  
  # Get all active network interfaces (excluding loopback)
  while IFS= read -r interface; do
    if [[ "$interface" != "lo" && -n "$interface" ]]; then
      interfaces+=("$interface")
    fi
  done < <(ip link show | grep -E "^[0-9]+:" | grep -v "lo:" | cut -d: -f2 | tr -d ' ')
  
  echo "${interfaces[@]}"
}

# Function to optimize container network buffers
optimize_network_buffers() {
  local buffer_size="${DOCKER_NET_BUFFER_SIZE:-16777216}"  # 16MB default
  
  log_message "$MODULE_NAME" "INFO" "Optimizing network buffers for L4D2 competitive gaming"
  log_message "$MODULE_NAME" "INFO" "Target buffer size: $buffer_size bytes"
  
  # Network core optimizations
  local net_params=(
    "net.core.rmem_default:262144"
    "net.core.rmem_max:$buffer_size"
    "net.core.wmem_default:262144" 
    "net.core.wmem_max:$buffer_size"
    "net.core.netdev_max_backlog:5000"
    "net.core.netdev_budget:600"
    "net.core.somaxconn:1024"
  )
  
  for param in "${net_params[@]}"; do
    local key=$(echo "$param" | cut -d: -f1)
    local value=$(echo "$param" | cut -d: -f2)
    local sysctl_path="/proc/sys/${key//./\/}"
    
    if [[ -w "$sysctl_path" ]]; then
      if echo "$value" > "$sysctl_path" 2>/dev/null; then
        log_message "$MODULE_NAME" "SUCCESS" "Set $key=$value"
      else
        log_message "$MODULE_NAME" "WARNING" "Failed to set $key=$value"
      fi
    else
      log_message "$MODULE_NAME" "WARNING" "Cannot write to $sysctl_path (may require host-level change)"
    fi
  done
}

# Function to optimize TCP settings for gaming
optimize_tcp_gaming() {
  log_message "$MODULE_NAME" "INFO" "Optimizing TCP settings for low-latency gaming"
  
  # Gaming-specific TCP optimizations
  local tcp_params=(
    "net.ipv4.tcp_nodelay:1"                    # Disable Nagle's algorithm
    "net.ipv4.tcp_low_latency:1"                # Enable low latency mode
    "net.ipv4.tcp_fastopen:3"                   # Enable TCP Fast Open
    "net.ipv4.tcp_congestion_control:bbr"       # Use BBR congestion control
    "net.ipv4.tcp_rmem:4096 65536 16777216"    # TCP read buffer
    "net.ipv4.tcp_wmem:4096 65536 16777216"    # TCP write buffer
    "net.ipv4.tcp_timestamps:1"                 # Enable timestamps for RTT
    "net.ipv4.tcp_sack:1"                       # Enable selective ACK
    "net.ipv4.tcp_window_scaling:1"             # Enable window scaling
  )
  
  for param in "${tcp_params[@]}"; do
    local key=$(echo "$param" | cut -d: -f1)
    local value=$(echo "$param" | cut -d: -f2-)
    local sysctl_path="/proc/sys/${key//./\/}"
    
    if [[ -w "$sysctl_path" ]]; then
      if echo "$value" > "$sysctl_path" 2>/dev/null; then
        log_message "$MODULE_NAME" "SUCCESS" "Set $key=$value"
      else
        log_message "$MODULE_NAME" "WARNING" "Failed to set $key=$value"
      fi
    else
      log_message "$MODULE_NAME" "INFO" "Cannot modify $key (host-level setting required)"
    fi
  done
}

# Function to optimize UDP settings for Source engine
optimize_udp_gaming() {
  log_message "$MODULE_NAME" "INFO" "Optimizing UDP settings for Source engine"
  
  # UDP optimizations for gaming
  local udp_params=(
    "net.core.rmem_default:262144"
    "net.core.rmem_max:16777216"
    "net.core.wmem_default:262144"
    "net.core.wmem_max:16777216"
  )
  
  for param in "${udp_params[@]}"; do
    local key=$(echo "$param" | cut -d: -f1)
    local value=$(echo "$param" | cut -d: -f2)
    local sysctl_path="/proc/sys/${key//./\/}"
    
    if [[ -w "$sysctl_path" ]]; then
      if echo "$value" > "$sysctl_path" 2>/dev/null; then
        log_message "$MODULE_NAME" "SUCCESS" "Set $key=$value"
      else
        log_message "$MODULE_NAME" "WARNING" "Failed to set $key=$value"
      fi
    fi
  done
}

# Function to optimize network interface settings
optimize_interface_settings() {
  local interfaces=($(get_network_interfaces))
  local disable_offload="${DOCKER_NET_DISABLE_OFFLOAD:-true}"
  
  if [[ ${#interfaces[@]} -eq 0 ]]; then
    log_message "$MODULE_NAME" "WARNING" "No network interfaces found for optimization"
    return 1
  fi
  
  log_message "$MODULE_NAME" "INFO" "Optimizing interfaces: ${interfaces[*]}"
  
  for interface in "${interfaces[@]}"; do
    log_message "$MODULE_NAME" "INFO" "Optimizing interface: $interface"
    
    # Check if ethtool is available and interface exists
    if command -v ethtool >/dev/null 2>&1 && ip link show "$interface" >/dev/null 2>&1; then
      
      # Disable hardware offloading for lower latency (if enabled)
      if [[ "$disable_offload" == "true" ]]; then
        local offload_features=("gso" "tso" "lro" "gro" "rx-checksumming" "tx-checksumming")
        
        for feature in "${offload_features[@]}"; do
          if ethtool -K "$interface" "$feature" off >/dev/null 2>&1; then
            log_message "$MODULE_NAME" "SUCCESS" "Disabled $feature on $interface"
          else
            log_message "$MODULE_NAME" "INFO" "$feature not available or already disabled on $interface"
          fi
        done
      fi
      
      # Set ring buffer sizes if possible
      if ethtool -G "$interface" rx 512 tx 512 >/dev/null 2>&1; then
        log_message "$MODULE_NAME" "SUCCESS" "Set ring buffers for $interface"
      else
        log_message "$MODULE_NAME" "INFO" "Cannot modify ring buffers for $interface"
      fi
      
    else
      log_message "$MODULE_NAME" "WARNING" "ethtool not available or interface $interface not found"
    fi
    
    # Set interface queue length
    if ip link set dev "$interface" txqueuelen 1000 >/dev/null 2>&1; then
      log_message "$MODULE_NAME" "SUCCESS" "Set txqueuelen=1000 for $interface"
    else
      log_message "$MODULE_NAME" "WARNING" "Failed to set txqueuelen for $interface"
    fi
  done
}

# Function to setup network monitoring
setup_network_monitoring() {
  log_message "$MODULE_NAME" "INFO" "Setting up network performance monitoring"
  
  # Create network monitoring script
  cat > /tmp/l4d2_net_monitor.sh << 'EOF'
#!/bin/bash
# L4D2 Network Performance Monitor

LOGFILE="/tmp/l4d2_logs/network_stats.log"
mkdir -p "$(dirname "$LOGFILE")"

while true; do
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  
  # Get network statistics
  rx_bytes=$(cat /proc/net/dev | grep eth0 | awk '{print $2}')
  tx_bytes=$(cat /proc/net/dev | grep eth0 | awk '{print $10}')
  
  # Get UDP buffer usage
  udp_mem=$(cat /proc/net/sockstat | grep UDP | awk '{print $3}')
  
  # Log stats
  echo "[$timestamp] RX:$rx_bytes TX:$tx_bytes UDP_MEM:$udp_mem" >> "$LOGFILE"
  
  # Sleep for 10 seconds
  sleep 10
done
EOF
  
  chmod +x /tmp/l4d2_net_monitor.sh
  
  # Start monitor in background if not already running
  if ! pgrep -f "l4d2_net_monitor" >/dev/null; then
    nohup /tmp/l4d2_net_monitor.sh >/dev/null 2>&1 &
    log_message "$MODULE_NAME" "SUCCESS" "Started network monitoring"
  fi
}

# Function to verify network optimizations
verify_network_settings() {
  log_message "$MODULE_NAME" "INFO" "Verifying network optimizations:"
  
  # Show current buffer sizes
  echo "=== Network Buffer Sizes ==="
  echo "rmem_max: $(cat /proc/sys/net/core/rmem_max 2>/dev/null || echo 'N/A')"
  echo "wmem_max: $(cat /proc/sys/net/core/wmem_max 2>/dev/null || echo 'N/A')"
  echo "netdev_max_backlog: $(cat /proc/sys/net/core/netdev_max_backlog 2>/dev/null || echo 'N/A')"
  
  # Show TCP settings
  echo "=== TCP Settings ==="
  echo "tcp_nodelay: $(cat /proc/sys/net/ipv4/tcp_nodelay 2>/dev/null || echo 'N/A')"
  echo "tcp_fastopen: $(cat /proc/sys/net/ipv4/tcp_fastopen 2>/dev/null || echo 'N/A')"
  echo "tcp_congestion_control: $(cat /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null || echo 'N/A')"
  
  # Show interface statistics
  echo "=== Interface Statistics ==="
  cat /proc/net/dev | head -3
}

# =============================================================================
# MODULE EXECUTION LOGIC (REQUIRED)
# =============================================================================
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  
  MODULE_NAME="docker_networking_optimization"
  
  # Define log_message function if not available (fallback)
  if ! command -v log_message &> /dev/null; then
    log_message() {
      local module="$1"
      local type="$2" 
      local message="$3"
      echo "[$type] [$module] $message"
    }
  fi
  
  # Load configuration from environment variables
  BUFFER_SIZE="${DOCKER_NET_BUFFER_SIZE:-16777216}"
  ENABLE_FASTOPEN="${DOCKER_NET_ENABLE_FASTOPEN:-true}"
  OPTIMIZE_QUEUES="${DOCKER_NET_OPTIMIZE_QUEUES:-true}"
  DISABLE_OFFLOAD="${DOCKER_NET_DISABLE_OFFLOAD:-true}"
  
  log_message "$MODULE_NAME" "INFO" "=== Starting Docker Network Optimization ==="
  log_message "$MODULE_NAME" "INFO" "Optimizing for L4D2 competitive gaming (100 tick)"
  
  # Show initial network status
  log_message "$MODULE_NAME" "INFO" "Current network interfaces:"
  ip link show | grep -E "^[0-9]+:" | head -5
  
  # STEP 1: Optimize network buffers
  log_message "$MODULE_NAME" "INFO" "Optimizing network buffers..."
  optimize_network_buffers
  
  # STEP 2: Optimize TCP settings for gaming
  log_message "$MODULE_NAME" "INFO" "Optimizing TCP settings for low-latency gaming..."
  optimize_tcp_gaming
  
  # STEP 3: Optimize UDP settings for Source engine
  log_message "$MODULE_NAME" "INFO" "Optimizing UDP settings for Source engine..."
  optimize_udp_gaming
  
  # STEP 4: Optimize network interface settings
  if [[ "$OPTIMIZE_QUEUES" == "true" ]]; then
    log_message "$MODULE_NAME" "INFO" "Optimizing network interface settings..."
    optimize_interface_settings
  fi
  
  # STEP 5: Setup network monitoring
  log_message "$MODULE_NAME" "INFO" "Setting up network performance monitoring..."
  setup_network_monitoring
  
  # STEP 6: Verify optimizations
  log_message "$MODULE_NAME" "INFO" "Verifying network optimizations..."
  verify_network_settings
  
  # STEP 7: Display optimization summary
  log_message "$MODULE_NAME" "SUCCESS" "Docker network optimization completed"
  log_message "$MODULE_NAME" "INFO" "Network stack optimized for 100 Tickrate competitive L4D2"
  log_message "$MODULE_NAME" "INFO" "Low-latency TCP/UDP settings applied"
  log_message "$MODULE_NAME" "INFO" "Buffer sizes optimized for high-tickrate gaming"
  
  exit 0
fi
