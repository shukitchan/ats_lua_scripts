#!/bin/bash

#
# Cache Groups Cleanup Runner Script
# 
# This script runs the cache groups cleanup utility with proper error handling,
# logging, and optional scheduling via cron.
#

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLEANUP_SCRIPT="$SCRIPT_DIR/cache_groups_cleanup.lua"
LOG_DIR="/var/log/cache_groups"
LOG_FILE="$LOG_DIR/cleanup.log"
LOCK_FILE="/var/run/cache_groups_cleanup.lock"
DEFAULT_MAX_AGE=3600  # 1 hour
DEFAULT_SOCKET_PATH="/var/run/redis/redis.sock"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S'): $1" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S'): $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S'): $1" | tee -a "$LOG_FILE"
}

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  --max-age SECONDS     Maximum age for cache entries (default: $DEFAULT_MAX_AGE)"
    echo "  --socket-path PATH    Redis unix socket path (default: $DEFAULT_SOCKET_PATH)"
    echo "  --dry-run             Show what would be cleaned without deleting"
    echo "  --verbose             Enable verbose logging"
    echo "  --no-lock             Skip lock file creation (use with caution)"
    echo "  --log-dir PATH        Log directory (default: $LOG_DIR)"
    echo "  --help                Show this help message"
    echo
    echo "Examples:"
    echo "  $0                                    # Run with defaults"
    echo "  $0 --max-age 7200 --verbose          # Clean entries older than 2 hours"
    echo "  $0 --dry-run                         # Preview what would be cleaned"
    echo "  $0 --socket-path /tmp/redis.sock     # Use custom Redis socket"
    echo
    echo "Cron examples:"
    echo "  # Run every hour"
    echo "  0 * * * * $0 >/dev/null 2>&1"
    echo "  # Run every 30 minutes with 2-hour retention"
    echo "  */30 * * * * $0 --max-age 7200 >/dev/null 2>&1"
}

check_prerequisites() {
    # Check if cleanup script exists
    if [ ! -f "$CLEANUP_SCRIPT" ]; then
        log_error "Cleanup script not found: $CLEANUP_SCRIPT"
        exit 1
    fi
    
    # Check if lua is available
    if ! command -v lua &> /dev/null; then
        log_error "Lua interpreter not found. Please install lua."
        exit 1
    fi
    
    # Check if redis-lua is available
    if ! lua -e "require('redis')" 2>/dev/null; then
        log_error "redis-lua library not found. Please install redis-lua."
        log_error "Run: sudo ./setup_redis.sh to install dependencies."
        exit 1
    fi
}

setup_logging() {
    # Create log directory if it doesn't exist
    if [ ! -d "$LOG_DIR" ]; then
        mkdir -p "$LOG_DIR"
        chmod 755 "$LOG_DIR"
    fi
    
    # Ensure log file exists and is writable
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"
}

acquire_lock() {
    if [ "$USE_LOCK" = "true" ]; then
        # Check if another instance is running
        if [ -f "$LOCK_FILE" ]; then
            local lock_pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
            if [ -n "$lock_pid" ] && kill -0 "$lock_pid" 2>/dev/null; then
                log_warn "Another cleanup process is already running (PID: $lock_pid)"
                exit 0
            else
                log_warn "Stale lock file found, removing it"
                rm -f "$LOCK_FILE"
            fi
        fi
        
        # Create lock file
        echo $$ > "$LOCK_FILE"
        
        # Set up trap to remove lock file on exit
        trap 'rm -f "$LOCK_FILE"' EXIT
    fi
}

run_cleanup() {
    log_info "Starting cache groups cleanup"
    log_info "Max age: ${MAX_AGE} seconds"
    log_info "Redis socket: ${SOCKET_PATH}"
    log_info "Dry run: ${DRY_RUN}"
    log_info "Verbose: ${VERBOSE}"
    
    # Build command arguments
    local cmd_args=()
    cmd_args+=("--socket-path" "$SOCKET_PATH")
    cmd_args+=("--max-age" "$MAX_AGE")
    
    if [ "$DRY_RUN" = "true" ]; then
        cmd_args+=("--dry-run")
    fi
    
    if [ "$VERBOSE" = "true" ]; then
        cmd_args+=("--verbose")
    fi
    
    # Run the cleanup script
    local start_time=$(date +%s)
    
    if lua "$CLEANUP_SCRIPT" "${cmd_args[@]}" 2>&1 | tee -a "$LOG_FILE"; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_info "Cleanup completed successfully in ${duration} seconds"
        return 0
    else
        local exit_code=$?
        log_error "Cleanup failed with exit code: $exit_code"
        return $exit_code
    fi
}

# Parse command line arguments
MAX_AGE="$DEFAULT_MAX_AGE"
SOCKET_PATH="$DEFAULT_SOCKET_PATH"
DRY_RUN="false"
VERBOSE="false"
USE_LOCK="true"

while [[ $# -gt 0 ]]; do
    case $1 in
        --max-age)
            MAX_AGE="$2"
            shift 2
            ;;
        --socket-path)
            SOCKET_PATH="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN="true"
            shift
            ;;
        --verbose)
            VERBOSE="true"
            shift
            ;;
        --no-lock)
            USE_LOCK="false"
            shift
            ;;
        --log-dir)
            LOG_DIR="$2"
            LOG_FILE="$LOG_DIR/cleanup.log"
            shift 2
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate arguments
if ! [[ "$MAX_AGE" =~ ^[0-9]+$ ]] || [ "$MAX_AGE" -le 0 ]; then
    log_error "Invalid max-age value: $MAX_AGE (must be a positive integer)"
    exit 1
fi

# Main execution
main() {
    setup_logging
    check_prerequisites
    acquire_lock
    run_cleanup
}

# Run main function
main "$@"