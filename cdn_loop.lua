-- CDN-Loop example from https://blog.cloudflare.com/preventing-request-loops-using-cdn-loop/

-- Example with CDN-Loop added to request downstream
--   curl -v -H 'CDN-Loop: test2' -H 'CDN-Loop: test1' 'http://test.com/' 

-- Example with multi-hop cycle detected
--   curl -v -H 'CDN-Loop: mytest' -H 'CDN-Loop: test1' 'http://test.com/'

function do_global_read_request()
    ts.debug("CDN-Loop implementation")
    local tag = 'mytest'
    local info = ts.client_request.header['CDN-Loop'] or ''
    ts.debug('info: '..info)

    if info == '' then
        ts.client_request.header['CDN-Loop'] = tag
        return 0
    end

    -- remove white spaces
    info = info:gsub("%s+", "")

    -- comma separated list of string
    for str in string.gmatch(info, '([^,]+)') do
        if str == tag then
            -- loop detected, sending response
            ts.http.set_resp(400, "Multi-Hop Cycle Detected\n")
        end
    end

    -- adding own tag to the header
    ts.client_request.header['CDN-Loop'] = info..', '..tag
end
