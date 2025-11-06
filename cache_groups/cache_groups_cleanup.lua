#!/usr/bin/env lua

--[[
Cache Groups Cleanup Utility

This script cleans up expired cache group entries from Redis.
It's designed to be run as a separate process, typically via cron job.

Usage:
  lua cache_groups_cleanup.lua [options]

Options:
  --socket-path PATH    Redis unix socket path (default: /var/run/redis/redis.sock)
  --max-age SECONDS     Maximum age for entries in seconds (default: 3600)
  --dry-run             Show what would be cleaned up without actually deleting
  --verbose             Enable verbose logging
  --help                Show this help message

Author: Generated for Apache Traffic Server Cache Groups
Version: 1.0
License: Apache 2.0
--]]

-- Configuration
local config = {
    redis_socket_path = "/var/run/redis/redis.sock",
    max_age = 3600,  -- 1 hour
    dry_run = false,
    verbose = false
}

-- Parse command line arguments
local function parse_args(args)
    local i = 1
    while i <= #args do
        local arg = args[i]
        
        if arg == "--socket-path" then
            i = i + 1
            if i <= #args then
                config.redis_socket_path = args[i]
            else
                error("--socket-path requires a path argument")
            end
        elseif arg == "--max-age" then
            i = i + 1
            if i <= #args then
                config.max_age = tonumber(args[i])
                if not config.max_age then
                    error("--max-age requires a numeric argument")
                end
            else
                error("--max-age requires a numeric argument")
            end
        elseif arg == "--dry-run" then
            config.dry_run = true
        elseif arg == "--verbose" then
            config.verbose = true
        elseif arg == "--help" then
            print([[
Cache Groups Cleanup Utility

Usage:
  lua cache_groups_cleanup.lua [options]

Options:
  --socket-path PATH    Redis unix socket path (default: /var/run/redis/redis.sock)
  --max-age SECONDS     Maximum age for entries in seconds (default: 3600)
  --dry-run             Show what would be cleaned up without actually deleting
  --verbose             Enable verbose logging
  --help                Show this help message

Examples:
  lua cache_groups_cleanup.lua --max-age 7200 --verbose
  lua cache_groups_cleanup.lua --dry-run --socket-path /tmp/redis.sock
]])
            os.exit(0)
        else
            error("Unknown argument: " .. arg)
        end
        
        i = i + 1
    end
end

-- Logging functions
local function log_info(message)
    print(string.format("[INFO] %s: %s", os.date("%Y-%m-%d %H:%M:%S"), message))
end

local function log_verbose(message)
    if config.verbose then
        print(string.format("[VERBOSE] %s: %s", os.date("%Y-%m-%d %H:%M:%S"), message))
    end
end

local function log_error(message)
    io.stderr:write(string.format("[ERROR] %s: %s\n", os.date("%Y-%m-%d %H:%M:%S"), message))
end

-- Setup Redis connection
local function setup_redis()
    -- Try to load redis-lua
    local redis_ok, redis = pcall(require, 'redis')
    if not redis_ok then
        log_error("Failed to load redis-lua library. Please install redis-lua.")
        log_error("Install with: sudo cp redis-lua-2.0.4/src/redis.lua /usr/local/share/lua/5.1/")
        os.exit(1)
    end
    
    -- Connect to Redis
    local client_ok, redis_client = pcall(function()
        return redis.connect('unix://' .. config.redis_socket_path)
    end)
    
    if not client_ok or not redis_client then
        log_error("Failed to connect to Redis at " .. config.redis_socket_path)
        log_error("Make sure Redis is running and the socket path is correct.")
        os.exit(1)
    end
    
    -- Test connection
    local ping_ok, ping_result = pcall(function()
        return redis_client:ping()
    end)
    
    if not ping_ok or ping_result ~= "PONG" then
        log_error("Redis connection test failed")
        os.exit(1)
    end
    
    log_verbose("Connected to Redis at " .. config.redis_socket_path)
    return redis_client
end

-- Cleanup expired entries
local function cleanup_expired_entries(redis_client)
    local current_time = os.time()
    local cleanup_threshold = config.max_age
    local total_cleaned = 0
    local total_checked = 0
    
    log_info(string.format("Starting cleanup with max age %d seconds", cleanup_threshold))
    if config.dry_run then
        log_info("DRY RUN mode - no actual deletions will be performed")
    end
    
    -- Get all cache group keys
    local success, all_keys = pcall(function()
        return redis_client:keys("cg:*:*")
    end)
    
    if not success or not all_keys then
        log_error("Failed to get cache group keys from Redis")
        return 1
    end
    
    log_info(string.format("Found %d cache groups to check", #all_keys))
    
    for _, redis_key in ipairs(all_keys) do
        log_verbose("Checking group: " .. redis_key)
        
        local group_success, all_entries = pcall(function()
            return redis_client:hgetall(redis_key)
        end)
        
        if group_success and all_entries then
            -- Redis HGETALL returns array with alternating keys and values
            for i = 1, #all_entries, 2 do
                local cache_key = all_entries[i]
                local entry_value = all_entries[i + 1]
                total_checked = total_checked + 1
                
                -- Parse entry_value to get timestamp: url|timestamp
                local url, timestamp_str = entry_value:match("^(.-)|(%d+)$")
                local timestamp = tonumber(timestamp_str)
                
                if timestamp then
                    local age = current_time - timestamp
                    log_verbose(string.format("Entry %s age: %d seconds", cache_key, age))
                    
                    if age > cleanup_threshold then
                        if config.dry_run then
                            log_info(string.format("Would clean up expired entry: %s (age: %d seconds)", cache_key, age))
                        else
                            local delete_success, delete_err = pcall(function()
                                redis_client:hdel(redis_key, cache_key)
                            end)
                            
                            if delete_success then
                                log_verbose(string.format("Cleaned up expired entry: %s (age: %d seconds)", cache_key, age))
                            else
                                log_error(string.format("Failed to delete %s: %s", cache_key, tostring(delete_err)))
                            end
                        end
                        total_cleaned = total_cleaned + 1
                    end
                else
                    log_error(string.format("Invalid timestamp in entry: %s", entry_value))
                end
            end
            
            -- Check if group is now empty and remove it
            if not config.dry_run then
                local count_success, entry_count = pcall(function()
                    return redis_client:hlen(redis_key)
                end)
                
                if count_success and entry_count == 0 then
                    redis_client:del(redis_key)
                    log_verbose("Removed empty group: " .. redis_key)
                end
            end
        else
            log_error("Failed to get entries for group: " .. redis_key)
        end
    end
    
    local action = config.dry_run and "would be cleaned" or "cleaned"
    log_info(string.format("Cleanup complete: %d entries %s out of %d checked", total_cleaned, action, total_checked))
    
    return 0
end

-- Main function
local function main()
    -- Parse command line arguments
    local args = {...}
    local parse_ok, parse_err = pcall(parse_args, args)
    if not parse_ok then
        log_error("Argument parsing failed: " .. parse_err)
        os.exit(1)
    end
    
    -- Setup Redis connection
    local redis_client = setup_redis()
    
    -- Run cleanup
    local exit_code = cleanup_expired_entries(redis_client)
    
    -- Close Redis connection
    pcall(function() redis_client:quit() end)
    
    os.exit(exit_code)
end

-- Run main function if this script is executed directly
if arg and arg[0] then
    main()
else
    -- Return functions for require() usage
    return {
        cleanup_expired_entries = cleanup_expired_entries,
        setup_redis = setup_redis,
        config = config
    }
end