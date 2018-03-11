-- use "redis-lua" - https://github.com/nrk/redis-lua
-- redis-lua depends on LuaSocket - http://w3.impa.br/~diego/software/luasocket/

ts.add_package_cpath('/usr/local/lib/lua/5.1/socket/?.so;/usr/local/lib/lua/5.1/mime/?.so')
ts.add_package_path('/usr/local/share/lua/5.1/?.lua;/usr/local/share/lua/5.1/socket/?.lua')

local redis = require 'redis'
local client = redis.connect('127.0.0.1', 6379)

function do_global_send_response()
  local response = client:ping()
  local value = client:get('mykey')
  ts.client_response.header['X-Redis-Ping'] = tostring(response)
  ts.client_response.header['X-Redis-MyKey'] = value
end
