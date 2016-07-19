-- rough example showing how we can do Stale-If-Error
-- https://tools.ietf.org/html/rfc5861

function process(header, body)
  ts.debug('server intercept')

  local resp = 'HTTP/1.1 200 OK\r\n'

  for k,v in pairs(header) do
    resp = resp .. k .. ': ' .. v .. '\r\n'
  end
  resp = resp .. '\r\n' .. body

  ts.say(resp)
end


function cache_lookup()
  ts.debug('cache-lookup')

  local inner = ts.http.is_internal_request()
  if inner ~= 0 then
    -- always make internal requests to be a cache miss so we retrive from origin
    ts.debug('internal')
    ts.http.set_cache_lookup_status(TS_LUA_CACHE_LOOKUP_MISS)
  else
    ts.debug('external')
    local cache_status = ts.http.get_cache_lookup_status()
    if cache_status == TS_LUA_CACHE_LOOKUP_HIT_STALE then
      ts.debug('stale hit')

      local url = ts.ctx['url'] or ''
      -- add extra query parameter to request 
      url = url .. '?async=yes'

      local ct = {
        header = ts.ctx['headers']
      }
      local res = ts.fetch(url, ct)

      if res.status == 200 then
        ts.debug('async response is good, will do a server intercept')
        ts.http.server_intercept(process, res.header, res.body )
      else
        ts.debug('async response is bad')
        ts.http.set_cache_lookup_status(TS_LUA_CACHE_LOOKUP_HIT_FRESH)
      end
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
