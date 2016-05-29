-- Check out https://docs.trafficserver.apache.org/en/latest/admin-guide/plugins/ts_lua.en.html
-- for information on how to run the script
--
-- This script add CORS header to the response if the request has a referer header matching
-- some criteria

function send_response()
    if ts.ctx['origin'] == nil then
      ts.debug("invalid referer")
    else
      ts.client_response.header['Access-Control-Allow-Origin'] = ts.ctx['origin']
    end

    return 0
end

function do_remap()
    local referer = ts.client_request.header.Referer
    if referer == nil then 
      ts.ctx['origin'] = nil
    else
      ts.ctx['origin'] = string.match(referer, "http://%a+.yahoo.com")
    end

    ts.hook(TS_LUA_HOOK_SEND_RESPONSE_HDR, send_response)
    return 0
end
