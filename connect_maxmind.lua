-- Use maxmind GeoLite2 database to return information from an IP address

-- Setup Instructions
-- 1) install libmaxminddb - 1.6.0 (https://github.com/maxmind/libmaxminddb)
-- 2) Get GeoLite2 country database (GeoLite2-Country.mmdb) from https://dev.maxmind.com/geoip/geolite2-free-geolocation-data and put it in /usr/share/GeoIP/GeoLite2-Country.mmdb
-- 3) Get luajit-geoip 2.1.0(https://github.com/leafo/luajit-geoip) 
--   a) wget https://github.com/leafo/luajit-geoip/archive/refs/tags/v2.1.0.tar.gz
--   b) tar zxvf v2.1.0.tar.gz
--   c) cd luajit-geoip-2.1.0/geoip
--   d) mkdir -p /usr/local/share/lua/5.1/geoip
--   e) cp *.lua /usr/local/share/lua/5.1/geoip

ts.add_package_path('/usr/local/share/lua/5.1/?.lua')

local geoip = require 'geoip.mmdb'

function do_global_send_response()
  local mmdb = geoip.load_database("/usr/share/GeoIP/GeoLite2-Country.mmdb")

  local result = mmdb:lookup("8.8.8.8")

  ts.client_response.header['X-Maxmind-Info'] = result.country.iso_code
end

