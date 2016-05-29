-- Check out https://docs.trafficserver.apache.org/en/latest/admin-guide/plugins/ts_lua.en.html
-- for information on how to run the script
--
-- This scripts set timeout values different from the default for a specific domain

function do_remap()
    local host = ts.client_request.header.Host or ''
    if host == 'www.yahoo.com' then
        ts.http.timeout_set(TS_LUA_TIMEOUT_ACTIVE, 10) -- active connection timeout
        ts.http.timeout_set(TS_LUA_TIMEOUT_CONNECT, 2) -- connect timeout
        ts.http.timeout_set(TS_LUA_TIMEOUT_DNS, 2) -- DNS resolution timeout
        ts.http.timeout_set(TS_LUA_TIMEOUT_NO_ACTIVITY, 5) -- no activity timeout
    end
    return 0
end
