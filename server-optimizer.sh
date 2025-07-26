#!/bin/bash

# L4D2 Server Optimizer
# Interactive system to execute selected optimization modules for swap, disk, THP, IRQ, network and IPv6.
# Features: Module selection menu, installation status tracking, timeout protection.
# Uses timeout to avoid module blocking.

# Default configuration values (can be overridden by .env file)
OPTIMIZER_DEBUG=1
OPTIMIZER_TIMEOUT_DURATION=180  # seconds per module

# Configuration directories (system-wide - requires root privileges)
# Default values - can be overridden by .env file
OPTIMIZER_CONFIG_DIR="/etc/l4d2-optimizer"
OPTIMIZER_DATA_DIR="/var/lib/l4d2-optimizer"
OPTIMIZER_LOG_DIR="/var/log/l4d2-optimizer"

# Configuration files
STATUS_FILE="$OPTIMIZER_DATA_DIR/module_status"
DEBUG_LOG_FILE="$OPTIMIZER_LOG_DIR/debug.log"

# Dynamic modules arrays (will be populated by discover_modules function)
declare -A MODULES
declare -a MODULE_ORDER
declare -A MODULE_METADATA

# Logging function for modules
# Usage: log_message "MODULE" "TYPE" "MESSAGE"
# TYPE: INFO, SUCCESS, WARNING, ERROR
log_message() {
  local module="$1"
  local type="$2"
  local message="$3"
  
  # Handle DEBUG type specially - use debug_log instead of echo
  if [[ "$type" == "DEBUG" ]]; then
    debug_log "$module" "$message" "main" "false"
    return
  fi
  
  case "$type" in
    INFO)    echo "ℹ️  [$module] $message" ;;
    SUCCESS) echo "✅ [$module] $message" ;;
    WARNING) echo "⚠️  [$module] $message" ;;
    ERROR)   echo "❌ [$module] $message" ;;
    *)       echo "📝 [$module] $message" ;;
  esac
}

# Debug logging function - saves messages to debug.log when DEBUG mode is enabled
# Usage: debug_log "MODULE" "MESSAGE" ["FUNCTION"] [show_terminal]
debug_log() {
  local module="$1"
  local message="$2"
  local function_name="${3:-main}"
  local show_terminal="${4:-false}"  # Default: do NOT show in terminal
  
  # Only log if DEBUG mode is enabled
  if [[ "$OPTIMIZER_DEBUG" == "1" ]]; then
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_entry="[$timestamp] [DEBUG] [$module:$function_name] $message"
    
    # Create debug log directory if it doesn't exist
    local debug_dir=$(dirname "$DEBUG_LOG_FILE")
    if [[ ! -d "$debug_dir" ]]; then
      mkdir -p "$debug_dir" 2>/dev/null
    fi
    
    # Write to debug log file (always, no terminal interference)
    echo "$log_entry" >> "$DEBUG_LOG_FILE" 2>/dev/null
    
    # ONLY show on terminal if explicitly requested and it's safe to do so
    if [[ "$show_terminal" == "true" ]]; then
      echo "🐛 [DEBUG] [$module:$function_name] $message" >&2
    fi
  fi
}

# Function to clean debug log file
# Usage: clean_debug_log [max_lines]
clean_debug_log() {
  local max_lines="${1:-1000}"  # Default: keep last 1000 lines
  
  if [[ "$OPTIMIZER_DEBUG" == "1" && -f "$DEBUG_LOG_FILE" ]]; then
    local current_lines=$(wc -l < "$DEBUG_LOG_FILE" 2>/dev/null)
    
    if [[ $current_lines -gt $max_lines ]]; then
      debug_log "SYSTEM" "Debug log has $current_lines lines, truncating to $max_lines" "clean_debug_log"
      
      # Keep last N lines
      tail -n "$max_lines" "$DEBUG_LOG_FILE" > "${DEBUG_LOG_FILE}.tmp" 2>/dev/null
      mv "${DEBUG_LOG_FILE}.tmp" "$DEBUG_LOG_FILE" 2>/dev/null
      
      debug_log "SYSTEM" "Debug log cleaned successfully" "clean_debug_log"
    fi
  fi
}

# Load environment configuration from .env file after log_message is defined
BASE_DIR=$(dirname "$0")
ENV_FILE="$BASE_DIR/.env"

# Load .env configuration if file exists
if [[ -f "$ENV_FILE" ]]; then
  echo "🔧 Loading configuration from .env file..."
  debug_log "CONFIG" "Starting .env file parsing: $ENV_FILE" "load_env"
  
  # Read .env file line by line
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip empty lines and comments
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    
    # Skip lines that don't contain =
    [[ "$line" =~ = ]] || continue
    
    # Extract variable name and value
    var_name="${line%%=*}"
    var_value="${line#*=}"
    
    # Remove inline comments from value (everything after #)
    var_value="${var_value%%#*}"
    
    # Remove leading/trailing whitespace from both name and value FIRST
    # This is critical for proper quote detection
    var_name="${var_name#"${var_name%%[![:space:]]*}"}"  # Remove leading whitespace
    var_name="${var_name%"${var_name##*[![:space:]]}"}"  # Remove trailing whitespace
    var_value="${var_value#"${var_value%%[![:space:]]*}"}"  # Remove leading whitespace
    var_value="${var_value%"${var_value##*[![:space:]]}"}"  # Remove trailing whitespace
    
    # Remove quotes from value if present (using direct character-by-character approach)
    # This handles both single and double quotes reliably
    if [[ "${var_value:0:1}" == '"' && "${var_value: -1}" == '"' ]]; then
      var_value="${var_value:1:-1}"  # Remove first and last character
    elif [[ "${var_value:0:1}" == "'" && "${var_value: -1}" == "'" ]]; then
      var_value="${var_value:1:-1}"  # Remove first and last character
    fi
    
    # Export the variable
    export "$var_name"="$var_value"
    
    debug_log "CONFIG" "Parsed variable: $var_name=$var_value" "load_env"
    
    if [[ "$OPTIMIZER_DEBUG" == "1" ]]; then
      echo "  • Loaded: $var_name=$var_value"
    fi
    
  done < "$ENV_FILE"
  
  debug_log "CONFIG" "Environment configuration loaded successfully" "load_env"
  echo "✅ Environment configuration loaded successfully"
else
  debug_log "CONFIG" "No .env file found at $ENV_FILE, using defaults" "load_env"
  echo "ℹ️  No .env file found, using default configuration"
fi

# Set MODULE_DIR after BASE_DIR is defined
MODULE_DIR="$BASE_DIR/modules"

# Function to create necessary directories
create_directories() {
  local dirs=("$OPTIMIZER_CONFIG_DIR" "$OPTIMIZER_DATA_DIR" "$OPTIMIZER_LOG_DIR" "$OPTIMIZER_DATA_DIR/backups")
  
  for dir in "${dirs[@]}"; do
    if [[ ! -d "$dir" ]]; then
      if mkdir -p "$dir" 2>/dev/null; then
        log_message "SYSTEM" "INFO" "Created directory: $dir"
      else
        log_message "SYSTEM" "ERROR" "Failed to create directory: $dir"
        return 1
      fi
    fi
  done
  
  # Set appropriate permissions for system directories
  chmod 755 "$OPTIMIZER_CONFIG_DIR" "$OPTIMIZER_DATA_DIR" "$OPTIMIZER_LOG_DIR" "$OPTIMIZER_DATA_DIR/backups" 2>/dev/null
  
  return 0
}

# Function to load module status from file
load_module_status() {
  if [[ -f "$STATUS_FILE" ]]; then
    source "$STATUS_FILE"
  fi
}

# Function to save module status to file
save_module_status() {
  local module="$1"
  local status="$2"
  local timestamp="$3"
  
  # Create status file if it doesn't exist
  touch "$STATUS_FILE"
  
  # Remove old entry for this module
  sed -i "/^${module}_STATUS=/d" "$STATUS_FILE"
  sed -i "/^${module}_TIMESTAMP=/d" "$STATUS_FILE"
  
  # Add new status
  echo "${module}_STATUS=\"$status\"" >> "$STATUS_FILE"
  echo "${module}_TIMESTAMP=\"$timestamp\"" >> "$STATUS_FILE"
}

# Function to get module status
get_module_status() {
  local module="$1"
  local status_var="${module}_STATUS"
  echo "${!status_var:-NOT_INSTALLED}"
}

# Function to get module timestamp
get_module_timestamp() {
  local module="$1"
  local timestamp_var="${module}_TIMESTAMP"
  echo "${!timestamp_var:-Never}"
}

# Function to check if a system package is installed
is_package_installed() {
  local package="$1"
  local show_debug="${2:-false}"  # Default: don't show debug in terminal
  
  debug_log "DEPENDENCIES" "Checking if package '$package' is installed" "is_package_installed" "$show_debug"
  
  # Check using multiple package managers
  if command -v dpkg >/dev/null 2>&1; then
    # Debian/Ubuntu systems
    if dpkg -l "$package" 2>/dev/null | grep -q "^ii"; then
      debug_log "DEPENDENCIES" "Package '$package' found via dpkg" "is_package_installed" "$show_debug"
      return 0
    fi
  fi
  
  if command -v rpm >/dev/null 2>&1; then
    # RedHat/CentOS/SUSE systems
    if rpm -q "$package" >/dev/null 2>&1; then
      debug_log "DEPENDENCIES" "Package '$package' found via rpm" "is_package_installed" "$show_debug"
      return 0
    fi
  fi
  
  if command -v pacman >/dev/null 2>&1; then
    # Arch Linux systems
    if pacman -Q "$package" >/dev/null 2>&1; then
      debug_log "DEPENDENCIES" "Package '$package' found via pacman" "is_package_installed" "$show_debug"
      return 0
    fi
  fi
  
  # Also check if the command exists directly
  if command -v "$package" >/dev/null 2>&1; then
    debug_log "DEPENDENCIES" "Package '$package' found via command check" "is_package_installed" "$show_debug"
    return 0
  fi
  
  debug_log "DEPENDENCIES" "Package '$package' not found" "is_package_installed" "$show_debug"
  return 1
}

# Function to check module dependencies
check_module_dependencies() {
  local module_file="$1"
  local show_debug="${2:-false}"  # Default: don't show debug in terminal
  local module_name_clean="${module_file%.sh}"
  
  debug_log "DEPENDENCIES" "Checking dependencies for module: $module_file" "check_module_dependencies" "$show_debug"
  
  # Get dependency arrays from metadata
  local dependencies_str="${MODULE_METADATA["${module_file}:dependencies"]:-}"
  local packages_str="${MODULE_METADATA["${module_file}:packages"]:-}"
  
  # Convert string back to array (dependencies are stored as space-separated)
  local -a dependencies
  local -a required_packages
  
  if [[ -n "$dependencies_str" ]]; then
    IFS=' ' read -ra dependencies <<< "$dependencies_str"
  fi
  
  if [[ -n "$packages_str" ]]; then
    IFS=' ' read -ra required_packages <<< "$packages_str"
  fi
  
  debug_log "DEPENDENCIES" "Module dependencies: [${dependencies[*]:-none}]" "check_module_dependencies" "$show_debug"
  debug_log "DEPENDENCIES" "Required packages: [${required_packages[*]:-none}]" "check_module_dependencies" "$show_debug"
  
  # Check module dependencies
  for dep in "${dependencies[@]}"; do
    if [[ -n "$dep" ]]; then
      debug_log "DEPENDENCIES" "Checking module dependency: $dep" "check_module_dependencies" "$show_debug"
      
      # Find the module file that provides this dependency
      local dep_found=false
      for other_module in "${MODULE_ORDER[@]}"; do
        local other_module_name="${MODULE_METADATA["${other_module}:name"]:-}"
        if [[ "$other_module_name" == "$dep" ]]; then
          local dep_status=$(get_module_status "${other_module%.sh}")
          if [[ "$dep_status" != "INSTALLED" ]]; then
            debug_log "DEPENDENCIES" "Module dependency '$dep' not installed (status: $dep_status)" "check_module_dependencies" "$show_debug"
            return 1
          fi
          dep_found=true
          break
        fi
      done
      
      if [[ "$dep_found" == false ]]; then
        debug_log "DEPENDENCIES" "Module dependency '$dep' not found in available modules" "check_module_dependencies" "$show_debug"
        return 1
      fi
    fi
  done
  
  # Check system package dependencies
  for package in "${required_packages[@]}"; do
    if [[ -n "$package" ]]; then
      debug_log "DEPENDENCIES" "Checking system package: $package" "check_module_dependencies" "$show_debug"
      if ! is_package_installed "$package" "$show_debug"; then
        debug_log "DEPENDENCIES" "Required package '$package' not installed" "check_module_dependencies" "$show_debug"
        return 1
      fi
    fi
  done
  
  debug_log "DEPENDENCIES" "All dependencies satisfied for module: $module_file" "check_module_dependencies" "$show_debug"
  return 0
}

# Function to get missing dependencies for a module
get_missing_dependencies() {
  local module_file="$1"
  local missing_deps=()
  local missing_packages=()
  
  # Get dependency arrays from metadata
  local dependencies_str="${MODULE_METADATA["${module_file}:dependencies"]:-}"
  local packages_str="${MODULE_METADATA["${module_file}:packages"]:-}"
  
  # Convert string back to array
  local -a dependencies
  local -a required_packages
  
  if [[ -n "$dependencies_str" ]]; then
    IFS=' ' read -ra dependencies <<< "$dependencies_str"
  fi
  
  if [[ -n "$packages_str" ]]; then
    IFS=' ' read -ra required_packages <<< "$packages_str"
  fi
  
  # Check module dependencies
  for dep in "${dependencies[@]}"; do
    if [[ -n "$dep" ]]; then
      local dep_found=false
      for other_module in "${MODULE_ORDER[@]}"; do
        local other_module_name="${MODULE_METADATA["${other_module}:name"]:-}"
        if [[ "$other_module_name" == "$dep" ]]; then
          local dep_status=$(get_module_status "${other_module%.sh}")
          if [[ "$dep_status" != "INSTALLED" ]]; then
            missing_deps+=("$dep")
          fi
          dep_found=true
          break
        fi
      done
      
      if [[ "$dep_found" == false ]]; then
        missing_deps+=("$dep (not found)")
      fi
    fi
  done
  
  # Check system package dependencies
  for package in "${required_packages[@]}"; do
    if [[ -n "$package" ]]; then
      if ! is_package_installed "$package" false; then  # false = don't show debug in terminal
        missing_packages+=("$package")
      fi
    fi
  done
  
  # Return results
  local result=""
  if [[ ${#missing_deps[@]} -gt 0 ]]; then
    result+="Modules: ${missing_deps[*]}"
  fi
  if [[ ${#missing_packages[@]} -gt 0 ]]; then
    if [[ -n "$result" ]]; then
      result+="; "
    fi
    result+="Packages: ${missing_packages[*]}"
  fi
  
  echo "$result"
}

# =============================================================================
# DOCKER ENVIRONMENT DETECTION FUNCTIONS
# =============================================================================

# Centralized function to detect current environment
detect_current_environment() {
  local current_env="host"
  if [[ -f /.dockerenv ]]; then
    current_env="docker"
  elif [[ -f /proc/1/cgroup ]] && grep -q docker /proc/1/cgroup 2>/dev/null; then
    current_env="docker"
  fi
  echo "$current_env"
}

# Function to check if module is compatible with current environment
is_module_environment_compatible() {
  local module_file="$1"
  
  # Validate input
  if [[ -z "$module_file" ]]; then
    echo "ERROR: is_module_environment_compatible called without module_file" >&2
    return 1
  fi
  
  # Get module environment requirement with explicit default
  local module_environment="${MODULE_METADATA["${module_file}:environment"]}"
  if [[ -z "$module_environment" ]]; then
    module_environment="both"
  fi
  
  # Detect current environment using centralized function
  local current_env=$(detect_current_environment)
  
  # Clean strings to handle any encoding issues
  local clean_module_env=$(printf '%s' "$module_environment" | tr -cd '[:alnum:]')
  local clean_current_env=$(printf '%s' "$current_env" | tr -cd '[:alnum:]')
  
  # Debug output (only when debug is enabled)
  if [[ "$OPTIMIZER_DEBUG" == "1" ]]; then
    echo "[COMPAT] module=$module_file | module_env='$clean_module_env' | current_env='$clean_current_env'" >&2
  fi
  
  # Check compatibility
  if [[ "$clean_module_env" == "both" ]]; then
    [[ "$OPTIMIZER_DEBUG" == "1" ]] && echo "[COMPAT] COMPATIBLE (supports both environments)" >&2
    return 0
  elif [[ "$clean_module_env" == "$clean_current_env" ]]; then
    [[ "$OPTIMIZER_DEBUG" == "1" ]] && echo "[COMPAT] COMPATIBLE (exact match)" >&2
    return 0
  else
    [[ "$OPTIMIZER_DEBUG" == "1" ]] && echo "[COMPAT] INCOMPATIBLE ('$clean_module_env' != '$clean_current_env')" >&2
    return 1
  fi
}

# Function to get environment-incompatible modules count and list
get_environment_incompatible_info() {
  local incompatible_count=0
  local incompatible_list=()
  
  # Check each module for compatibility
  for module in "${MODULE_ORDER[@]}"; do
    if ! is_module_environment_compatible "$module"; then
      ((incompatible_count++))
      local module_display_name="${MODULE_METADATA["${module}:name"]:-${module%.sh}}"
      incompatible_list+=("$module_display_name")
    fi
  done
  
  echo "$incompatible_count|${incompatible_list[*]}"
}

# Function to show banner
show_banner() {
  # Don't clear screen in debug mode to preserve debug messages
  if [[ "$OPTIMIZER_DEBUG" != "1" ]]; then
    clear
  fi
  printf "\n\033[1;36m╔══════════════════════════════════════════════════════════════╗\n"
  printf "║                                                              ║\n"
  printf "║           🎮 L4D2 DEDICATED SERVER OPTIMIZER 🎮              ║\n"
  printf "║                    Modular Edition v2.0                      ║\n"
  printf "║                                                              ║\n"
  printf "╚══════════════════════════════════════════════════════════════╝\033[0m\n"
  printf "\n"
}

# Function to show module menu
show_module_menu() {
  show_banner
  printf "\033[1;33m📋 Available Optimization Modules:\033[0m\n"
  
  # Show debug info if enabled
  if [[ "$OPTIMIZER_DEBUG" == "1" ]]; then
    printf "\033[1;31m🐛 DEBUG MODE ENABLED - Development features active\033[0m\n"
  fi
  
  # Show Docker environment information
  local current_env=$(detect_current_environment)
  
  if [[ "$current_env" == "docker" ]]; then
    current_env="docker"
    printf "\033[1;36m🐳 DOCKER ENVIRONMENT DETECTED\033[0m\n"
    
    # Get incompatible modules info
    local env_info=$(get_environment_incompatible_info)
    local incompatible_count="${env_info%%|*}"
    local incompatible_list="${env_info##*|}"
    
    if [[ $incompatible_count -gt 0 ]]; then
      printf "\033[1;33m⚠️  %d modules are not available in Docker containers\033[0m\n" "$incompatible_count"
      if [[ "$OPTIMIZER_DEBUG" == "1" ]]; then
        printf "\033[0;90m   Incompatible modules: %s\033[0m\n" "$incompatible_list"
      fi
    fi
  else
    printf "\033[1;32m🖥️  HOST ENVIRONMENT DETECTED - All modules available\033[0m\n"
  fi
  
  printf "\n"
  
  local counter=1
  local module_list=()
  
  # Use ordered list instead of associative array iteration
  for module in "${MODULE_ORDER[@]}"; do
    local module_name_clean="${module%.sh}"
    local status=$(get_module_status "$module_name_clean")
    local timestamp=$(get_module_timestamp "$module_name_clean")
    local status_icon=""
    local status_text=""
    
    # Get module metadata
    local module_display_name="${MODULE_METADATA["${module}:name"]:-Unknown}"
    local module_description="${MODULE_METADATA["${module}:description"]:-No description}"
    local module_category="${MODULE_METADATA["${module}:category"]:-other}"
    local module_version="${MODULE_METADATA["${module}:version"]:-1.0.0}"
    local module_timeout="${MODULE_METADATA["${module}:timeout"]:-$OPTIMIZER_TIMEOUT_DURATION}"
    local module_author="${MODULE_METADATA["${module}:author"]:-Unknown}"
    
    # Check dependencies and environment compatibility before determining status
    if [[ "$status" == "NOT_INSTALLED" ]] || [[ "$status" == "NOT INSTALLED" ]]; then
      # Check environment compatibility first
      if ! is_module_environment_compatible "$module"; then
        status="ENVIRONMENT_INCOMPATIBLE"
      elif ! check_module_dependencies "$module" false; then  # false = don't show debug in terminal
        status="DEPENDENCIES_MISSING"
      else
        status="NOT_INSTALLED"
      fi
    fi
    
    case "$status" in
      "INSTALLED")
        status_icon="✅"
        status_text="\033[0;32m[INSTALLED - $timestamp]\033[0m"
        ;;
      "FAILED")
        status_icon="❌"
        status_text="\033[0;31m[FAILED - $timestamp]\033[0m"
        ;;
      "DEPENDENCIES_MISSING")
        status_icon="⚠️"
        status_text="\033[1;33m[DEPENDENCIES MISSING]\033[0m"
        ;;
      "ENVIRONMENT_INCOMPATIBLE")
        status_icon="🚫"
        local module_env="${MODULE_METADATA["${module}:environment"]:-both}"
        status_text="\033[1;35m[INCOMPATIBLE - $module_env only]\033[0m"
        ;;
      *)
        status_icon="⚪"  
        status_text="\033[0;90m[NOT INSTALLED]\033[0m"
        status="NOT_INSTALLED"
        ;;
    esac
    
    # Category emoji mapping
    local category_emoji=""
    case "$module_category" in
      "memory")   category_emoji="🧠" ;;
      "network")  category_emoji="🌐" ;;
      "disk")     category_emoji="💾" ;;
      "cpu")      category_emoji="⚡" ;;
      "security") category_emoji="🔒" ;;
      "system")   category_emoji="⚙️" ;;
      "gaming")   category_emoji="🎮" ;;
      *)          category_emoji="📦" ;;
    esac
    
    # Format the line with proper spacing and category
    printf "  \033[1;36m%2d)\033[0m %s %s %-45s " "$counter" "$status_icon" "$category_emoji" "$module_description"
    echo -e "$status_text"
    
    # Always show module information (previously only in debug mode)
    local backup_required="${MODULE_METADATA["${module}:backup_required"]:-false}"
    local module_environment="${MODULE_METADATA["${module}:environment"]:-both}"
    local backup_icon=""
    if [[ "$backup_required" == "true" ]]; then
      backup_icon="💾"
    else
      backup_icon="📝"
    fi
    
    # Environment compatibility icon
    local env_icon=""
    case "$module_environment" in
      "host")   env_icon="🖥️" ;;
      "docker") env_icon="🐳" ;;
      "both")   env_icon="🔄" ;;
      *)        env_icon="❓" ;;
    esac
    
    printf "      \033[0;90m└─ Name: %s | Version: %s | Category: %s | Environment: %s %s | Backup: %s %s\033[0m\n" \
           "$module_display_name" "$module_version" "$module_category" "$env_icon" "$module_environment" "$backup_icon" "$backup_required"
    
    # Show dependency information
    local dependencies_str="${MODULE_METADATA["${module}:dependencies"]:-}"
    local packages_str="${MODULE_METADATA["${module}:packages"]:-}"
    
    if [[ -n "$dependencies_str" || -n "$packages_str" ]]; then
      if [[ -n "$dependencies_str" ]]; then
        printf "      \033[0;90m└─ Module Deps: [%s]\033[0m\n" "$dependencies_str"
      fi
      if [[ -n "$packages_str" ]]; then
        printf "      \033[0;90m└─ Package Deps: [%s]\033[0m\n" "$packages_str"
      fi
      
      # Show missing dependencies if status is DEPENDENCIES_MISSING
      if [[ "$status" == "DEPENDENCIES_MISSING" ]]; then
        local missing=$(get_missing_dependencies "$module")
        if [[ -n "$missing" ]]; then
          printf "      \033[1;31m└─ ⚠️  Missing: %s\033[0m\n" "$missing"
        fi
      fi
    fi
    
    # Show additional debug info only if DEBUG is enabled
    if [[ "$OPTIMIZER_DEBUG" == "1" ]]; then
      printf "      \033[0;33m└─ 🐛 DEBUG: File=%s | Timeout=%ss | Author=%s\033[0m\n" \
             "$module" "$module_timeout" "$module_author"
    fi
    
    module_list+=("$module")
    ((counter++))
  done
  
  printf "\n"
  printf "\033[1;33m🛠️  Actions:\033[0m\n"
  printf "  \033[1;36m 0)\033[0m 🚀 Install ALL modules\n"
  printf "  \033[1;36m R)\033[0m 🔄 Reset installation status\n"
  printf "  \033[1;36m S)\033[0m 📊 Show system information\n"
  printf "  \033[1;36m M)\033[0m 📋 Show detailed modules information\n"
  printf "  \033[1;36m Q)\033[0m 🚪 Quit\n"
  printf "\n"
  
  # Store module list for selection
  declare -g -a CURRENT_MODULE_LIST=("${module_list[@]}")
}

# Export function to make it available in modules
export -f log_message
export -f debug_log
export -f clean_debug_log

# Function to discover and load modules dynamically
discover_modules() {
  # Clear existing arrays
  MODULES=()
  MODULE_ORDER=()
  
  # Arrays to store module metadata
  declare -g -A MODULE_METADATA
  
  debug_log "SYSTEM" "Starting module discovery in $MODULE_DIR" "discover_modules"
  log_message "SYSTEM" "INFO" "Discovering modules in $MODULE_DIR"
  
  # Find all .sh files in modules directory
  while IFS= read -r -d '' module_file; do
    local filename=$(basename "$module_file")
    local module_name="${filename%.sh}"
    
    debug_log "SYSTEM" "Processing file: $filename" "discover_modules"
    
    # Skip prototype templates in production mode
    if [[ "$filename" =~ template\.sh$ && "$OPTIMIZER_DEBUG" != "1" ]]; then
      debug_log "SYSTEM" "Skipping template file $filename (OPTIMIZER_DEBUG=$OPTIMIZER_DEBUG)" "discover_modules"
      log_message "SYSTEM" "INFO" "Skipping template file $filename (production mode)"
      continue
    fi
    
    # Check if file is executable
    if [[ ! -x "$module_file" ]]; then
      debug_log "SYSTEM" "Module $filename is not executable, skipping" "discover_modules"
      log_message "SYSTEM" "WARNING" "Module $filename is not executable, skipping"
      continue
    fi
    
    # Source the module to get its metadata
    debug_log "SYSTEM" "Sourcing module: $filename" "discover_modules"
    if source "$module_file" && declare -f register_module > /dev/null; then
      # Call register_module function
      debug_log "SYSTEM" "Calling register_module() for $filename" "discover_modules"
      register_module 2>/dev/null
      
      # Validate required variables
      if [[ -n "$MODULE_NAME" && -n "$MODULE_DESCRIPTION" ]]; then
        debug_log "SYSTEM" "Module metadata validated: $MODULE_NAME" "discover_modules"
        
        # Store module metadata
        MODULE_METADATA["${filename}:name"]="$MODULE_NAME"
        MODULE_METADATA["${filename}:description"]="$MODULE_DESCRIPTION"
        MODULE_METADATA["${filename}:version"]="${MODULE_VERSION:-1.0.0}"
        MODULE_METADATA["${filename}:category"]="${MODULE_CATEGORY:-other}"
        MODULE_METADATA["${filename}:timeout"]="${MODULE_TIMEOUT:-$OPTIMIZER_TIMEOUT_DURATION}"
        MODULE_METADATA["${filename}:reboot"]="${MODULE_REQUIRES_REBOOT:-false}"
        MODULE_METADATA["${filename}:environment"]="${MODULE_ENVIRONMENT:-both}"
        MODULE_METADATA["${filename}:author"]="${MODULE_AUTHOR:-Unknown}"
        MODULE_METADATA["${filename}:impact"]="${MODULE_GAME_IMPACT:-No information available}"
        MODULE_METADATA["${filename}:documentation_url"]="${MODULE_DOCUMENTATION_URL:-Not specified}"
        
        # Store dependencies as space-separated strings for easier handling
        if [[ -n "${MODULE_DEPENDENCIES[*]:-}" ]]; then
          MODULE_METADATA["${filename}:dependencies"]="${MODULE_DEPENDENCIES[*]}"
          debug_log "SYSTEM" "Stored module dependencies for $filename: [${MODULE_DEPENDENCIES[*]}]" "discover_modules"
        else
          MODULE_METADATA["${filename}:dependencies"]=""
        fi
        
        if [[ -n "${MODULE_REQUIRED_PACKAGES[*]:-}" ]]; then
          MODULE_METADATA["${filename}:packages"]="${MODULE_REQUIRED_PACKAGES[*]}"
          debug_log "SYSTEM" "Stored required packages for $filename: [${MODULE_REQUIRED_PACKAGES[*]}]" "discover_modules"
        else
          MODULE_METADATA["${filename}:packages"]=""
        fi
        
        debug_log "SYSTEM" "Stored metadata for $filename: impact='${MODULE_GAME_IMPACT:-No information available}', doc_url='${MODULE_DOCUMENTATION_URL:-Not specified}'" "discover_modules"
        
        # Store backup configuration metadata
        MODULE_METADATA["${filename}:backup_required"]="${MODULE_REQUIRES_BACKUP:-false}"
        if [[ "${MODULE_REQUIRES_BACKUP:-false}" == "true" ]]; then
          MODULE_METADATA["${filename}:backup_files"]="${MODULE_BACKUP_FILES[*]:-}"
          MODULE_METADATA["${filename}:backup_commands"]="${MODULE_BACKUP_COMMANDS[*]:-}"
          debug_log "SYSTEM" "Backup enabled for $filename: files=[${MODULE_BACKUP_FILES[*]:-}]" "discover_modules"
        fi
        
        # Store environment variables used by this module
        if [[ -n "${MODULE_ENV_VARIABLES[*]:-}" ]]; then
          MODULE_METADATA["${filename}:env_variables"]="${MODULE_ENV_VARIABLES[*]}"
          debug_log "SYSTEM" "Environment variables for $filename: [${MODULE_ENV_VARIABLES[*]}]" "discover_modules"
        else
          MODULE_METADATA["${filename}:env_variables"]=""
        fi
        
        # Add to arrays
        MODULES["$filename"]="$MODULE_DESCRIPTION"
        MODULE_ORDER+=("$filename")
        
        debug_log "SYSTEM" "Successfully loaded module: $MODULE_NAME ($filename)" "discover_modules"
        log_message "SYSTEM" "SUCCESS" "Loaded module: $MODULE_NAME ($filename)"
      else
        debug_log "SYSTEM" "Module $filename missing required metadata (NAME=$MODULE_NAME, DESC=$MODULE_DESCRIPTION)" "discover_modules"
        log_message "SYSTEM" "ERROR" "Module $filename missing required metadata"
      fi
    else
      debug_log "SYSTEM" "Module $filename does not have register_module function or failed to source" "discover_modules"
      log_message "SYSTEM" "WARNING" "Module $filename does not have register_module function"
    fi
    
    # Clean up variables for next iteration
    unset MODULE_NAME MODULE_DESCRIPTION MODULE_VERSION MODULE_CATEGORY
    unset MODULE_TIMEOUT MODULE_REQUIRES_REBOOT MODULE_ENVIRONMENT MODULE_DEPENDENCIES MODULE_REQUIRED_PACKAGES
    unset MODULE_AUTHOR MODULE_DOCUMENTATION_URL MODULE_GAME_IMPACT 
    unset MODULE_REQUIRES_BACKUP MODULE_BACKUP_FILES MODULE_BACKUP_COMMANDS MODULE_ENV_VARIABLES
    
  done < <(find "$MODULE_DIR" -name "*.sh" -type f -print0 | sort -z)
  
  debug_log "SYSTEM" "Module discovery completed. Found ${#MODULE_ORDER[@]} modules: [${MODULE_ORDER[*]}]" "discover_modules"
  log_message "SYSTEM" "INFO" "Module discovery completed. Found ${#MODULE_ORDER[@]} modules"
}

# Function to execute a specific module
execute_module() {
  local module_file="$1"
  local module_name="${module_file%.sh}"
  local module_path="$MODULE_DIR/$module_file"
  
  debug_log "EXECUTION" "Starting execution of module: $module_file" "execute_module"
  
  # Get module-specific timeout and backup info
  local module_timeout="${MODULE_METADATA["${module_file}:timeout"]:-$OPTIMIZER_TIMEOUT_DURATION}"
  local module_display_name="${MODULE_METADATA["${module_file}:name"]:-$module_name}"
  local module_backup_required="${MODULE_METADATA["${module_file}:backup_required"]:-false}"
  
  debug_log "EXECUTION" "Module settings: timeout=$module_timeout, backup=$module_backup_required" "execute_module"
  
  printf "\n"
  printf "\033[1;44m 📦 EXECUTING MODULE: %s \033[0m\n" "$module_display_name"
  
  if [[ "$OPTIMIZER_DEBUG" == "1" ]]; then
    printf "\033[0;90m   File: %s | Timeout: %s seconds\033[0m\n" "$module_file" "$module_timeout"
    if [[ "$module_backup_required" == "true" ]]; then
      printf "\033[0;90m   💾 Backup: Enabled | Files: %s\033[0m\n" "${MODULE_METADATA["${module_file}:backup_files"]:-None}"
      printf "\033[0;90m   📋 Commands: %s\033[0m\n" "${MODULE_METADATA["${module_file}:backup_commands"]:-None}"
    else
      printf "\033[0;90m   💾 Backup: Disabled\033[0m\n"
    fi
  fi
  
  printf "\n"
  
  if [[ ! -f "$module_path" ]]; then
    debug_log "EXECUTION" "Module file not found: $module_path" "execute_module"
    log_message "$module_name" "ERROR" "Module file not found: $module_path"
    save_module_status "$module_name" "FAILED" "$(date '+%Y-%m-%d %H:%M:%S')"
    return 1
  fi
  
  if [[ ! -x "$module_path" ]]; then
    debug_log "EXECUTION" "Module $module_path lacks execution permission" "execute_module"
    log_message "$module_name" "ERROR" "No execution permission"
    save_module_status "$module_name" "FAILED" "$(date '+%Y-%m-%d %H:%M:%S')"
    return 1
  fi
  
  # Check environment compatibility before execution
  debug_log "EXECUTION" "Checking environment compatibility for module: $module_file" "execute_module"
  
  if ! is_module_environment_compatible "$module_file"; then
    local module_env="${MODULE_METADATA["${module_file}:environment"]:-both}"
    local current_env=$(detect_current_environment)
    
    printf "\n"
    printf "\033[1;31m🚫 ENVIRONMENT COMPATIBILITY CHECK FAILED\033[0m\n"
    printf "\033[1;33m📋 Current environment: %s\033[0m\n" "$current_env"
    printf "\033[1;33m📋 Module requires: %s\033[0m\n" "$module_env"
    printf "   This module is not designed to run in the current environment.\n"
    printf "\n"
    read -p "Press ENTER to continue..."
    
    debug_log "EXECUTION" "Environment incompatibility for $module_name: current=$current_env, required=$module_env" "execute_module"
    log_message "$module_name" "ERROR" "Environment incompatible: current=$current_env, required=$module_env"
    save_module_status "$module_name" "FAILED" "$(date '+%Y-%m-%d %H:%M:%S')"
    return 1
  fi
  
  # Check dependencies before execution
  debug_log "EXECUTION" "Checking dependencies for module: $module_file" "execute_module"
  if ! check_module_dependencies "$module_file" true; then  # true = show debug in terminal during execution
    local missing=$(get_missing_dependencies "$module_file")
    printf "\n"
    printf "\033[1;31m⚠️  DEPENDENCY CHECK FAILED\033[0m\n"
    if [[ -n "$missing" ]]; then
      printf "\033[1;33m📋 Missing dependencies: %s\033[0m\n" "$missing"
      debug_log "EXECUTION" "Dependencies missing for $module_name: $missing" "execute_module"
      log_message "$module_name" "ERROR" "Dependencies missing: $missing"
    else
      printf "\033[1;33m📋 Some dependencies are not satisfied\033[0m\n"
      debug_log "EXECUTION" "Dependencies not satisfied for $module_name" "execute_module"
      log_message "$module_name" "ERROR" "Dependencies not satisfied"
    fi
    printf "   Please install missing dependencies and try again.\n"
    printf "\n"
    read -p "Press ENTER to continue..."
    save_module_status "$module_name" "FAILED" "$(date '+%Y-%m-%d %H:%M:%S')"
    return 1
  fi
  
  debug_log "EXECUTION" "Dependencies satisfied, proceeding with execution" "execute_module"
  debug_log "EXECUTION" "Executing module with timeout $module_timeout: bash $module_path" "execute_module"
  
  # Execute with module-specific timeout
  timeout "$module_timeout" bash "$module_path"
  exit_code=$?
  
  debug_log "EXECUTION" "Module execution completed with exit code: $exit_code" "execute_module"
  
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  
  if [[ $exit_code -eq 0 ]]; then
    printf "\n"
    debug_log "EXECUTION" "Module $module_name completed successfully" "execute_module"
    log_message "$module_name" "SUCCESS" "Module completed successfully"
    save_module_status "$module_name" "INSTALLED" "$timestamp"
    return 0
  elif [[ $exit_code -eq 124 ]]; then
    printf "\n"
    debug_log "EXECUTION" "Module $module_name exceeded timeout of $module_timeout seconds" "execute_module"
    log_message "$module_name" "ERROR" "Module exceeded $module_timeout seconds timeout"
    save_module_status "$module_name" "FAILED" "$timestamp"
    return 1
  else
    printf "\n"
    debug_log "EXECUTION" "Module $module_name failed with exit code $exit_code" "execute_module"
    log_message "$module_name" "WARNING" "Module returned error code $exit_code"
    save_module_status "$module_name" "FAILED" "$timestamp"
    return 1
  fi
}

# Function to install all modules
install_all_modules() {
  printf "\n"
  printf "\033[1;43m 🚀 INSTALLING ALL OPTIMIZATION MODULES \033[0m\n"
  printf "\n"
  
  local total_modules=${#MODULE_ORDER[@]}
  local successful=0
  local failed=0
  
  # Use ordered list for consistent execution
  for module in "${MODULE_ORDER[@]}"; do
    if execute_module "$module"; then
      ((successful++))
    else
      ((failed++))
    fi
    
    # Small delay between modules
    sleep 1
  done
  
  printf "\n"
  printf "\033[1;42m ✅ INSTALLATION SUMMARY \033[0m\n"
  printf "  📊 Total modules: %d\n" "$total_modules"
  printf "  ✅ Successful: %d\n" "$successful"
  printf "  ❌ Failed: %d\n" "$failed"
  printf "\n"
  
  if [[ $failed -eq 0 ]]; then
    printf "\033[1;32m🎉 All modules installed successfully!\033[0m\n"
  else
    printf "\033[1;33m⚠️  Some modules failed. Check the logs above for details.\033[0m\n"
  fi
  
  printf "\n"
  read -p "Press ENTER to continue..."
}

# Function to reset installation status
reset_status() {
  echo ""
  echo -e "\033[1;41m ⚠️  RESET INSTALLATION STATUS ⚠️  \033[0m"
  echo ""
  echo "This will reset all module installation status to 'NOT INSTALLED'."
  echo "The actual system configuration will NOT be changed."
  echo ""
  read -p "Are you sure you want to continue? (y/N): " confirm
  
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    rm -f "$STATUS_FILE"
    echo ""
    echo -e "\033[1;32m✅ Installation status reset successfully!\033[0m"
  else
    echo ""
    echo -e "\033[1;33m❌ Reset cancelled.\033[0m"
  fi
  
  echo ""
  read -p "Press ENTER to continue..."
}

# Function to show system information
show_system_info() {
  show_banner
  echo -e "\033[1;33m🖥️  System Information:\033[0m"
  echo ""
  
  echo -e "\033[1;36mOperating System:\033[0m"
  if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    echo "  • Name: $PRETTY_NAME"
    echo "  • ID: $ID"
    echo "  • Version: $VERSION_ID"
  fi
  
  echo ""
  echo -e "\033[1;36mHardware:\033[0m"
  echo "  • CPU Cores: $(nproc)"
  echo "  • Memory: $(free -h | awk '/^Mem:/ {print $2}')"
  echo "  • Architecture: $(uname -m)"
  
  echo ""
  echo -e "\033[1;36mNetwork:\033[0m"
  local main_interface=$(ip route get 8.8.8.8 2>/dev/null | awk '{print $5; exit}')
  if [[ -n "$main_interface" ]]; then
    local ip_address=$(ip addr show "$main_interface" 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d'/' -f1)
    echo "  • Main Interface: $main_interface"
    echo "  • IP Address: ${ip_address:-Not configured}"
  else
    echo "  • Main Interface: Not detected"
  fi
  
  # Show DNS servers
  echo "  • DNS Servers:"
  if [[ -f /etc/resolv.conf ]]; then
    local dns_servers=($(grep "^nameserver" /etc/resolv.conf | awk '{print $2}'))
    if [[ ${#dns_servers[@]} -gt 0 ]]; then
      for i in "${!dns_servers[@]}"; do
        echo "    └─ DNS $((i+1)): ${dns_servers[i]}"
      done
    else
      echo "    └─ No DNS servers found in /etc/resolv.conf"
    fi
  else
    echo "    └─ /etc/resolv.conf not found"
  fi
  
  # Show systemd-resolved status if available
  if command -v resolvectl >/dev/null 2>&1; then
    local resolved_dns=$(resolvectl status 2>/dev/null | grep "DNS Servers:" | head -1 | sed 's/.*DNS Servers: *//')
    [[ -n "$resolved_dns" ]] && echo "    └─ Systemd-resolved: $resolved_dns"
  elif command -v systemd-resolve >/dev/null 2>&1; then
    local resolved_dns=$(systemd-resolve --status 2>/dev/null | grep "DNS Servers:" | head -1 | sed 's/.*DNS Servers: *//')
    [[ -n "$resolved_dns" ]] && echo "    └─ Systemd-resolved: $resolved_dns"
  fi
  
  printf "\n"
  printf "\033[1;36mOptimizer Configuration:\033[0m\n"
  printf "  • Config Directory: %s\n" "$OPTIMIZER_CONFIG_DIR"
  printf "  • Data Directory: %s\n" "$OPTIMIZER_DATA_DIR"
  printf "  • Log Directory: %s\n" "$OPTIMIZER_LOG_DIR"
  printf "  • Status File: %s\n" "$STATUS_FILE"
  printf "  • Modules Directory: %s\n" "$MODULE_DIR"
  printf "  • Available Modules: %d\n" "${#MODULE_ORDER[@]}"
  
  # Show .env file status
  if [[ -f "$ENV_FILE" ]]; then
    printf "  • Environment File: %s ✅\n" "$ENV_FILE"
    printf "  • Debug Mode: %s\n" "${OPTIMIZER_DEBUG:-0}"
    printf "  • Module Timeout: %s seconds\n" "${OPTIMIZER_TIMEOUT_DURATION:-180}"
  else
    printf "  • Environment File: Not found (using defaults)\n"
  fi
  
  # Show debug log info if DEBUG is enabled
  if [[ "$OPTIMIZER_DEBUG" == "1" ]]; then
    printf "  • Debug Log File: %s\n" "$DEBUG_LOG_FILE"
    if [[ -f "$DEBUG_LOG_FILE" ]]; then
      local debug_size=$(du -h "$DEBUG_LOG_FILE" 2>/dev/null | cut -f1)
      local debug_lines=$(wc -l < "$DEBUG_LOG_FILE" 2>/dev/null)
      printf "  • Debug Log Size: %s (%s lines)\n" "${debug_size:-0}" "${debug_lines:-0}"
    else
      printf "  • Debug Log Size: Not created yet\n"
    fi
  fi
  
  local installed_count=0
  local backup_enabled_count=0
  for module in "${MODULE_ORDER[@]}"; do
    local status=$(get_module_status "${module%.sh}")
    [[ "$status" == "INSTALLED" ]] && ((installed_count++))
    
    # Count modules with backup enabled
    local backup_required="${MODULE_METADATA["${module}:backup_required"]:-false}"
    [[ "$backup_required" == "true" ]] && ((backup_enabled_count++))
  done
  printf "  • Installed Modules: %d/%d\n" "$installed_count" "${#MODULE_ORDER[@]}"
  printf "  • Modules with Backup: %d/%d\n" "$backup_enabled_count" "${#MODULE_ORDER[@]}"
  printf "  • Backup Directory: %s/backups\n" "$OPTIMIZER_DATA_DIR"
  
  # Show debug log viewer option if DEBUG is enabled and log exists
  if [[ "$OPTIMIZER_DEBUG" == "1" && -f "$DEBUG_LOG_FILE" ]]; then
    printf "\n"
    printf "\033[1;33m🐛 Debug Options:\033[0m\n"
    printf "  • View last 20 debug entries: tail -20 %s\n" "$DEBUG_LOG_FILE"
    printf "  • View full debug log: less %s\n" "$DEBUG_LOG_FILE"
    printf "  • Clear debug log: > %s\n" "$DEBUG_LOG_FILE"
  fi
  
  printf "\n"
  read -p "Press ENTER to continue..."
}

# Function to show detailed module information
show_modules_info() {
  debug_log "MODULES_INFO" "Starting detailed modules information display" "show_modules_info"
  
  show_banner
  printf "\033[1;33m📋 Detailed Module Information:\033[0m\n"
  printf "\n"
  
  if [[ ${#MODULE_ORDER[@]} -eq 0 ]]; then
    debug_log "MODULES_INFO" "No modules found to display" "show_modules_info"
    printf "\033[1;31m❌ No modules found!\033[0m\n"
    printf "\n"
    read -p "Press ENTER to continue..."
    return
  fi
  
  debug_log "MODULES_INFO" "Displaying information for ${#MODULE_ORDER[@]} modules" "show_modules_info"
  
  local counter=1
  
  for module in "${MODULE_ORDER[@]}"; do
    local module_name_clean="${module%.sh}"
    local status=$(get_module_status "$module_name_clean")
    local timestamp=$(get_module_timestamp "$module_name_clean")
    
    # Get all module metadata
    local module_display_name="${MODULE_METADATA["${module}:name"]:-Unknown}"
    local module_description="${MODULE_METADATA["${module}:description"]:-No description}"
    local module_version="${MODULE_METADATA["${module}:version"]:-1.0.0}"
    local module_category="${MODULE_METADATA["${module}:category"]:-other}"
    local module_timeout="${MODULE_METADATA["${module}:timeout"]:-$OPTIMIZER_TIMEOUT_DURATION}"
    local module_reboot="${MODULE_METADATA["${module}:reboot"]:-false}"
    local module_author="${MODULE_METADATA["${module}:author"]:-Unknown}"
    local module_impact="${MODULE_METADATA["${module}:impact"]:-No information available}"
    local module_backup_required="${MODULE_METADATA["${module}:backup_required"]:-false}"
    local module_documentation_url="${MODULE_METADATA["${module}:documentation_url"]:-Not specified}"
    
    # Status formatting
    local status_icon=""
    local status_color=""
    case "$status" in
      "INSTALLED")
        status_icon="✅"
        status_color="\033[0;32m"
        ;;
      "FAILED")
        status_icon="❌"
        status_color="\033[0;31m"
        ;;
      *)
        status_icon="⚪"
        status_color="\033[0;90m"
        status="NOT INSTALLED"
        ;;
    esac
    
    # Category emoji
    local category_emoji=""
    case "$module_category" in
      "memory")   category_emoji="🧠" ;;
      "network")  category_emoji="🌐" ;;
      "disk")     category_emoji="💾" ;;
      "cpu")      category_emoji="⚡" ;;
      "security") category_emoji="🔒" ;;
      "system")   category_emoji="⚙️" ;;
      "gaming")   category_emoji="🎮" ;;
      *)          category_emoji="📦" ;;
    esac
    
    # Module header
    printf "\033[1;36m╔══════════════════════════════════════════════════════════════╗\033[0m\n"
    printf "\033[1;36m║\033[0m \033[1;33m%2d) %s %s %-44s\033[0m \033[1;36m║\033[0m\n" "$counter" "$status_icon" "$category_emoji" "$module_display_name"
    printf "\033[1;36m╚══════════════════════════════════════════════════════════════╝\033[0m\n"
    
    # Basic information
    printf "\033[1;32m📝 Basic Information:\033[0m\n"
    printf "  • \033[1;37mName:\033[0m %s\n" "$module_display_name"
    printf "  • \033[1;37mFilename:\033[0m %s\n" "$module"
    printf "  • \033[1;37mDescription:\033[0m %s\n" "$module_description"
    printf "  • \033[1;37mVersion:\033[0m %s\n" "$module_version"
    printf "  • \033[1;37mCategory:\033[0m %s %s\n" "$category_emoji" "$module_category"
    printf "  • \033[1;37mAuthor:\033[0m %s\n" "$module_author"
    if [[ "$module_documentation_url" != "Not specified" ]]; then
      printf "  • \033[1;37mDocumentation:\033[0m %s\n" "$module_documentation_url"
    fi
    
    # Status information
    printf "\n\033[1;34m📊 Status Information:\033[0m\n"
    printf "  • \033[1;37mCurrent Status:\033[0m %b%s\033[0m\n" "$status_color" "$status"
    if [[ "$status" != "NOT INSTALLED" ]]; then
      printf "  • \033[1;37mLast Execution:\033[0m %s\n" "$timestamp"
    fi
    
    # Technical specifications
    printf "\n\033[1;35m⚙️  Technical Specifications:\033[0m\n"
    printf "  • \033[1;37mTimeout:\033[0m %s seconds\n" "$module_timeout"
    printf "  • \033[1;37mRequires Reboot:\033[0m "
    if [[ "$module_reboot" == "true" ]]; then
      printf "\033[1;31m⚠️  Yes\033[0m\n"
    else
      printf "\033[1;32m✅ No\033[0m\n"
    fi
    
    # Environment compatibility
    local module_environment="${MODULE_METADATA["${module}:environment"]:-both}"
    local current_env="host"
    if [[ -f /.dockerenv ]] || grep -q docker /proc/1/cgroup 2>/dev/null; then
      current_env="docker"
    fi
    
    printf "  • \033[1;37mEnvironment Support:\033[0m "
    case "$module_environment" in
      "host")
        printf "\033[1;32m🖥️  Host Only\033[0m"
        if [[ "$current_env" == "docker" ]]; then
          printf " \033[1;31m(⚠️  Not compatible with current Docker environment)\033[0m"
        fi
        printf "\n"
        ;;
      "docker")
        printf "\033[1;36m🐳 Docker Only\033[0m"
        if [[ "$current_env" == "host" ]]; then
          printf " \033[1;31m(⚠️  Not compatible with current host environment)\033[0m"
        fi
        printf "\n"
        ;;
      "both")
        printf "\033[1;32m🔄 Both Host and Docker\033[0m"
        printf " \033[1;32m(✅ Compatible with current %s environment)\033[0m" "$current_env"
        printf "\n"
        ;;
      *)
        printf "\033[1;90m❓ Unknown (%s)\033[0m\n" "$module_environment"
        ;;
    esac
    
    # Backup configuration
    printf "  • \033[1;37mBackup System:\033[0m "
    if [[ "$module_backup_required" == "true" ]]; then
      printf "\033[1;32m💾 Enabled\033[0m\n"
      
      local backup_files="${MODULE_METADATA["${module}:backup_files"]:-}"
      local backup_commands="${MODULE_METADATA["${module}:backup_commands"]:-}"
      
      if [[ -n "$backup_files" ]]; then
        printf "    └─ \033[1;37mFiles to backup:\033[0m %s\n" "$backup_files"
      fi
      if [[ -n "$backup_commands" ]]; then
        printf "    └─ \033[1;37mCommands to backup:\033[0m %s\n" "$backup_commands"
      fi
    else
      printf "\033[1;90m📝 Disabled\033[0m\n"
    fi
    
    # Dependencies information
    local dependencies_str="${MODULE_METADATA["${module}:dependencies"]:-}"
    local packages_str="${MODULE_METADATA["${module}:packages"]:-}"
    
    printf "\n\033[1;34m🔗 Dependencies:\033[0m\n"
    
    if [[ -n "$dependencies_str" || -n "$packages_str" ]]; then
      # Show module dependencies
      if [[ -n "$dependencies_str" ]]; then
        printf "  • \033[1;37mRequired Modules:\033[0m\n"
        IFS=' ' read -ra deps_array <<< "$dependencies_str"
        for dep in "${deps_array[@]}"; do
          if [[ -n "$dep" ]]; then
            # Check if dependency is satisfied
            local dep_satisfied=false
            local dep_status=""
            for other_module in "${MODULE_ORDER[@]}"; do
              local other_module_name="${MODULE_METADATA["${other_module}:name"]:-}"
              if [[ "$other_module_name" == "$dep" ]]; then
                dep_status=$(get_module_status "${other_module%.sh}")
                if [[ "$dep_status" == "INSTALLED" ]]; then
                  dep_satisfied=true
                fi
                break
              fi
            done
            
            if [[ "$dep_satisfied" == true ]]; then
              printf "    └─ \033[1;32m✅ %s\033[0m (installed)\n" "$dep"
            else
              printf "    └─ \033[1;31m❌ %s\033[0m (%s)\n" "$dep" "${dep_status:-not found}"
            fi
          fi
        done
      fi
      
      # Show package dependencies
      if [[ -n "$packages_str" ]]; then
        printf "  • \033[1;37mRequired Packages:\033[0m\n"
        IFS=' ' read -ra pkgs_array <<< "$packages_str"
        for pkg in "${pkgs_array[@]}"; do
          if [[ -n "$pkg" ]]; then
            if is_package_installed "$pkg" false; then  # false = don't show debug in terminal
              printf "    └─ \033[1;32m✅ %s\033[0m (installed)\n" "$pkg"
            else
              printf "    └─ \033[1;31m❌ %s\033[0m (missing)\n" "$pkg"
            fi
          fi
        done
      fi
      
      # Overall dependency status
      if check_module_dependencies "$module" false; then  # false = don't show debug in terminal
        printf "  • \033[1;37mOverall Status:\033[0m \033[1;32m✅ All dependencies satisfied\033[0m\n"
      else
        printf "  • \033[1;37mOverall Status:\033[0m \033[1;31m⚠️  Dependencies missing\033[0m\n"
        local missing=$(get_missing_dependencies "$module")
        if [[ -n "$missing" ]]; then
          printf "    └─ \033[1;33mMissing: %s\033[0m\n" "$missing"
        fi
      fi
    else
      printf "  • \033[1;32m✅ No dependencies required\033[0m\n"
    fi
    
    # Game impact
    printf "\n\033[1;33m🎮 Game Impact:\033[0m\n"
    if [[ "$module_impact" != "No information available" ]]; then
      printf "  • \033[1;37mDescription:\033[0m %s\n" "$module_impact"
    else
      printf "  • \033[1;90mNo specific game impact information available\033[0m\n"
    fi
    
    # Environment Variables
    local env_variables_str="${MODULE_METADATA["${module}:env_variables"]:-}"
    printf "\n\033[1;35m🔧 Environment Variables:\033[0m\n"
    
    if [[ -n "$env_variables_str" ]]; then
      printf "  • \033[1;37mConfigurable Variables:\033[0m\n"
      IFS=' ' read -ra env_vars_array <<< "$env_variables_str"
      for env_var in "${env_vars_array[@]}"; do
        if [[ -n "$env_var" ]]; then
          # Get current value from environment and clean it
          local current_value="${!env_var:-Not set}"
          
          # Remove quotes and comments from the displayed value
          current_value="${current_value%%\"*}"  # Remove everything after first quote
          current_value="${current_value%%#*}"   # Remove everything after first #
          current_value="${current_value// /}"   # Remove spaces
          
          # If value is empty after cleaning, show "Not set"
          [[ -z "$current_value" ]] && current_value="Not set"
          
          # Show variable with current value
          printf "    └─ \033[1;36m%s\033[0m = \033[1;32m%s\033[0m\n" "$env_var" "$current_value"
        fi
      done
      printf "  • \033[1;37mConfiguration File:\033[0m %s\n" "$ENV_FILE"
    else
      printf "  • \033[1;90mNo configurable environment variables\033[0m\n"
    fi
    
    # File information
    local module_path="$MODULE_DIR/$module"
    if [[ -f "$module_path" ]]; then
      local file_size=$(du -h "$module_path" 2>/dev/null | cut -f1)
      local file_perms=$(ls -l "$module_path" 2>/dev/null | awk '{print $1}')
      printf "\n\033[1;36m📄 File Information:\033[0m\n"
      printf "  • \033[1;37mPath:\033[0m %s\n" "$module_path"
      printf "  • \033[1;37mSize:\033[0m %s\n" "${file_size:-Unknown}"
      printf "  • \033[1;37mPermissions:\033[0m %s\n" "${file_perms:-Unknown}"
      if [[ -x "$module_path" ]]; then
        printf "  • \033[1;37mExecutable:\033[0m \033[1;32m✅ Yes\033[0m\n"
      else
        printf "  • \033[1;37mExecutable:\033[0m \033[1;31m❌ No\033[0m\n"
      fi
    fi
    
    printf "\n"
    
    # Add separator if not the last module
    if [[ $counter -lt ${#MODULE_ORDER[@]} ]]; then
      printf "\033[0;90m────────────────────────────────────────────────────────────────\033[0m\n"
      printf "\n"
    fi
    
    ((counter++))
  done
  
  printf "\n"
  printf "\033[1;32m📊 Summary: %d modules total\033[0m\n" "${#MODULE_ORDER[@]}"
  printf "\n"
  read -p "Press ENTER to continue..."
}

# Main menu loop
main_menu() {
  while true; do
    # Load current status
    load_module_status
    
    # Show menu
    show_module_menu
    
    # Get user input
    read -p "Select option: " choice
    
    # Debug: show received input if DEBUG is enabled
    if [[ "$OPTIMIZER_DEBUG" == "1" ]]; then
      debug_log "MENU" "User input received: '$choice'" "main_menu"
    fi
    
    # Convert to uppercase for case-insensitive matching
    choice=$(echo "$choice" | tr '[:lower:]' '[:upper:]')
    
    # Calculate valid range based on available modules
    local max_modules=${#CURRENT_MODULE_LIST[@]}
    
    case "$choice" in
      [1-9]|[1-9][0-9])
        # Execute individual module (support up to 99 modules)
        local module_index=$((choice - 1))
        if [[ $choice -ge 1 && $choice -le $max_modules ]]; then
          local selected_module="${CURRENT_MODULE_LIST[$module_index]}"
          execute_module "$selected_module"
          echo ""
          read -p "Press ENTER to continue..."
        else
          echo ""
          echo -e "\033[1;31m❌ Invalid module selection! Valid range: 1-$max_modules\033[0m"
          sleep 2
        fi
        ;;
      0)
        # Install all modules
        install_all_modules
        ;;
      R|r)
        # Reset status
        reset_status
        ;;
      S|s)
        # Show system info
        show_system_info
        ;;
      M|m)
        # Show detailed modules information
        debug_log "MENU" "User selected modules information view" "main_menu"
        show_modules_info
        ;;
      Q|q|QUIT|quit|EXIT|exit)
        # Quit
        show_banner
        echo -e "\033[1;32m👋 Thank you for using L4D2 Server Optimizer!\033[0m"
        echo ""
        exit 0
        ;;
      "")
        # Empty input - just redraw menu
        continue
        ;;
      *)
        echo ""
        echo -e "\033[1;31m❌ Invalid option '$choice'. Please try again.\033[0m"
        if [[ "$OPTIMIZER_DEBUG" == "1" ]]; then
          echo -e "\033[0;90m   Valid options: 1-$max_modules, 0, R, S, M, Q\033[0m"
        fi
        sleep 2
        ;;
    esac
  done
}

echo "🚀 Starting L4D2 Server Optimizer..."
debug_log "STARTUP" "L4D2 Server Optimizer starting..." "main"

# Check root user
if [[ $EUID -ne 0 ]]; then
  debug_log "STARTUP" "Script not running as root (EUID=$EUID)" "main"
  echo "❌ Must be run as root." && exit 1
fi

debug_log "STARTUP" "Root user check passed" "main"

# Detect and verify compatible operating system
debug_log "STARTUP" "Checking OS compatibility" "main"
if [[ -f /etc/os-release ]]; then
  source /etc/os-release
  debug_log "STARTUP" "Detected OS: $ID $VERSION_ID ($PRETTY_NAME)" "main"
  case "$ID,$VERSION_ID" in
    debian,11|debian,12|ubuntu,20.04|ubuntu,22.04|ubuntu,24.04)
      debug_log "STARTUP" "OS compatibility check passed" "main"
      echo "✅ Compatible system: $PRETTY_NAME" ;;
    *)
      debug_log "STARTUP" "OS compatibility check failed - unsupported OS" "main"
      echo "❌ Incompatible OS. Compatible with Debian 11/12, Ubuntu 20.04/22.04/24.04. Detected: $PRETTY_NAME"
      exit 1 ;;
  esac
else
  debug_log "STARTUP" "/etc/os-release not found" "main"
  echo "❌ /etc/os-release not found. Aborting." && exit 1
fi

# MODULE_DIR is now defined earlier after loading .env configuration
# Check modules directory existence
if [[ ! -d "$MODULE_DIR" ]]; then
  echo "❌ Modules directory not found: $MODULE_DIR" && exit 1
fi

# Create necessary configuration directories
debug_log "STARTUP" "Creating configuration directories" "main"
if ! create_directories; then
  debug_log "STARTUP" "Failed to create required directories" "main"
  echo "❌ Failed to create required directories" && exit 1
fi

# Clean debug log if it gets too large
clean_debug_log "${OPTIMIZER_DEBUG_LOG_MAX_LINES:-1000}"

# Discover and load modules dynamically
debug_log "STARTUP" "Starting module discovery" "main"
discover_modules

# Initialize status file
load_module_status

# Show main menu
main_menu