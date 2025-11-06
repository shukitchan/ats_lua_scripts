# Apache Traffic Server Cache Groups Plugin

A Lua plugin for Apache Traffic Server that implements HTTP Cache Groups as specified in [RFC 9875](https://datatracker.ietf.org/doc/rfc9875/).

## Overview

This plugin provides a mechanism for grouping cached HTTP responses and enabling group-based cache invalidation. It implements the `Cache-Groups` and `Cache-Group-Invalidation` response headers defined in RFC 9875.

### Key Features

- **Cache Grouping**: Associate cached responses with named groups using the `Cache-Groups` header
- **Group Invalidation**: Invalidate all responses in specified groups using the `Cache-Group-Invalidation` header
- **Origin Isolation**: Cache groups are scoped to individual origins for security
- **RFC 9875 Compliance**: Full implementation of the HTTP Cache Groups specification
- **Performance Optimized**: Efficient group tracking and cleanup mechanisms
- **Configurable**: Customizable limits and behavior options

## Installation

### Prerequisites

- Apache Traffic Server 8.0+ with Lua plugin support
- Lua 5.1+ environment
- Redis server with unix domain socket support
- redis-lua library (v2.0.4+)

### Setup

1. **Setup Redis with unix domain socket:**
   ```bash
   sudo ./setup_redis.sh
   ```
   This script will:
   - Install Redis server
   - Configure Redis to use unix domain socket at `/var/run/redis/redis.sock`
   - Install redis-lua library
   - Set proper permissions for ATS access
   - Test the Redis connection

2. **Copy the plugin files:**
   ```bash
   sudo cp cache_groups.lua /opt/trafficserver/etc/trafficserver/lua/
   sudo chown trafficserver:trafficserver /opt/trafficserver/etc/trafficserver/lua/cache_groups.lua
   ```

3. **Setup cleanup task:**
   ```bash
   # Copy cleanup files to a suitable location
   sudo mkdir -p /opt/cache_groups
   sudo cp cache_groups_cleanup.lua run_cleanup.sh /opt/cache_groups/
   sudo chmod +x /opt/cache_groups/cache_groups_cleanup.lua
   sudo chmod +x /opt/cache_groups/run_cleanup.sh
   
   # Setup cron job for cleanup (run every hour)
   echo "0 * * * * root /opt/cache_groups/run_cleanup.sh >/dev/null 2>&1" | sudo tee /etc/cron.d/cache-groups-cleanup
   ```

4. **Update remap.config:**
   ```
   # For specific domains
   map http://example.com/ http://backend.example.com/ @plugin=lua.so @pparam=/opt/trafficserver/etc/trafficserver/lua/cache_groups.lua
   
   # For all traffic
   map / @plugin=lua.so @pparam=/opt/trafficserver/etc/trafficserver/lua/cache_groups.lua
   ```

5. **Reload ATS configuration:**
   ```bash
   sudo traffic_ctl config reload
   ```

## Usage

### Cache-Groups Header

Add the `Cache-Groups` header to HTTP responses to associate them with one or more cache groups:

```http
HTTP/1.1 200 OK
Content-Type: application/json
Cache-Control: max-age=3600
Cache-Groups: "api-v1", "user-data", "analytics"

{"userId": 123, "userData": {...}}
```

### Cache-Group-Invalidation Header

Add the `Cache-Group-Invalidation` header to responses from unsafe HTTP methods (POST, PUT, DELETE, etc.) to invalidate cache groups:

```http
POST /api/users/123 HTTP/1.1
...

HTTP/1.1 200 OK
Content-Type: text/html
Cache-Group-Invalidation: "user-data", "user-sessions"

Success: User updated
```

### Example Scenarios

#### 1. E-commerce Product Catalog

```http
# Product page response
Cache-Groups: "products", "category-electronics", "brand-apple"

# After product update
Cache-Group-Invalidation: "products", "category-electronics"
```

#### 2. User Profile System

```http
# User profile response
Cache-Groups: "user-123", "user-profiles", "api-v2"

# After profile update
Cache-Group-Invalidation: "user-123", "user-profiles"
```

#### 3. Content Management System

```http
# Article response
Cache-Groups: "articles", "author-456", "category-tech"

# After content publish
Cache-Group-Invalidation: "articles", "homepage", "feeds"
```

## Configuration

All configuration is now embedded directly in the `cache_groups.lua` script. You can modify the `CONFIG` table at the top of the script to customize behavior:

```lua
local CONFIG = {
    MAX_GROUPS_PER_RESPONSE = 32,    -- RFC 9875 requirement
    MAX_GROUP_NAME_LENGTH = 32,      -- RFC 9875 requirement
    CACHE_GROUP_HEADER = "Cache-Groups",
    CACHE_GROUP_INVALIDATION_HEADER = "Cache-Group-Invalidation",
    DEBUG_ENABLED = false,
    REDIS_SOCKET_PATH = "/var/run/redis/redis.sock"  -- Unix domain socket path
}
```

### ATS Configuration

Enable debug logging in `records.config` to see cache group activity:

```
CONFIG proxy.config.diags.debug.enabled INT 1
CONFIG proxy.config.diags.debug.tags STRING lua
```

## RFC 9875 Compliance

This implementation follows RFC 9875 specifications:

- ✅ **Cache-Groups Header**: Structured field list of strings
- ✅ **Cache-Group-Invalidation Header**: Structured field list of strings
- ✅ **Origin Isolation**: Groups are scoped per origin
- ✅ **Safe Method Restriction**: Invalidation only processed for unsafe methods
- ✅ **Minimum Limits**: Supports 32+ groups with 32+ character names
- ✅ **Case Sensitivity**: Group names are compared case-sensitively
- ✅ **Group Membership**: Responses belong to groups when headers match exactly

## API Reference

### Headers

#### Cache-Groups
```
Cache-Groups: "group1", "group2", "group3"
```
- **Type**: Response header
- **Format**: Structured field list of quoted strings
- **Purpose**: Associates response with cache groups
- **Limits**: Max 32 groups, 32 characters per group name

#### Cache-Group-Invalidation
```
Cache-Group-Invalidation: "group1", "group2"
```
- **Type**: Response header
- **Format**: Structured field list of quoted strings
- **Purpose**: Invalidates specified cache groups
- **Restriction**: Only processed for unsafe HTTP methods
- **Limits**: Max 32 groups, 32 characters per group name

## Redis Backend

This plugin uses Redis as the backend storage for cache group data, providing:

### Benefits of Redis Backend
- **Persistence**: Cache group data survives ATS restarts
- **Scalability**: Multiple ATS instances can share cache group information
- **Performance**: Redis unix domain socket provides high-performance access
- **Memory Management**: Redis handles memory allocation and cleanup efficiently

### Redis Configuration
The plugin connects to Redis via unix domain socket for optimal performance:

```lua
-- Redis connection using unix domain socket
REDIS_SOCKET_PATH = "/var/run/redis/redis.sock"
```

### Data Structure in Redis
Cache groups are stored using the following Redis key patterns:

```
cg:{origin}:{group_name} -> HASH
  {cache_key} -> "{url}|{timestamp}"
```

Example:
```
cg:https://example.com:80:api-v1 -> HASH
  "http://example.com/api/users/123" -> "http://example.com/api/users/123|1699123456"
```

## Cache Cleanup

Cache group entries are automatically cleaned up by a separate process to remove expired entries and prevent Redis memory growth.

### Cleanup Utility

The cleanup is handled by two files:
- `cache_groups_cleanup.lua` - Lua script that performs the actual cleanup
- `run_cleanup.sh` - Shell wrapper with logging and error handling

### Manual Cleanup

Run cleanup manually:

```bash
# Basic cleanup (remove entries older than 1 hour)
/opt/cache_groups/run_cleanup.sh

# Dry run to see what would be cleaned
/opt/cache_groups/run_cleanup.sh --dry-run

# Custom retention (2 hours) with verbose output
/opt/cache_groups/run_cleanup.sh --max-age 7200 --verbose

# Use custom Redis socket
/opt/cache_groups/run_cleanup.sh --socket-path /tmp/redis.sock
```

### Automated Cleanup

Setup cron job for regular cleanup:

```bash
# Run every hour (recommended)
0 * * * * root /opt/cache_groups/run_cleanup.sh >/dev/null 2>&1

# Run every 30 minutes with 2-hour retention
*/30 * * * * root /opt/cache_groups/run_cleanup.sh --max-age 7200 >/dev/null 2>&1
```

### Redis Commands Used
- `HSET`: Add cache entry to group
- `HGET`/`HGETALL`: Retrieve cache entries
- `HKEYS`: List all cache keys in a group
- `HEXISTS`: Check if cache entry exists in group
- `HDEL`: Remove cache entry from group
- `DEL`: Remove entire cache group
- `KEYS`: Find cache groups (used for cleanup and stats)
- `HLEN`: Count entries in a group

### Redis Monitoring
Monitor cache group activity:

```bash
# Monitor all Redis commands
redis-cli -s /var/run/redis/redis.sock monitor

# Check cache group statistics
redis-cli -s /var/run/redis/redis.sock
> KEYS cg:*
> HGETALL cg:https://example.com:80:api-v1
```

## Performance Considerations

### Memory Usage
- Redis handles cache group membership storage
- Automatic cleanup removes expired entries
- Configurable limits prevent unbounded growth

### Cache Efficiency
- Group invalidation is more efficient than individual entry invalidation
- Origin isolation prevents cross-contamination
- Minimal overhead on cache lookup operations

### Scalability
- Designed for high-traffic environments
- Efficient data structures for group operations
- Configurable cleanup intervals

## Troubleshooting

### Common Issues

1. **Headers not processed**
   - Verify plugin is loaded in remap.config
   - Check ATS error logs for Lua errors
   - Ensure proper header format (quoted strings)

2. **Groups not invalidating**
   - Confirm Cache-Group-Invalidation is on unsafe methods only
   - Verify group names match exactly (case-sensitive)
   - Check origin isolation (groups are per-origin)

3. **Memory growth**
   - Increase cleanup frequency
   - Reduce max_tracking_age
   - Monitor cache group statistics

### Debug Mode

Enable debug logging by setting `DEBUG_ENABLED = true` in the CONFIG table:

```lua
local CONFIG = {
    -- ... other settings ...
    DEBUG_ENABLED = true,
    -- ... rest of config ...
}
```

Then check ATS logs for detailed cache group activity:

```bash
tail -f /opt/trafficserver/var/log/trafficserver/diags.log | grep CacheGroups
```

## Security Considerations

### Origin Isolation
Cache groups are isolated per origin to prevent:
- Cross-origin cache pollution
- Unauthorized cache invalidation
- Information leakage between origins

### Shared Hosting
In shared hosting environments:
- Different tenants cannot affect each other's cache groups
- Group names are opaque to prevent information disclosure
- Access control should be implemented at the application layer

## Contributing

### Development Setup

1. Clone the repository
2. Make changes to cache_groups.lua
3. Update documentation as needed

### Code Style
- Follow Lua best practices
- Use descriptive variable names
- Include comprehensive comments
- Maintain RFC 9875 compliance

## License

Apache License 2.0 - See LICENSE file for details.

## References

- [RFC 9875: HTTP Cache Groups](https://datatracker.ietf.org/doc/rfc9875/)
- [Apache Traffic Server Documentation](https://docs.trafficserver.apache.org/)
- [ATS Lua Plugin Guide](https://docs.trafficserver.apache.org/en/latest/admin-guide/plugins/lua.en.html)

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review ATS logs with debug enabled  
3. Verify RFC 9875 compliance
4. Monitor Redis operations with `redis-cli -s /var/run/redis/redis.sock monitor`