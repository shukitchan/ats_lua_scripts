-- Check out https://docs.trafficserver.apache.org/en/latest/admin-guide/plugins/ts_lua.en.html
-- for information on how to run the script
--
-- This script adds HSTS header to response for requests for www.yahoo.com resources

function do_remap()
    local host = ts.client_request.header.Host or ''
    if host == 'www.yahoo.com' then
        ts.client_response.header['Strict-Transport-Security'] = "max-age=172800"
    end
    return 0
end

