#!/bin/bash

#
# Redis Setup Script for Apache Traffic Server Cache Groups Plugin
# This script configures Redis to use unix domain socket for optimal performance
#

set -e

# Configuration
REDIS_CONF_FILE="/etc/redis/redis.conf"
REDIS_SOCKET_PATH="/var/run/redis/redis.sock"
REDIS_SOCKET_DIR="/var/run/redis"
REDIS_LOG_DIR="/var/log/redis"
ATS_USER="trafficserver"
REDIS_USER="redis"

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

install_redis() {
    log_info "Installing Redis server..."
    
    if command -v apt-get &> /dev/null; then
        # Ubuntu/Debian
        apt-get update
        apt-get install -y redis-server
    elif command -v yum &> /dev/null; then
        # CentOS/RHEL
        yum install -y redis
    elif command -v dnf &> /dev/null; then
        # Fedora
        dnf install -y redis
    else
        log_error "Unsupported package manager. Please install Redis manually."
        exit 1
    fi
}

setup_redis_directories() {
    log_info "Setting up Redis directories..."
    
    # Create socket directory
    mkdir -p "$REDIS_SOCKET_DIR"
    chown "$REDIS_USER:$REDIS_USER" "$REDIS_SOCKET_DIR"
    chmod 755 "$REDIS_SOCKET_DIR"
    
    # Set up log directory permissions
    if [ -d "$REDIS_LOG_DIR" ]; then
        chown "$REDIS_USER:$REDIS_USER" "$REDIS_LOG_DIR"
        chmod 755 "$REDIS_LOG_DIR"
    fi
}

configure_redis() {
    log_info "Configuring Redis for unix domain socket..."
    
    # Backup original config
    if [ -f "$REDIS_CONF_FILE" ]; then
        cp "$REDIS_CONF_FILE" "$REDIS_CONF_FILE.backup.$(date +%Y%m%d_%H%M%S)"
        log_info "Backed up original Redis config"
    fi
    
    # Configure Redis to use unix socket
    cat >> "$REDIS_CONF_FILE" << EOF

# Cache Groups Plugin Configuration
# Disable TCP port for security (unix socket only)
port 0

# Enable unix domain socket
unixsocket $REDIS_SOCKET_PATH
unixsocketperm 777

# Performance optimizations for cache groups
save 900 1
save 300 10
save 60 10000

# Memory management
maxmemory-policy allkeys-lru
maxmemory 256mb

# Logging
loglevel notice
logfile $REDIS_LOG_DIR/redis-server.log

# Persistence (optional - disable for pure cache)
# save ""
# appendonly no
EOF

    log_info "Redis configuration updated"
}

setup_permissions() {
    log_info "Setting up permissions for ATS access..."
    
    # Ensure ATS user can access Redis socket
    if id "$ATS_USER" &>/dev/null; then
        usermod -a -G "$REDIS_USER" "$ATS_USER"
        log_info "Added $ATS_USER to $REDIS_USER group"
    else
        log_warn "ATS user '$ATS_USER' not found. Please ensure ATS is installed."
    fi
}

start_redis() {
    log_info "Starting Redis server..."
    
    # Enable and start Redis service
    systemctl enable redis-server 2>/dev/null || systemctl enable redis 2>/dev/null || true
    systemctl restart redis-server 2>/dev/null || systemctl restart redis 2>/dev/null || true
    
    # Wait for Redis to start
    sleep 2
    
    # Test connection
    if [ -S "$REDIS_SOCKET_PATH" ]; then
        log_info "Redis is running and socket is available"
        
        # Test Redis connection
        if redis-cli -s "$REDIS_SOCKET_PATH" ping | grep -q PONG; then
            log_info "Redis connection test successful"
        else
            log_error "Redis connection test failed"
            exit 1
        fi
    else
        log_error "Redis socket not found at $REDIS_SOCKET_PATH"
        exit 1
    fi
}

install_redis_lua() {
    log_info "Installing redis-lua library..."
    
    # Check if redis-lua is already installed
    if lua -e "require('redis')" 2>/dev/null; then
        log_info "redis-lua is already installed"
        return
    fi
    
    # Install dependencies
    if command -v apt-get &> /dev/null; then
        apt-get install -y lua5.1 liblua5.1-dev wget build-essential
    elif command -v yum &> /dev/null; then
        yum install -y lua lua-devel wget gcc make
    elif command -v dnf &> /dev/null; then
        dnf install -y lua lua-devel wget gcc make
    fi
    
    # Download and install redis-lua
    cd /tmp
    wget https://github.com/nrk/redis-lua/archive/v2.0.4.tar.gz
    tar zxf v2.0.4.tar.gz
    
    # Install to system lua path
    mkdir -p /usr/local/share/lua/5.1
    cp redis-lua-2.0.4/src/redis.lua /usr/local/share/lua/5.1/
    
    # Cleanup
    rm -rf redis-lua-2.0.4 v2.0.4.tar.gz
    
    log_info "redis-lua library installed"
}

test_installation() {
    log_info "Testing Cache Groups Redis integration..."
    
    # Test basic Redis operations
    redis-cli -s "$REDIS_SOCKET_PATH" << EOF
SET test_key "hello_cache_groups"
GET test_key
HSET cg:example.com:test_group cache123 "http://example.com/page|$(date +%s)"
HGET cg:example.com:test_group cache123
HLEN cg:example.com:test_group
DEL cg:example.com:test_group
DEL test_key
EOF
    
    log_info "Redis operations test completed"
}

show_summary() {
    log_info "Redis setup completed successfully!"
    echo
    echo "Configuration Summary:"
    echo "- Redis socket: $REDIS_SOCKET_PATH"
    echo "- Redis config: $REDIS_CONF_FILE"
    echo "- Socket permissions: 777 (accessible by ATS)"
    echo "- TCP port: Disabled (unix socket only)"
    echo
    echo "Next steps:"
    echo "1. Update cache_groups.lua CONFIG.REDIS_SOCKET_PATH if needed"
    echo "2. Restart Apache Traffic Server"
    echo "3. Monitor Redis with: redis-cli -s $REDIS_SOCKET_PATH monitor"
    echo "4. Check Redis info with: redis-cli -s $REDIS_SOCKET_PATH info"
}

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  --install-only    Only install Redis, don't configure"
    echo "  --config-only     Only configure Redis (assumes already installed)"
    echo "  --test-only       Only run tests (assumes Redis is configured)"
    echo "  --help           Show this help message"
    echo
}

main() {
    local install_only=false
    local config_only=false
    local test_only=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --install-only)
                install_only=true
                shift
                ;;
            --config-only)
                config_only=true
                shift
                ;;
            --test-only)
                test_only=true
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
    
    log_info "Starting Redis setup for Cache Groups plugin..."
    
    check_root
    
    if [ "$test_only" = true ]; then
        test_installation
        exit 0
    fi
    
    if [ "$config_only" = false ]; then
        install_redis
        install_redis_lua
    fi
    
    if [ "$install_only" = false ]; then
        setup_redis_directories
        configure_redis
        setup_permissions
        start_redis
        test_installation
        show_summary
    fi
}

# Run main function
main "$@"