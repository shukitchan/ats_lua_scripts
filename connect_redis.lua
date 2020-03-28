-- Prerequisite 0 - Use ATS 8.0.x

-- Prerequisite 1 - Luajit-2.1.0 beta3/Lua 5.1.4/LuaSocket 3.0 rc1/redis-lua 2.0.4

-- # Install luajit 2.1.0 beta 3
-- curl -R -O http://luajit.org/download/LuaJIT-2.1.0-beta3.tar.gz && \
-- tar zxf LuaJIT-2.1.0-beta3.tar.gz && \
-- cd LuaJIT-2.1.0-beta3 && \
-- make && \
-- sudo make install
-- # Install Lua 5.1.4
-- curl -R -O http://www.lua.org/ftp/lua-5.1.4.tar.gz && \
-- tar zxf lua-5.1.4.tar.gz && \
-- cd lua-5.1.4 && \
-- make linux test && \
-- sudo make linux install 
-- # Install LuaSocket v3.0-rc1 
-- wget https://github.com/diegonehab/luasocket/archive/v3.0-rc1.tar.gz && \
-- tar zvf v3.0-rc1.tar.gz && \
-- cd luasocket-3.0-rc1 && \
-- sed -i "s/LDFLAGS_linux=-O -shared -fpic -o/LDFLAGS_linux=-O -shared -fpic -L\/usr\/lib -lluajit-5.1 -o/" src/makefile && \
-- ln -sf /usr/lib/libluajit-5.1.so.2.1.0 /usr/lib/libluajit-5.1.so && \
-- make && \
-- sudo make install-unix
-- # Install redis-lua 2.0.4
-- wget https://github.com/nrk/redis-lua/archive/v2.0.4.tar.gz && \
-- tar zxf v2.0.4.tar.gz && \
-- sudo cp redis-lua-2.0.4/src/redis.lua /usr/local/share/lua/5.1/redis.lua

-- Prerequisite 2 - Set up redis-server with unix domain socket

-- unix domain socket has better performance and so we should set up local redis to use that
-- Note the sock must be readable/writable by nobody since ATS runs as that user
-- Sample instructions for setting redis 2.8.4 and putting a key in
-- 1. edit /etc/redis/redis.conf to set "port 0", "unixsocket /var/run/redis/redis.sock" and "unixsocketperm 755"  
-- 2. sudo chown nobody /var/run/redis
-- 3. sudo chgrp nogroup /var/run/redis
-- 4. sudo chown nobody /var/log/redis
-- 5. sudo chgrp nogroup /var/log/redis
-- 6. sudo -u nobody redis-server /etc/redis/redis.conf
-- 7. sudo -u nobody redis-cli -s /var/run/redis/redis.sock set mykey helloworld

ts.add_package_cpath('/usr/local/lib/lua/5.1/socket/?.so;/usr/local/lib/lua/5.1/mime/?.so')
ts.add_package_path('/usr/local/share/lua/5.1/?.lua;/usr/local/share/lua/5.1/socket/?.lua')

local redis = require 'redis'
-- not connecting to redis default port
-- local client = redis.connect('127.0.0.1', 6379)

-- connecting to unix domain socket
local client = redis.connect('unix:///var/run/redis/redis.sock')

function do_global_send_response()
  local response = client:ping()
  local value = client:get('mykey')
  ts.client_response.header['X-Redis-Ping'] = tostring(response)
  ts.client_response.header['X-Redis-MyKey'] = value
end
