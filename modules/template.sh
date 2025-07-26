#!/bin/bash
# modules/prototype_template.sh
# PROTOTYPE TEMPLATE - This is a template for creating new optimization modules
# This file serves as a blank prototype for development and testing purposes
# When DEBUG=1, this module will appear in the menu for testing the dynamic module system

# =============================================================================
# MODULE REGISTRATION FUNCTION (REQUIRED)
# =============================================================================
# This function must be present in all modules and defines the module metadata
# DO NOT modify the function name or structure, only the values inside
register_module() {
  # Basic Information (REQUIRED)
  MODULE_NAME="Template"
  MODULE_DESCRIPTION="Prototype Template for Development and Testing"
  MODULE_VERSION="1.0.0"
  
  # Category Selection (REQUIRED - choose one)
  # Available options: "memory", "network", "disk", "cpu", "security", "system", "gaming", "other"
  MODULE_CATEGORY="other"
  
  # Execution Configuration (OPTIONAL)
  MODULE_TIMEOUT=30  # Override global timeout in seconds (default: 180)
  MODULE_REQUIRES_REBOOT=false  # Set to true if system reboot is required after execution
  
  # Environment Compatibility (REQUIRED)
  # Options: "host", "docker", "both"
  # - "host": Only runs on host systems (bare metal/VM)
  # - "docker": Only runs inside Docker containers  
  # - "both": Can run in both environments
  MODULE_ENVIRONMENT="both"
  
  # Dependencies and Requirements (OPTIONAL - leave empty arrays if none)
  MODULE_DEPENDENCIES=()  # Array of required modules (by MODULE_NAME)
  MODULE_REQUIRED_PACKAGES=()  # Array of required system packages (e.g., "curl" "wget")
  
  # System Compatibility (REQUIRED)
  # Format: "os_id,version" - combines OS and version for easier validation
  MODULE_SUPPORTED_SYSTEMS=("debian,11" "debian,12" "ubuntu,20.04" "ubuntu,22.04" "ubuntu,24.04")
  
  # Documentation and Metadata (OPTIONAL)
  MODULE_AUTHOR="AoC-Gamers"
  MODULE_DOCUMENTATION_URL="https://github.com/AoC-Gamers/L4D2-Optimizer"
  
  # Gaming Impact Information (OPTIONAL)
  MODULE_GAME_IMPACT="This is a prototype template for testing purposes only - no real optimizations applied"
  
  # Environment Variables Configuration (OPTIONAL)
  # Array of environment variables that this module uses for configuration
  MODULE_ENV_VARIABLES=("OPTIMIZER_EXAMPLE_VAR" "OPTIMIZER_ANOTHER_VAR")
  
  # Backup Configuration (OPTIONAL)
  MODULE_REQUIRES_BACKUP=true  # Set to true if this module should create backups before execution
  MODULE_BACKUP_FILES=("/etc/example.conf" "/proc/sys/example")  # Array of files/directories to backup
  MODULE_BACKUP_COMMANDS=("systemctl status example" "cat /proc/example")  # Array of commands to execute for backup
}

# =============================================================================
# BACKUP FUNCTIONS (OPTIONAL - Only needed if MODULE_REQUIRES_BACKUP=true)
# =============================================================================

# Function to create backup directory structure
create_backup_directory() {
  local module_name="$1"
  local timestamp="$2"
  
  # Define backup directory path following the agreed structure
  local backup_dir="/var/lib/l4d2-optimizer/backups/${module_name}/${timestamp}"
  
  if mkdir -p "$backup_dir"; then
    echo "$backup_dir"
    return 0
  else
    log_message "$module_name" "ERROR" "Failed to create backup directory: $backup_dir"
    return 1
  fi
}

# Function to perform file backups
backup_files() {
  local module_name="$1"
  local backup_dir="$2"
  local files_to_backup=("${@:3}")
  
  local backup_count=0
  local failed_count=0
  
  for file_path in "${files_to_backup[@]}"; do
    if [[ -e "$file_path" ]]; then
      # Create subdirectory structure in backup
      local relative_path="${file_path#/}"
      local backup_file_dir="$backup_dir/files/$(dirname "$relative_path")"
      
      if mkdir -p "$backup_file_dir"; then
        if cp -a "$file_path" "$backup_file_dir/"; then
          log_message "$module_name" "SUCCESS" "Backed up: $file_path"
          ((backup_count++))
        else
          log_message "$module_name" "ERROR" "Failed to backup: $file_path"
          ((failed_count++))
        fi
      else
        log_message "$module_name" "ERROR" "Failed to create backup subdirectory for: $file_path"
        ((failed_count++))
      fi
    else
      log_message "$module_name" "WARNING" "File not found for backup: $file_path"
    fi
  done
  
  log_message "$module_name" "INFO" "File backup summary: $backup_count successful, $failed_count failed"
  return $failed_count
}

# Function to perform command output backups
backup_commands() {
  local module_name="$1"
  local backup_dir="$2"
  local commands_to_run=("${@:3}")
  
  local commands_dir="$backup_dir/commands"
  mkdir -p "$commands_dir"
  
  local command_count=0
  
  for cmd in "${commands_to_run[@]}"; do
    ((command_count++))
    local output_file="$commands_dir/command_${command_count}.txt"
    
    # Save command and timestamp
    echo "# Command executed: $cmd" > "$output_file"
    echo "# Timestamp: $(date '+%Y-%m-%d %H:%M:%S')" >> "$output_file"
    echo "# ============================================" >> "$output_file"
    
    # Execute command and save output
    if eval "$cmd" >> "$output_file" 2>&1; then
      log_message "$module_name" "SUCCESS" "Command backup completed: $cmd"
    else
      log_message "$module_name" "WARNING" "Command backup completed with errors: $cmd"
    fi
  done
  
  log_message "$module_name" "INFO" "Command backup summary: $command_count commands executed"
}

# Function to create backup metadata
create_backup_metadata() {
  local module_name="$1"
  local backup_dir="$2"
  local files_to_backup=("${@:3}")
  
  local metadata_file="$backup_dir/backup_metadata.json"
  
  cat > "$metadata_file" << EOF
{
  "backup_info": {
    "module_name": "$module_name",
    "timestamp": "$(date '+%Y-%m-%d %H:%M:%S')",
    "backup_directory": "$backup_dir",
    "system_info": {
      "hostname": "$(hostname)",
      "os_release": "$(cat /etc/os-release | grep PRETTY_NAME | cut -d'=' -f2 | tr -d '\"')",
      "kernel_version": "$(uname -r)",
      "architecture": "$(uname -m)"
    }
  },
  "backup_files": [
$(for file in "${files_to_backup[@]}"; do echo "    \"$file\","; done | sed '$s/,$//')
  ],
  "backup_status": "completed"
}
EOF
  
  log_message "$module_name" "SUCCESS" "Backup metadata created: $metadata_file"
}

# Main backup function - orchestrates the entire backup process
perform_module_backup() {
  local module_name="$1"
  
  # Only proceed if backup is required
  if [[ "${MODULE_REQUIRES_BACKUP:-false}" != "true" ]]; then
    log_message "$module_name" "INFO" "Backup not required for this module"
    return 0
  fi
  
  log_message "$module_name" "INFO" "=== Starting Backup Process ==="
  
  # Generate timestamp for backup directory
  local timestamp=$(date '+%Y%m%d_%H%M%S')
  
  # Create backup directory
  local backup_dir
  if backup_dir=$(create_backup_directory "$module_name" "$timestamp"); then
    log_message "$module_name" "SUCCESS" "Backup directory created: $backup_dir"
  else
    log_message "$module_name" "ERROR" "Failed to create backup directory"
    return 1
  fi
  
  # Perform file backups if specified
  if [[ ${#MODULE_BACKUP_FILES[@]} -gt 0 ]]; then
    log_message "$module_name" "INFO" "Backing up ${#MODULE_BACKUP_FILES[@]} files/directories..."
    backup_files "$module_name" "$backup_dir" "${MODULE_BACKUP_FILES[@]}"
  fi
  
  # Perform command backups if specified
  if [[ ${#MODULE_BACKUP_COMMANDS[@]} -gt 0 ]]; then
    log_message "$module_name" "INFO" "Executing ${#MODULE_BACKUP_COMMANDS[@]} backup commands..."
    backup_commands "$module_name" "$backup_dir" "${MODULE_BACKUP_COMMANDS[@]}"
  fi
  
  # Create backup metadata
  create_backup_metadata "$module_name" "$backup_dir" "${MODULE_BACKUP_FILES[@]}"
  
  log_message "$module_name" "SUCCESS" "=== Backup Process Completed ==="
  log_message "$module_name" "INFO" "Backup location: $backup_dir"
  
  return 0
}

# =============================================================================
# ENVIRONMENT DETECTION FUNCTIONS
# =============================================================================

# Function to detect if running inside Docker container
detect_docker_environment() {
  local is_docker=false
  
  # Method 1: Check for .dockerenv file
  if [[ -f /.dockerenv ]]; then
    is_docker=true
  fi
  
  # Method 2: Check cgroup for docker
  if [[ -f /proc/1/cgroup ]] && grep -q docker /proc/1/cgroup 2>/dev/null; then
    is_docker=true
  fi
  
  # Method 3: Check for container environment variable
  if [[ -n "${container:-}" ]] || [[ -n "${DOCKER_CONTAINER:-}" ]]; then
    is_docker=true
  fi
  
  # Method 4: Check systemd-detect-virt if available
  if command -v systemd-detect-virt >/dev/null 2>&1; then
    if systemd-detect-virt --container >/dev/null 2>&1; then
      is_docker=true
    fi
  fi
  
  echo "$is_docker"
}

# Function to check if module is compatible with current environment
is_module_environment_compatible() {
  local module_environment="$1"
  local current_env
  
  # Detect current environment
  if [[ "$(detect_docker_environment)" == "true" ]]; then
    current_env="docker"
  else
    current_env="host"
  fi
  
  # Check compatibility
  case "$module_environment" in
    "both")
      return 0  # Compatible with both
      ;;
    "$current_env")
      return 0  # Compatible with current environment
      ;;
    *)
      return 1  # Not compatible
      ;;
  esac
}

# =============================================================================
# MODULE EXECUTION LOGIC (REQUIRED)
# =============================================================================
# This section contains the actual optimization code
# Only execute if the script is called directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  
  # Set module name for logging
  MODULE_NAME="prototype_template"
  
  # Define log_message function if not available (fallback)
  if ! command -v log_message &> /dev/null; then
    log_message() {
      local module="$1"
      local type="$2" 
      local message="$3"
      echo "[$type] [$module] $message"
    }
  fi
  
  # START OPTIMIZATION LOGIC
  log_message "$MODULE_NAME" "INFO" "=== Starting Prototype Template Execution ==="
  log_message "$MODULE_NAME" "INFO" "This is a development template - no real changes will be made"
  
  # STEP 0: Check environment compatibility
  log_message "$MODULE_NAME" "INFO" "Checking environment compatibility..."
  
  # Load module metadata
  register_module
  
  # Detect current environment
  local is_docker=$(detect_docker_environment)
  local current_env="host"
  if [[ "$is_docker" == "true" ]]; then
    current_env="docker"
  fi
  
  log_message "$MODULE_NAME" "INFO" "Current environment: $current_env"
  log_message "$MODULE_NAME" "INFO" "Module supports: ${MODULE_ENVIRONMENT:-both}"
  
  # Check compatibility
  if ! is_module_environment_compatible "${MODULE_ENVIRONMENT:-both}"; then
    log_message "$MODULE_NAME" "ERROR" "Module not compatible with $current_env environment"
    log_message "$MODULE_NAME" "ERROR" "This module is designed for: ${MODULE_ENVIRONMENT:-both}"
    exit 1
  fi
  
  log_message "$MODULE_NAME" "SUCCESS" "Environment compatibility check passed"
  
  # STEP 1: Create backup before making any changes (if required)
  if [[ "${MODULE_REQUIRES_BACKUP:-false}" == "true" ]]; then
    log_message "$MODULE_NAME" "INFO" "Creating backup before applying optimizations..."
    if ! perform_module_backup "$MODULE_NAME"; then
      log_message "$MODULE_NAME" "ERROR" "Backup failed - aborting module execution"
      exit 1
    fi
  fi
  
  # STEP 2: Check system compatibility
  log_message "$MODULE_NAME" "INFO" "Checking system compatibility..."
  sleep 1
  
  # STEP 3: Validate configuration parameters
  log_message "$MODULE_NAME" "INFO" "Validating configuration parameters..."
  sleep 1
  
  # STEP 4: Apply optimization settings (environment-aware)
  log_message "$MODULE_NAME" "INFO" "Applying optimization settings for $current_env environment..."
  
  if [[ "$current_env" == "docker" ]]; then
    log_message "$MODULE_NAME" "INFO" "Running Docker-specific optimizations..."
    # Docker-specific logic here
    sleep 1
  else
    log_message "$MODULE_NAME" "INFO" "Running host-specific optimizations..."  
    # Host-specific logic here
    sleep 1
  fi
  
  # STEP 5: Verify changes
  log_message "$MODULE_NAME" "INFO" "Verifying changes..."
  sleep 1
  
  # Success message
  log_message "$MODULE_NAME" "SUCCESS" "Prototype template execution completed successfully"
  log_message "$MODULE_NAME" "INFO" "=== Template Execution Finished ==="
  
  # Exit with success
  exit 0
fi

# =============================================================================
# BACKUP SYSTEM USAGE INSTRUCTIONS
# =============================================================================
# To enable backup functionality in your module:
#
# 1. Set MODULE_REQUIRES_BACKUP=true in register_module()
# 2. Define MODULE_BACKUP_FILES array with files/directories to backup
# 3. Define MODULE_BACKUP_COMMANDS array with commands to execute for backup
# 4. The backup will be automatically created before module execution
#
# Backup Directory Structure:
# /var/lib/l4d2-optimizer/backups/
# └── {module_name}/
#     └── {timestamp}/
#         ├── backup_metadata.json
#         ├── files/
#         │   └── {original_file_structure}
#         └── commands/
#             └── command_N.txt
#
# Example Usage:
# MODULE_REQUIRES_BACKUP=true
# MODULE_BACKUP_FILES=("/etc/sysctl.conf" "/proc/sys/vm/swappiness")
# MODULE_BACKUP_COMMANDS=("sysctl -a | grep vm" "free -h")
# =============================================================================
