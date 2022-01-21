-- Example showing how to do tracing with jaeger
-- depends on opentracing-1.5.1, lua-bridge-tracer-0.1.1, jaeger_client_cpp
--
-- 1) opentracing-1.5.1 
--    wget https://github.com/opentracing/opentracing-cpp/archive/v1.5.1.tar.gz 
--    follow instructions to compile and install
-- 2) lua-bridge-tracer 0.1.1
--    wget https://github.com/opentracing/lua-bridge-tracer/archive/v0.1.1.tar.gz
--    We need to add "target_link_libraries(opentracing_bridge_tracer luajit-5.1)" to CMakeLists.txt for the library to compile against luajit
--    Then follow the instructions to compile and install
-- 3) jaeger_client_cpp 0.4.2
--    wget https://github.com/jaegertracing/jaeger-client-cpp/releases/download/v0.4.2/libjaegertracing_plugin.linux_amd64.so
--    cp libjaegertracing_plugin.linux_amd64.so /usr/local/lib/libjaegertracing_plugin.so
-- 4) Copy the jaeger-config.json from this repo and copy to /usr/local/etc/ . Make sure it is readable by ATS.

local bridge_tracer = require('opentracing_bridge_tracer')

local f = assert(io.open('/usr/local/etc/jaeger-config.json', "rb"))
local config = f:read("*all")
f:close()

local tracer = bridge_tracer:new('/usr/local/lib/libjaegertracing_plugin.so', config)

function do_global_send_request()

    local span = tracer:start_span('hello')
    ts.debug('Debug Message')
    span:finish()

end
