-- this script makes cache invalidation by cache tag possible
-- 1. The origin needs to associate the response with mutiple cache tags through the X-Cache-Tags response header (e.g. X-Cache-Tags: a,b,c)
-- 2. You can send in a BAN (i.e. method is "BAN") request with X-Cache-Tags (e.g. X-Cache-Tags: a,b) request header to invalidate the cache entry with those tags

-- Internally we use a counter (from the ATS Statistics API) for each tag
-- Each cache entry will have all counter values for its tags recorded in cached respone header
-- a BAN request with X-Cache-Tags header will trigger the counter to increment
-- A cache lookup will result in a miss if the counter value is larger than that recorded in the cached respone header
-- All X-Cache-Tags headers are removed from the response sent to the user. 

function do_global_read_request()
  ts.debug("global read request hook")

  -- accept a BAN request with cache tags and increment the corresponding counters
  local method = ts.client_request.get_method() or ''
  ts.debug('method: '..method)

  if (method == 'BAN') then
    local cache_tags = ts.client_request.header['X-Cache-Tags'] or ''
    local delimiter = ','
    for match in (cache_tags..delimiter):gmatch("(.-)"..delimiter) do
      ts.debug("cache_tag: "..match)
      local stat = ts.stat_find(match)
      if(stat ~= nil) then
        ts.debug("incrementing counter for cache tag")
        stat:increment(1)
      end
    end
    ts.http.set_resp(200, "Done")
  end
end

function do_global_send_response()
  ts.debug("global send response hook")

  -- remove all cache tag headers
  local cache_tags = ts.client_response.header['X-Cache-Tags'] or ''
  local delimiter = ','
  for match in (cache_tags..delimiter):gmatch("(.-)"..delimiter) do
    ts.debug("cache_tag: "..match)
    ts.client_response.header['X-Cache-Tag-'..match] = nil
  end
  ts.client_response.header['X-Cache-Tags'] = nil
end

function do_global_read_response()
  ts.debug("global read response hook")

  -- find out the cache tags response header and create response header for each tag and assign them the counter value for that tag
  local cache_tags = ts.server_response.header['X-Cache-Tags'] or ''
  local delimiter = ','
  for match in (cache_tags..delimiter):gmatch("(.-)"..delimiter) do
    ts.debug("cache_tag: "..match)
    local stat = ts.stat_find(match)
    if(stat == nil) then
      stat = ts.stat_create(match, TS_LUA_RECORDDATATYPE_INT, TS_LUA_STAT_PERSISTENT, TS_STAT_SYNC_COUNT)
      stat:set_value(1)
    end
    ts.server_response.header['X-Cache-Tag-'..match] = stat:get_value()
  end
end

function do_global_cache_lookup_complete()
  ts.debug("global cache lookup complete hook")

  -- force a cache miss if the counter value for that tag is larger than in the response header
  local cache_status = ts.http.get_cache_lookup_status()
  if cache_status == TS_LUA_CACHE_LOOKUP_HIT_FRESH then
    ts.debug('cache hit')
    local cache_tags = ts.cached_response.header['X-Cache-Tags'] or ''
    local delimiter = ','
    for match in (cache_tags..delimiter):gmatch("(.-)"..delimiter) do
      ts.debug("cache_tag: "..match)
      local stat = ts.stat_find(match)
      if(stat ~= nil) then
        local tag = tonumber(ts.cached_response.header['X-Cache-Tag-'..match] or '')
        ts.debug("cache_tag value: "..tag)
        ts.debug("stat value: "..stat:get_value())
        if((tag ~= nil) and (stat:get_value() > tonumber(tag) )) then
          -- make it a cache miss for when the global statistics counter is larger than tag value
          ts.debug("forcing a cache miss")
          ts.http.set_cache_lookup_status(TS_LUA_CACHE_LOOKUP_MISS)
        end
      end
    end
  else
    ts.debug('no cache hit')
  end

end
