#!/bin/bash
# modules/docker_processes.sh
# Docker Process Priority Optimization for L4D2 Competitive Gaming
# This module optimizes process scheduling and priorities within Docker containers
# Specifically designed for high-tickrate L4D2 servers

# =============================================================================
# MODULE REGISTRATION FUNCTION (REQUIRED)
# =============================================================================
register_module() {
  # Basic Information (REQUIRED)
  MODULE_NAME="docker_process_optimization"
  MODULE_DESCRIPTION="Container Process Priority and Real-time Scheduling"
  MODULE_VERSION="1.0.0"
  
  # Category Selection (REQUIRED - choose one)
  MODULE_CATEGORY="gaming"
  
  # Execution Configuration (OPTIONAL)
  MODULE_TIMEOUT=45  # Process priority changes are quick
  MODULE_REQUIRES_REBOOT=false
  
  # Environment Compatibility (REQUIRED)
  MODULE_ENVIRONMENT="docker"
  
  # Dependencies and Requirements (OPTIONAL)
  MODULE_DEPENDENCIES=()
  MODULE_REQUIRED_PACKAGES=("util-linux" "procps")  # For renice, ionice, ps
  
  # System Compatibility (REQUIRED)
  MODULE_SUPPORTED_SYSTEMS=("debian,11" "debian,12" "ubuntu,20.04" "ubuntu,22.04" "ubuntu,24.04")
  
  # Documentation and Metadata (OPTIONAL)
  MODULE_AUTHOR="AoC-Gamers"
  MODULE_DOCUMENTATION_URL="https://github.com/AoC-Gamers/L4D2-Optimizer"
  
  # Gaming Impact Information (OPTIONAL)
  MODULE_GAME_IMPACT="Optimizes process priorities for 100 tickrate stability, reduces micro-stutters, and ensures consistent hitreg in competitive L4D2 servers"
  
  # Environment Variables Configuration (OPTIONAL)
  MODULE_ENV_VARIABLES=("DOCKER_PROCESS_SRCDS_NICE" "DOCKER_PROCESS_SRCDS_IONICE" "DOCKER_PROCESS_OTHER_NICE" "DOCKER_PROCESS_ENABLE_RT")
  
  # Backup Configuration (OPTIONAL)
  MODULE_REQUIRES_BACKUP=true
  MODULE_BACKUP_FILES=("/proc/*/stat" "/proc/*/sched")
  MODULE_BACKUP_COMMANDS=("ps -eo pid,ppid,ni,pri,psr,comm,args" "cat /proc/*/sched | head -20")
}

# =============================================================================
# BACKUP FUNCTIONS (Inherited from template)
# =============================================================================
# [Backup functions would be inherited from template - omitted for brevity]

# =============================================================================
# PROCESS OPTIMIZATION FUNCTIONS
# =============================================================================

# Function to find L4D2/Source engine processes
find_game_processes() {
  local game_pids=()
  
  # Look for common L4D2/Source engine process names
  local process_patterns=("srcds_linux" "srcds_run" "srcds" "l4d2" "left4dead2")
  
  for pattern in "${process_patterns[@]}"; do
    while IFS= read -r pid; do
      if [[ -n "$pid" && "$pid" =~ ^[0-9]+$ ]]; then
        game_pids+=("$pid")
        log_message "$MODULE_NAME" "INFO" "Found game process: PID $pid ($pattern)"
      fi
    done < <(pgrep -f "$pattern" 2>/dev/null)
  done
  
  echo "${game_pids[@]}"
}

# Function to set process nice value
set_process_nice() {
  local pid="$1"
  local nice_value="$2"
  local process_name="$3"
  
  if [[ -n "$pid" && "$pid" =~ ^[0-9]+$ ]]; then
    local current_nice=$(ps -o ni= -p "$pid" 2>/dev/null | tr -d ' ')
    
    if [[ "$current_nice" != "$nice_value" ]]; then
      if renice "$nice_value" -p "$pid" >/dev/null 2>&1; then
        log_message "$MODULE_NAME" "SUCCESS" "Set nice=$nice_value for PID $pid ($process_name)"
        return 0
      else
        log_message "$MODULE_NAME" "ERROR" "Failed to set nice=$nice_value for PID $pid"
        return 1
      fi
    else
      log_message "$MODULE_NAME" "INFO" "PID $pid already has nice=$current_nice"
      return 0
    fi
  else
    log_message "$MODULE_NAME" "ERROR" "Invalid PID: $pid"
    return 1
  fi
}

# Function to set I/O nice value
set_process_ionice() {
  local pid="$1"
  local ionice_class="$2"
  local ionice_level="$3"
  local process_name="$4"
  
  if command -v ionice >/dev/null 2>&1; then
    if ionice -c "$ionice_class" -n "$ionice_level" -p "$pid" 2>/dev/null; then
      log_message "$MODULE_NAME" "SUCCESS" "Set ionice class=$ionice_class level=$ionice_level for PID $pid ($process_name)"
      return 0
    else
      log_message "$MODULE_NAME" "WARNING" "Failed to set ionice for PID $pid (may require root)"
      return 1
    fi
  else
    log_message "$MODULE_NAME" "WARNING" "ionice command not available"
    return 1
  fi
}

# Function to set CPU affinity
set_process_affinity() {
  local pid="$1"
  local cpu_list="$2"
  local process_name="$3"
  
  if command -v taskset >/dev/null 2>&1; then
    if taskset -cp "$cpu_list" "$pid" >/dev/null 2>&1; then
      log_message "$MODULE_NAME" "SUCCESS" "Set CPU affinity=$cpu_list for PID $pid ($process_name)"
      return 0
    else
      log_message "$MODULE_NAME" "WARNING" "Failed to set CPU affinity for PID $pid"
      return 1
    fi
  else
    log_message "$MODULE_NAME" "WARNING" "taskset command not available"
    return 1
  fi
}

# Function to optimize other container processes
optimize_other_processes() {
  local other_nice="${DOCKER_PROCESS_OTHER_NICE:-10}"
  
  log_message "$MODULE_NAME" "INFO" "Optimizing non-game processes with nice=$other_nice"
  
  # Get all processes except game processes and system processes
  local all_pids=($(ps -eo pid --no-headers | tr -d ' '))
  local game_pids=($(find_game_processes))
  
  for pid in "${all_pids[@]}"; do
    # Skip if it's a game process
    local is_game_process=false
    for game_pid in "${game_pids[@]}"; do
      if [[ "$pid" == "$game_pid" ]]; then
        is_game_process=true
        break
      fi
    done
    
    # Skip system processes (PID < 100) and game processes
    if [[ "$pid" -lt 100 || "$is_game_process" == true ]]; then
      continue
    fi
    
    # Get process name
    local process_name=$(ps -o comm= -p "$pid" 2>/dev/null)
    
    # Skip kernel threads (processes in square brackets)
    if [[ "$process_name" =~ ^\[.*\]$ ]]; then
      continue
    fi
    
    # Set lower priority for other processes
    set_process_nice "$pid" "$other_nice" "$process_name"
  done
}

# =============================================================================
# MODULE EXECUTION LOGIC (REQUIRED)
# =============================================================================
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  
  MODULE_NAME="docker_process_optimization"
  
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
  SRCDS_NICE="${DOCKER_PROCESS_SRCDS_NICE:--20}"        # Highest priority for game server
  SRCDS_IONICE_CLASS="${DOCKER_PROCESS_SRCDS_IONICE:-1}" # Real-time I/O class
  SRCDS_IONICE_LEVEL="4"                                 # Mid-level within RT class
  OTHER_NICE="${DOCKER_PROCESS_OTHER_NICE:-10}"         # Lower priority for other processes
  ENABLE_RT="${DOCKER_PROCESS_ENABLE_RT:-true}"         # Enable real-time optimizations
  
  log_message "$MODULE_NAME" "INFO" "=== Starting Docker Process Optimization ==="
  log_message "$MODULE_NAME" "INFO" "Optimizing for L4D2 competitive gaming (100 tick)"
  
  # STEP 0: Environment compatibility check (inherited from template)
  
  # STEP 1: Find game server processes
  log_message "$MODULE_NAME" "INFO" "Searching for L4D2/Source engine processes..."
  game_pids=($(find_game_processes))
  
  if [[ ${#game_pids[@]} -eq 0 ]]; then
    log_message "$MODULE_NAME" "WARNING" "No game server processes found"
    log_message "$MODULE_NAME" "INFO" "Process optimization will apply when game server starts"
  else
    log_message "$MODULE_NAME" "SUCCESS" "Found ${#game_pids[@]} game server process(es)"
  fi
  
  # STEP 2: Optimize game server processes
  for pid in "${game_pids[@]}"; do
    process_name=$(ps -o comm= -p "$pid" 2>/dev/null || echo "unknown")
    
    log_message "$MODULE_NAME" "INFO" "Optimizing game process PID $pid ($process_name)"
    
    # Set highest CPU priority
    set_process_nice "$pid" "$SRCDS_NICE" "$process_name"
    
    # Set real-time I/O priority if enabled
    if [[ "$ENABLE_RT" == "true" ]]; then
      set_process_ionice "$pid" "$SRCDS_IONICE_CLASS" "$SRCDS_IONICE_LEVEL" "$process_name"
    fi
    
    # CPU affinity would be set at container level, not here
    # This is handled by docker run --cpuset-cpus parameter
  done
  
  # STEP 3: Optimize other container processes
  log_message "$MODULE_NAME" "INFO" "Deprioritizing non-game processes..."
  optimize_other_processes
  
  # STEP 4: Set up process monitoring script (optional)
  if [[ "$ENABLE_RT" == "true" ]]; then
    log_message "$MODULE_NAME" "INFO" "Setting up continuous process monitoring..."
    
    # Create a simple monitoring script that runs in background
    cat > /tmp/l4d2_process_monitor.sh << 'EOF'
#!/bin/bash
while true; do
  # Check every 30 seconds for new game processes
  for pid in $(pgrep -f "srcds"); do
    current_nice=$(ps -o ni= -p "$pid" 2>/dev/null | tr -d ' ')
    if [[ "$current_nice" != "-20" ]]; then
      renice -20 -p "$pid" >/dev/null 2>&1
      ionice -c 1 -n 4 -p "$pid" >/dev/null 2>&1
    fi
  done
  sleep 30
done
EOF
    
    chmod +x /tmp/l4d2_process_monitor.sh
    
    # Start monitor in background if not already running
    if ! pgrep -f "l4d2_process_monitor" >/dev/null; then
      nohup /tmp/l4d2_process_monitor.sh >/dev/null 2>&1 &
      log_message "$MODULE_NAME" "SUCCESS" "Started background process monitor"
    fi
  fi
  
  # STEP 5: Display current process priorities
  log_message "$MODULE_NAME" "INFO" "Current process priorities:"
  ps -eo pid,ni,pri,psr,comm,args | grep -E "(PID|srcds|l4d2)" | head -10
  
  log_message "$MODULE_NAME" "SUCCESS" "Docker process optimization completed"
  log_message "$MODULE_NAME" "INFO" "Game server processes optimized for 100 tick competitive gaming"
  
  exit 0
fi
