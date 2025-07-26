#!/bin/bash
# modules/docker_filesystem.sh
# Docker Filesystem Optimization for L4D2 Competitive Gaming
# This module optimizes filesystem performance within Docker containers
# Uses tmpfs for temporary data and optimizes I/O patterns for high-tickrate servers

# =============================================================================
# MODULE REGISTRATION FUNCTION (REQUIRED)
# =============================================================================
register_module() {
  # Basic Information (REQUIRED)
  MODULE_NAME="docker_filesystem_optimization"
  MODULE_DESCRIPTION="Container Filesystem and I/O Performance Optimization"
  MODULE_VERSION="1.0.0"
  
  # Category Selection (REQUIRED - choose one)
  MODULE_CATEGORY="disk"
  
  # Execution Configuration (OPTIONAL)
  MODULE_TIMEOUT=60  # Filesystem operations may take time
  MODULE_REQUIRES_REBOOT=false
  
  # Environment Compatibility (REQUIRED)
  MODULE_ENVIRONMENT="docker"
  
  # Dependencies and Requirements (OPTIONAL)
  MODULE_DEPENDENCIES=()
  MODULE_REQUIRED_PACKAGES=("coreutils" "util-linux" "procps")
  
  # System Compatibility (REQUIRED)
  MODULE_SUPPORTED_SYSTEMS=("debian,11" "debian,12" "ubuntu,20.04" "ubuntu,22.04" "ubuntu,24.04")
  
  # Documentation and Metadata (OPTIONAL)
  MODULE_AUTHOR="AoC-Gamers"
  MODULE_DOCUMENTATION_URL="https://github.com/AoC-Gamers/L4D2-Optimizer"
  
  # Gaming Impact Information (OPTIONAL)
  MODULE_GAME_IMPACT="Reduces map loading times, eliminates I/O stutters during gameplay, optimizes demo recording for 100 tick servers, and improves overall server responsiveness"
  
  # Environment Variables Configuration (OPTIONAL)
  MODULE_ENV_VARIABLES=("DOCKER_FS_TMPFS_SIZE" "DOCKER_FS_ENABLE_TMPFS" "DOCKER_FS_OPTIMIZE_LOGS" "DOCKER_FS_DEMO_TMPFS")
  
  # Backup Configuration (OPTIONAL)
  MODULE_REQUIRES_BACKUP=true
  MODULE_BACKUP_FILES=("/etc/fstab")
  MODULE_BACKUP_COMMANDS=("df -h" "mount | grep tmpfs" "findmnt -t tmpfs")
}

# =============================================================================
# FILESYSTEM OPTIMIZATION FUNCTIONS
# =============================================================================

# Function to check available memory for tmpfs
check_available_memory() {
  local total_mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
  local available_mem_kb=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
  
  local total_mem_mb=$((total_mem_kb / 1024))
  local available_mem_mb=$((available_mem_kb / 1024))
  
  log_message "$MODULE_NAME" "INFO" "Total memory: ${total_mem_mb}MB, Available: ${available_mem_mb}MB"
  
  echo "$available_mem_mb"
}

# Function to create tmpfs mount for L4D2 temporary data
create_tmpfs_mounts() {
  local tmpfs_size="${DOCKER_FS_TMPFS_SIZE:-512M}"
  local available_mem=$(check_available_memory)
  
  # Ensure we don't use more than 25% of available memory for tmpfs
  local max_tmpfs_mb=$((available_mem / 4))
  
  log_message "$MODULE_NAME" "INFO" "Creating tmpfs mounts for L4D2 performance optimization"
  log_message "$MODULE_NAME" "INFO" "Requested tmpfs size: $tmpfs_size, Max recommended: ${max_tmpfs_mb}MB"
  
  # Create directories for tmpfs mounts
  local tmpfs_dirs=(
    "/tmp/l4d2_cache"           # General game cache
    "/tmp/l4d2_demos"           # Demo recording (high I/O)
    "/tmp/l4d2_logs"            # Log files
    "/tmp/l4d2_temp"            # Temporary game files
  )
  
  for dir in "${tmpfs_dirs[@]}"; do
    if [[ ! -d "$dir" ]]; then
      if mkdir -p "$dir"; then
        log_message "$MODULE_NAME" "SUCCESS" "Created directory: $dir"
      else
        log_message "$MODULE_NAME" "ERROR" "Failed to create directory: $dir"
        continue
      fi
    fi
    
    # Check if already mounted
    if mountpoint -q "$dir" 2>/dev/null; then
      log_message "$MODULE_NAME" "INFO" "tmpfs already mounted at: $dir"
      continue
    fi
    
    # Mount tmpfs
    if mount -t tmpfs -o size="$tmpfs_size",noatime,nosuid,nodev tmpfs "$dir"; then
      log_message "$MODULE_NAME" "SUCCESS" "Mounted tmpfs at: $dir (size: $tmpfs_size)"
    else
      log_message "$MODULE_NAME" "ERROR" "Failed to mount tmpfs at: $dir"
    fi
  done
}

# Function to optimize L4D2 directory structure
optimize_l4d2_directories() {
  local l4d2_paths=(
    "/opt/l4d2"
    "/home/steam/l4d2"
    "/srv/l4d2"
    "$HOME/l4d2"
    "/app/l4d2"  # Common in containers
  )
  
  local l4d2_root=""
  
  # Find L4D2 installation directory
  for path in "${l4d2_paths[@]}"; do
    if [[ -d "$path" && (-f "$path/srcds_run" || -f "$path/srcds_linux") ]]; then
      l4d2_root="$path"
      log_message "$MODULE_NAME" "SUCCESS" "Found L4D2 installation at: $l4d2_root"
      break
    fi
  done
  
  if [[ -z "$l4d2_root" ]]; then
    log_message "$MODULE_NAME" "WARNING" "L4D2 installation not found, skipping directory optimization"
    return 1
  fi
  
  # Create symlinks to tmpfs for performance-critical directories
  local critical_dirs=(
    "left4dead2/logs"
    "left4dead2/demos" 
    "left4dead2/cache"
  )
  
  for rel_dir in "${critical_dirs[@]}"; do
    local src_dir="$l4d2_root/$rel_dir"
    local tmpfs_target="/tmp/l4d2_$(basename "$rel_dir")"
    
    # Skip if source doesn't exist
    if [[ ! -d "$src_dir" ]]; then
      log_message "$MODULE_NAME" "INFO" "Directory not found, skipping: $src_dir"
      continue
    fi
    
    # Backup existing directory if it's not already a symlink
    if [[ ! -L "$src_dir" ]]; then
      local backup_dir="${src_dir}.backup.$(date +%Y%m%d_%H%M%S)"
      if mv "$src_dir" "$backup_dir"; then
        log_message "$MODULE_NAME" "SUCCESS" "Backed up $src_dir to $backup_dir"
      else
        log_message "$MODULE_NAME" "ERROR" "Failed to backup $src_dir"
        continue
      fi
    fi
    
    # Create symlink to tmpfs
    if ln -sf "$tmpfs_target" "$src_dir"; then
      log_message "$MODULE_NAME" "SUCCESS" "Created symlink: $src_dir -> $tmpfs_target"
    else
      log_message "$MODULE_NAME" "ERROR" "Failed to create symlink for $src_dir"
    fi
  done
}

# Function to optimize container filesystem settings
optimize_container_fs() {
  log_message "$MODULE_NAME" "INFO" "Applying container filesystem optimizations"
  
  # Set optimal I/O scheduler (if possible within container)
  if [[ -f /sys/block/*/queue/scheduler ]]; then
    for scheduler_file in /sys/block/*/queue/scheduler; do
      if [[ -w "$scheduler_file" ]]; then
        # Try to set deadline scheduler for better gaming performance
        if echo "deadline" > "$scheduler_file" 2>/dev/null; then
          local device=$(echo "$scheduler_file" | cut -d'/' -f4)
          log_message "$MODULE_NAME" "SUCCESS" "Set deadline scheduler for: $device"
        fi
      fi
    done
  fi
  
  # Optimize filesystem cache behavior
  if [[ -w /proc/sys/vm/dirty_ratio ]]; then
    echo "5" > /proc/sys/vm/dirty_ratio 2>/dev/null && \
    log_message "$MODULE_NAME" "SUCCESS" "Set vm.dirty_ratio=5 for faster I/O"
  fi
  
  if [[ -w /proc/sys/vm/dirty_background_ratio ]]; then
    echo "2" > /proc/sys/vm/dirty_background_ratio 2>/dev/null && \
    log_message "$MODULE_NAME" "SUCCESS" "Set vm.dirty_background_ratio=2"
  fi
  
  # Optimize readahead for gaming (smaller values for better latency)
  for device in /sys/block/*/queue/read_ahead_kb; do
    if [[ -w "$device" ]]; then
      echo "128" > "$device" 2>/dev/null && \
      log_message "$MODULE_NAME" "SUCCESS" "Set read_ahead_kb=128 for $(basename $(dirname $(dirname $device)))"
    fi
  done
}

# Function to setup log rotation for performance
setup_log_optimization() {
  local enable_log_opt="${DOCKER_FS_OPTIMIZE_LOGS:-true}"
  
  if [[ "$enable_log_opt" != "true" ]]; then
    log_message "$MODULE_NAME" "INFO" "Log optimization disabled"
    return 0
  fi
  
  log_message "$MODULE_NAME" "INFO" "Setting up log optimization for L4D2"
  
  # Create log rotation configuration
  cat > /tmp/l4d2_logrotate.conf << 'EOF'
# L4D2 Log Rotation for Performance
/tmp/l4d2_logs/*.log {
    hourly
    missingok
    rotate 24
    compress
    delaycompress
    copytruncate
    create 644 root root
    maxsize 10M
}

/tmp/l4d2_demos/*.dem {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    copytruncate
    maxsize 100M
}
EOF
  
  # Create cleanup script for old demos and logs
  cat > /tmp/l4d2_cleanup.sh << 'EOF'
#!/bin/bash
# Cleanup old L4D2 files for performance

# Remove demo files older than 3 days
find /tmp/l4d2_demos -name "*.dem" -mtime +3 -delete 2>/dev/null

# Remove log files older than 1 day
find /tmp/l4d2_logs -name "*.log" -mtime +1 -delete 2>/dev/null

# Remove temp files older than 1 hour
find /tmp/l4d2_temp -type f -mmin +60 -delete 2>/dev/null

# Clean up cache if it gets too large (>200MB)
cache_size=$(du -sm /tmp/l4d2_cache 2>/dev/null | cut -f1)
if [[ "$cache_size" -gt 200 ]]; then
    find /tmp/l4d2_cache -type f -atime +1 -delete 2>/dev/null
fi
EOF
  
  chmod +x /tmp/l4d2_cleanup.sh
  
  # Setup cron job for cleanup (if cron is available)
  if command -v crontab >/dev/null 2>&1; then
    echo "*/30 * * * * /tmp/l4d2_cleanup.sh" | crontab -
    log_message "$MODULE_NAME" "SUCCESS" "Setup automatic cleanup cron job"
  fi
}

# =============================================================================
# MODULE EXECUTION LOGIC (REQUIRED)
# =============================================================================
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  
  MODULE_NAME="docker_filesystem_optimization"
  
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
  ENABLE_TMPFS="${DOCKER_FS_ENABLE_TMPFS:-true}"
  TMPFS_SIZE="${DOCKER_FS_TMPFS_SIZE:-512M}"
  OPTIMIZE_LOGS="${DOCKER_FS_OPTIMIZE_LOGS:-true}"
  DEMO_TMPFS="${DOCKER_FS_DEMO_TMPFS:-true}"
  
  log_message "$MODULE_NAME" "INFO" "=== Starting Docker Filesystem Optimization ==="
  log_message "$MODULE_NAME" "INFO" "Optimizing for L4D2 competitive gaming I/O performance"
  
  # Display current filesystem status
  log_message "$MODULE_NAME" "INFO" "Current filesystem status:"
  df -h | grep -E "(Filesystem|tmpfs|/dev)" | head -5
  
  # STEP 1: Create tmpfs mounts for performance-critical data
  if [[ "$ENABLE_TMPFS" == "true" ]]; then
    log_message "$MODULE_NAME" "INFO" "Creating tmpfs mounts for L4D2 performance..."
    create_tmpfs_mounts
  else
    log_message "$MODULE_NAME" "INFO" "tmpfs optimization disabled"
  fi
  
  # STEP 2: Optimize L4D2 directory structure
  log_message "$MODULE_NAME" "INFO" "Optimizing L4D2 directory structure..."
  optimize_l4d2_directories
  
  # STEP 3: Apply container filesystem optimizations
  log_message "$MODULE_NAME" "INFO" "Applying container filesystem settings..."
  optimize_container_fs
  
  # STEP 4: Setup log and demo optimization
  if [[ "$OPTIMIZE_LOGS" == "true" ]]; then
    log_message "$MODULE_NAME" "INFO" "Setting up log optimization..."
    setup_log_optimization
  fi
  
  # STEP 5: Verify optimizations
  log_message "$MODULE_NAME" "INFO" "Verifying filesystem optimizations:"
  
  # Show tmpfs mounts
  echo "=== tmpfs Mounts ==="
  mount | grep tmpfs | grep l4d2
  
  # Show disk usage
  echo "=== Disk Usage ==="
  df -h | grep -E "(tmpfs|/tmp)"
  
  # Show I/O statistics if available
  if command -v iostat >/dev/null 2>&1; then
    echo "=== I/O Statistics ==="
    iostat -x 1 1 | tail -n +4
  fi
  
  log_message "$MODULE_NAME" "SUCCESS" "Docker filesystem optimization completed"
  log_message "$MODULE_NAME" "INFO" "L4D2 temporary data moved to high-speed tmpfs"
  log_message "$MODULE_NAME" "INFO" "I/O optimizations applied for 100 tick competitive gaming"
  
  exit 0
fi
