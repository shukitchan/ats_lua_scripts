-- depends on "luajit-geoip"

-- Setup Instructions
-- 1) install libmaxminddb - 1.4.2 (https://github.com/maxmind/libmaxminddb)
-- 2) Get GeoLite2 country database (GeoLite2-Country.mmdb) from https://dev.maxmind.com/geoip/geoip2/geolite2/ and put it in /usr/local/var/lua/
-- 3) Get lua-resty-maxminddb (https://github.com/anjia0532/lua-resty-maxminddb.git) 
--   a) git clone https://github.com/anjia0532/lua-resty-maxminddb.git
--   b) cd lua-resty-maxminddb
--   c) git checkout d00c9f32224b4603f2e049b1edf2ddee9dd5b1bc
--   d) cp lib/resty/maxminddb.lua /usr/local/share/lua/5.1/

ts.add_package_path('/usr/local/share/lua/5.1/?.lua')

local geo = require 'maxminddb'
geo.init("/usr/local/var/lua/GeoLite2-Country.mmdb") 

function tprint (tbl, indent)
  if not indent then indent = 0 end
  for k, v in pairs(tbl) do
    formatting = string.rep("  ", indent) .. k .. ": "
    if type(v) == "table" then
      ts.debug(formatting)
      tprint(v, indent+1)
    else
      ts.debug(formatting .. v)
    end
  end
end

function do_global_send_response()
  local res,err = geo.lookup("8.8.8.8")
   
  if not res then
    ts.client_response.header['X-Maxmind-Info'] = 'failed to lookup by ip ,reason:' .. err
  else 
    tprint(res)
    ts.client_response.header['X-Maxmind-Info'] = 'check result in traffic.out with debug on'
  end 
end
