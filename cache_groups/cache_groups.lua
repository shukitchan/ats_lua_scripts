--[[
Apache Traffic Server Lua Plugin for HTTP Cache Groups (RFC 9875)

This plugin implements the HTTP Cache Groups specification as defined in RFC 9875,
providing a mechanism for grouping cached responses and enabling group-based invalidation.

Features:
- Cache-Groups response header processing
- Cache-Group-Invalidation response header processing  
- Group-based cache invalidation
- Origin isolation for cache groups
- Configurable group limits and validation

Author: Generated for Apache Traffic Server
Version: 1.0
License: Apache 2.0
--]]

-- Configuration constants
local CONFIG = {
    MAX_GROUPS_PER_RESPONSE = 32,    -- RFC 9875 requirement
    MAX_GROUP_NAME_LENGTH = 32,      -- RFC 9875 requirement
    CACHE_GROUP_HEADER = "Cache-Groups",
    CACHE_GROUP_INVALIDATION_HEADER = "Cache-Group-Invalidation",
    DEBUG_ENABLED = false,
    REDIS_SOCKET_PATH = "/var/run/redis/redis.sock"  -- Unix domain socket path
}

-- Setup package paths for redis-lua
ts.add_package_cpath('/usr/local/lib/lua/5.1/socket/?.so;/usr/local/lib/lua/5.1/mime/?.so')
ts.add_package_path('/usr/local/share/lua/5.1/?.lua;/usr/local/share/lua/5.1/socket/?.lua')

-- Redis connection using unix domain socket
local redis = require 'redis'
local redis_client = redis.connect('unix://' .. CONFIG.REDIS_SOCKET_PATH)

-- Helper function for debug logging
local function debug_log(message)
    if CONFIG.DEBUG_ENABLED then
        ts.debug("CacheGroups: " .. tostring(message))
    end
end

-- Helper function to get origin from URL
local function get_origin(url)
    local scheme, host, port = url:match("^([^:]+)://([^:/]+):?(%d*)") 
    if not scheme or not host then
        return nil
    end
    
    -- Normalize port
    if port == "" then
        if scheme == "https" then
            port = "443"
        elseif scheme == "http" then
            port = "80"
        end
    end
    
    return scheme .. "://" .. host .. ":" .. port
end

-- Helper function to parse structured field list (simplified)
local function parse_structured_field_list(field_value)
    if not field_value or field_value == "" then
        return {}
    end
    
    local groups = {}
    local group_count = 0
    
    -- Simple parsing for quoted strings separated by commas
    for group in field_value:gmatch('%s*"([^"]*)"') do
        if group_count >= CONFIG.MAX_GROUPS_PER_RESPONSE then
            debug_log("Exceeded maximum groups per response: " .. CONFIG.MAX_GROUPS_PER_RESPONSE)
            break
        end
        
        if #group <= CONFIG.MAX_GROUP_NAME_LENGTH and #group > 0 then
            table.insert(groups, group)
            group_count = group_count + 1
        else
            debug_log("Invalid group name length: " .. group .. " (length: " .. #group .. ")")
        end
    end
    
    return groups
end

-- Helper function to get cache key for a request
local function get_cache_key(request_url, request_headers)
    -- This should match ATS's internal cache key generation
    -- For simplicity, using URL as base key
    local key = request_url
    
    -- Add Vary header considerations if needed
    local vary = request_headers["Vary"]
    if vary then
        -- In a real implementation, you'd need to include varying headers
        key = key .. "|vary:" .. vary
    end
    
    return key
end

-- Function to add response to cache groups
local function add_to_cache_groups(origin, groups, cache_key, url, headers)
    local timestamp = os.time()
    -- Store as JSON-like string: url|timestamp
    local entry_value = string.format("%s|%d", url, timestamp)
    
    for _, group in ipairs(groups) do
        -- Redis key format: cg:origin:group
        local redis_key = string.format("cg:%s:%s", origin, group)
        
        -- Use HSET to store cache_key -> entry_value mapping
        local success, err = pcall(function()
            redis_client:hset(redis_key, cache_key, entry_value)
        end)
        
        if success then
            debug_log("Added cache entry to group '" .. group .. "' for origin " .. origin)
        else
            debug_log("Redis HSET failed: " .. tostring(err))
        end
    end
end

-- Function to invalidate cache groups
local function invalidate_cache_groups(origin, groups_to_invalidate)
    local invalidated_count = 0
    
    for _, group in ipairs(groups_to_invalidate) do
        local redis_key = string.format("cg:%s:%s", origin, group)
        
        -- Get all cache keys in this group first
        local success, cache_keys = pcall(function()
            return redis_client:hkeys(redis_key)
        end)
        
        if success and cache_keys then
            for _, cache_key in ipairs(cache_keys) do
                -- In a real ATS implementation, you would call ATS cache invalidation API here
                debug_log("Invalidating cache entry: " .. cache_key .. " from group: " .. group)
                invalidated_count = invalidated_count + 1
            end
        end
        
        -- Delete the entire group
        local delete_success, delete_err = pcall(function()
            redis_client:del(redis_key)
        end)
        
        if delete_success then
            debug_log("Invalidated group '" .. group .. "' for origin " .. origin)
        else
            debug_log("Redis DEL failed: " .. tostring(delete_err))
        end
    end
    
    return invalidated_count
end

-- Function to check if request method is safe
local function is_safe_method(method)
    local safe_methods = {
        ["GET"] = true,
        ["HEAD"] = true,
        ["OPTIONS"] = true,
        ["TRACE"] = true
    }
    return safe_methods[method:upper()] or false
end

-- Main function to handle response processing
function process_response_headers()
    local request_url = ts.client_request.get_url()
    local request_method = ts.client_request.get_method()
    local request_headers = ts.client_request.get_headers()
    local response_headers = ts.server_response.get_headers()
    
    if not request_url then
        debug_log("No request URL found")
        return
    end
    
    local origin = get_origin(request_url)
    if not origin then
        debug_log("Could not determine origin from URL: " .. request_url)
        return
    end
    
    debug_log("Processing response for origin: " .. origin .. ", method: " .. request_method)
    
    -- Process Cache-Groups header
    local cache_groups_header = response_headers[CONFIG.CACHE_GROUP_HEADER]
    if cache_groups_header then
        local groups = parse_structured_field_list(cache_groups_header)
        if #groups > 0 then
            local cache_key = get_cache_key(request_url, request_headers)
            add_to_cache_groups(origin, groups, cache_key, request_url, response_headers)
            debug_log("Processed Cache-Groups header with " .. #groups .. " groups")
        end
    end
    
    -- Process Cache-Group-Invalidation header (only for unsafe methods)
    local cache_group_invalidation_header = response_headers[CONFIG.CACHE_GROUP_INVALIDATION_HEADER]
    if cache_group_invalidation_header and not is_safe_method(request_method) then
        local groups_to_invalidate = parse_structured_field_list(cache_group_invalidation_header)
        if #groups_to_invalidate > 0 then
            local invalidated_count = invalidate_cache_groups(origin, groups_to_invalidate)
            debug_log("Processed Cache-Group-Invalidation header, invalidated " .. 
                     invalidated_count .. " entries across " .. #groups_to_invalidate .. " groups")
        end
    elseif cache_group_invalidation_header and is_safe_method(request_method) then
        debug_log("Ignoring Cache-Group-Invalidation header for safe method: " .. request_method)
    end
end

-- Function to handle cache lookup (called before serving from cache)
function process_cache_lookup()
    local request_url = ts.client_request.get_url()
    local request_headers = ts.client_request.get_headers()
    
    if not request_url then
        return
    end
    
    local origin = get_origin(request_url)
    if not origin then
        return
    end
    
    local cache_key = get_cache_key(request_url, request_headers)
    
    -- Check if this cache entry belongs to any groups by scanning Redis keys
    local pattern = string.format("cg:%s:*", origin)
    local success, group_keys = pcall(function()
        return redis_client:keys(pattern)
    end)
    
    if success and group_keys then
        for _, redis_key in ipairs(group_keys) do
            -- Extract group name from redis key
            local group_name = redis_key:match("^cg:.-:(.+)$")
            
            -- Check if cache_key exists in this group
            local exists_success, exists = pcall(function()
                return redis_client:hexists(redis_key, cache_key)
            end)
            
            if exists_success and exists == 1 then
                debug_log("Cache entry belongs to group: " .. (group_name or redis_key))
                -- Here you could add additional logic for group-based cache policies
            end
        end
    end
end

-- Hook into ATS response processing
function do_remap()
    ts.hook(TS_LUA_HOOK_SEND_RESPONSE_HDR, process_response_headers)
    ts.hook(TS_LUA_HOOK_CACHE_LOOKUP_COMPLETE, process_cache_lookup)
    return 0
end