#!/bin/bash

#
# Apache Traffic Server Cache Groups Plugin Deployment Script
# This script helps deploy the Cache Groups plugin to your ATS installation
#

set -e

# Configuration
ATS_CONFIG_DIR="/opt/trafficserver/etc/trafficserver"
ATS_LUA_DIR="$ATS_CONFIG_DIR/lua"
ATS_USER="trafficserver"
ATS_GROUP="trafficserver"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

check_ats_installation() {
    if ! command -v traffic_server &> /dev/null; then
        log_error "Apache Traffic Server not found. Please install ATS first."
        exit 1
    fi
    
    if [ ! -d "$ATS_CONFIG_DIR" ]; then
        log_error "ATS configuration directory not found: $ATS_CONFIG_DIR"
        exit 1
    fi
    
    log_info "Found ATS installation at $ATS_CONFIG_DIR"
}

create_lua_directory() {
    if [ ! -d "$ATS_LUA_DIR" ]; then
        log_info "Creating Lua directory: $ATS_LUA_DIR"
        mkdir -p "$ATS_LUA_DIR"
        chown "$ATS_USER:$ATS_GROUP" "$ATS_LUA_DIR"
    fi
}

install_plugin() {
    log_info "Installing Cache Groups plugin..."
    
    # Copy main plugin file
    if [ -f "cache_groups.lua" ]; then
        cp cache_groups.lua "$ATS_LUA_DIR/"
        chown "$ATS_USER:$ATS_GROUP" "$ATS_LUA_DIR/cache_groups.lua"
        chmod 644 "$ATS_LUA_DIR/cache_groups.lua"
        log_info "Installed cache_groups.lua"
    else
        log_error "cache_groups.lua not found in current directory"
        exit 1
    fi
}
}

backup_remap_config() {
    if [ -f "$ATS_CONFIG_DIR/remap.config" ]; then
        cp "$ATS_CONFIG_DIR/remap.config" "$ATS_CONFIG_DIR/remap.config.backup.$(date +%Y%m%d_%H%M%S)"
        log_info "Backed up existing remap.config"
    fi
}

show_remap_example() {
    log_info "Add the following to your remap.config to enable Cache Groups:"
    echo
    echo "# Enable Cache Groups for specific domain"
    echo "map http://example.com/ http://backend.example.com/ \\"
    echo "  @plugin=lua.so @pparam=$ATS_LUA_DIR/cache_groups.lua"
    echo
    echo "# Or enable globally for all traffic"
    echo "map / @plugin=lua.so @pparam=$ATS_LUA_DIR/cache_groups.lua"
    echo
}

check_lua_plugin() {
    if ! find /opt/trafficserver -name "lua.so" 2>/dev/null | grep -q .; then
        log_warn "lua.so plugin not found. Make sure ATS was compiled with Lua support."
        log_warn "You may need to install the trafficserver-experimental-plugins package."
    else
        log_info "Found Lua plugin support"
    fi
}

test_installation() {
    log_info "Verifying plugin installation..."
    
    if [ -f "$ATS_LUA_DIR/cache_groups.lua" ]; then
        log_info "Plugin file installed successfully"
    else
        log_error "Plugin file not found at $ATS_LUA_DIR/cache_groups.lua"
        return 1
    fi
}

reload_ats() {
    log_info "Reloading ATS configuration..."
    
    if command -v traffic_ctl &> /dev/null; then
        if traffic_ctl config reload; then
            log_info "ATS configuration reloaded successfully"
        else
            log_error "Failed to reload ATS configuration"
            log_error "You may need to restart ATS manually"
        fi
    else
        log_warn "traffic_ctl not found, please reload ATS configuration manually"
    fi
}

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  --check-only    Only check prerequisites, don't install"
    echo "  --no-reload     Don't reload ATS after installation"
    echo "  --help          Show this help message"
    echo
}

main() {
    local check_only=false
    local no_reload=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --check-only)
                check_only=true
                shift
                ;;
            --no-reload)
                no_reload=true
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    log_info "Starting Cache Groups plugin deployment..."
    
    # Prerequisites
    check_root
    check_ats_installation
    check_lua_plugin
    
    if [ "$check_only" = true ]; then
        log_info "Prerequisites check completed successfully"
        exit 0
    fi
    
    # Installation
    create_lua_directory
    backup_remap_config
    install_plugin
    test_installation
    
    # Configuration
    show_remap_example
    
    # Reload ATS
    if [ "$no_reload" = false ]; then
        reload_ats
    fi
    
    log_info "Cache Groups plugin deployment completed!"
    log_info "Don't forget to update your remap.config to enable the plugin."
}

# Run main function
main "$@"