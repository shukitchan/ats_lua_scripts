-- depends on "redis-lua" - https://github.com/nrk/redis-lua
-- redis-lua depends on LuaSocket - http://w3.impa.br/~diego/software/luasocket/

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
