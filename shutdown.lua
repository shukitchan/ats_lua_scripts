-- Example to shutdown client or origin connection
-- This is done with a request header 'choice'

-- e.g. with an entry in remap.config like below and a test file 'test.txt' with random texts inside
-- map http://test.com/ http://httpbin.org/

-- curl -v -H'choice: cut_server' -H 'Host: test.com' -d "@test.txt" -X POST 'http://localhost:8080/post'
-- this will shutdown connection with the origin. It will also trigger the ATS to do retries if it is setup to do so. And after that, a status 502 will be returned to client

-- curl -v -H'choice: cut_client' -H 'Host: test.com' -d "@test.txt" -X POST 'http://localhost:8080/post'
-- this will shutdown connection with the client. It will cause the client to lose connection with ATS

local ffi = require 'ffi'

ffi.cdef[[
int     shutdown(int, int);
]]

local glibc = ffi.C

function transform(data, eos)
    ts.debug("testing")
    ts.debug(data)
end

function do_global_send_request()
    ts.debug("start sending request")
    local choice = ts.client_request.header['choice']
    if (choice == 'cut_server') then
      local fd = ts.http.get_server_fd()
      ts.debug('fd: ' .. fd)
      glibc.shutdown(fd, 1)
    end
    if (choice == 'cut_client') then
      local fd = ts.http.get_client_fd()
      ts.debug('fd: ' .. fd)
      glibc.shutdown(fd, 1)
    end
    ts.debug("done with sending request")
end

function do_global_read_request()
    ts.hook(TS_LUA_REQUEST_CLIENT, transform)
end
