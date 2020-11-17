-- Status 103 Early Hints example using intercept / fetch 
-- 1) This lua script is for use in remap.config e.g. map http://test1.com/ http://httpbin.org/ @plugin=tslua.so @pparam=/<script location>/early_hints.lua
-- 2) We use an intercept to stop the processing of the request
-- 3) We use fetch to get back the response of the request
-- 4) If status code is 200 we add a 103 early hints header to the response

-- Tested on ATS 8.1.0
-- Reference Article: https://www.fastly.com/blog/beyond-server-push-experimenting-with-the-103-early-hints-status-code

function process(purl, phdrs)
    -- getting url, headers for the fetch
    local url = purl
    local hdr = phdrs

    local ct = {
        header = hdr,
        method = 'GET',
        cliaddr = '127.0.0.1:33333'
    }
    local arr = ts.fetch_multi(
            {
                {url, ct},
            })

    -- retrieve status, body, headers of the fetch
    local body = arr[1].body or ''
    local status = arr[1].status or 404
    local hdrs_resp = ''
    local hdrs = arr[1].header
    for k, v in pairs(hdrs) do
        ts.error(k..': '..v)
        hdrs_resp = hdrs_resp .. k .. ': ' .. v .. '\r\n'
    end

    -- assemblying for the final response
    local resp = ''
    if (status == 200) then
      -- Add early hints for status 200 
      resp = 'HTTP/1.1 103 Early Hints\r\n' ..
             'Link: </test.css>; rel=preload\r\n\r\n' ..
             'HTTP/1.1 200 Ok\r\n'
    else
      resp = 'HTTP/1.1 '..status..' Custom Status\r\n'
    end
    resp =  resp ..
            hdrs_resp .. '\r\n' ..
            body
    ts.say(resp)
end

function do_remap()
    -- no need to intercept for the internal fetch request
    local inner =  ts.http.is_internal_request()
    if inner ~= 0 then
        return 0
    end

    -- intercept and passing URL and headers as parameters
    local purl = ts.client_request.get_pristine_url()
    local phdrs = ts.client_request.get_headers()
    ts.http.intercept(process, purl, phdrs)
end
