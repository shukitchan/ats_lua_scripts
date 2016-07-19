-- rough example showing how we can do Stale-While-Revalidate
-- https://tools.ietf.org/html/rfc5861
function async()
  ts.debug("async")

  local url = ts.ctx['url'] or ''
  -- add extra query parameter to async request 
  url = url .. '?async=yes'

  local ct = {
    header = ts.ctx['headers']
  }
  local res = ts.fetch(url, ct)

  if res.status == 200 then
    ts.debug('pushing')
    local purl = ts.ctx['url']
    local presp = 'HTTP/1.0 200 OK\r\n'
    local header = res.header
    for k, v in pairs( header) do
      presp = presp.. k .. ': ' .. v .. '\r\n'
    end
    presp = presp .. '\r\n' .. res.body

    local phdr = {}
    for k, v in pairs(ts.ctx['headers']) do
      phdr[k] = v
    end
    phdr['Content-Length'] = string.format('%d', string.len(presp))

    local pct = {
      header = phdr,
      method = 'PUSH',
      body = presp
    }
    local pres = ts.fetch(purl, pct)
  end
end

function cache_lookup()
  ts.debug('cache-lookup')

  local inner = ts.http.is_internal_request()
  if inner ~= 0 then
    -- always make internal requests to be a cache miss so we retrive from origin
    ts.debug('internal')
    ts.http.set_cache_lookup_status(TS_LUA_CACHE_LOOKUP_MISS)
  else
    -- mark stale hit as fresh hit and do an async request
    ts.debug('external')
    local cache_status = ts.http.get_cache_lookup_status()
    if cache_status == TS_LUA_CACHE_LOOKUP_HIT_STALE then
      ts.debug('stale hit')
      ts.http.set_cache_lookup_status(TS_LUA_CACHE_LOOKUP_HIT_FRESH)
      ts.schedule(TS_LUA_THREAD_POOL_NET, 0, async)
    end
  end

  return 0
end

function do_global_read_request()
  ts.ctx['url'] = ts.client_request.get_url()
  ts.ctx['headers'] = ts.client_request.get_headers()
  ts.hook(TS_LUA_HOOK_CACHE_LOOKUP_COMPLETE, cache_lookup)

  return 0
end
