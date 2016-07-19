-- Check out https://docs.trafficserver.apache.org/en/latest/admin-guide/plugins/ts_lua.en.html
-- for information on how to run the script
--
-- This script demostrates how to route request to a backup site when the origin is failing

function do_os_response()
    ts.debug('do_os_response')
    local st = ts.http.get_server_state()
    if st == TS_LUA_SRVSTATE_CONNECTION_ALIVE then
        ts.debug('alive')
        ts.http.enable_redirect(0)
    else 
        ts.debug('not alive')
        ts.http.redirect_url_set('http://foo.com/backup.html')
        ts.hook(TS_LUA_HOOK_SEND_RESPONSE_HDR, send_response)
    end
end

function send_response()
    ts.debug('send_response')
end

function do_remap()
    ts.debug('do_remap')
    return 0
end
