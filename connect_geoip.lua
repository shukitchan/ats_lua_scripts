-- Moved to https://github.com/apache/trafficserver/tree/master/example/plugins/lua-api
-- GeoIP legacy data can be retrieved here - https://mailfud.org/geoip-legacy/

-- depends on "luajit-geoip"

-- Setup Instructions
-- 1) install GeoIP - 1.6.12
-- 2) install GeoIP legacy country database - https://dev.maxmind.com/geoip/legacy/install/country/
-- 3) install luajit-geoip (https://github.com/leafo/luajit-geoip) or just copy geoip/init.lua from the repo to /usr/local/share/lua/5.1/geoip/init.lua  
-- 4) You may need to make change so luajit-geoip does ffi.load() on /usr/local/lib/libGeoIP.so 

ts.add_package_path('/usr/local/share/lua/5.1/?.lua')

local geoip = require 'geoip'

function do_global_send_response()
  local res = geoip.lookup_addr("8.8.8.8")
  ts.client_response.header['X-Country'] = res.country_code
end
