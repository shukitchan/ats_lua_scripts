-- lua_cbor (Verison 1.0.0-1) is used - https://www.zash.se/lua-cbor.html
-- This is a pure lua implementation (almost) without external dependency
-- Place cbor.lua in a directory with other lua files. e.g. /usr/local/trafficserver/etc/trafficserver/

ts.add_package_path('/usr/local/trafficserver/etc/trafficserver/?.lua')

local cbor = require "cbor";

function do_global_send_response()

  -- Encode a Lua table to CBOR
  local data_to_encode = {
    name = "Alice",
    age = 30,
    is_active = true,
    hobbies = {"reading", "hiking"},
    address = {
        street = "123 Main St",
        city = "Anytown"
    }
  }
  local encoded_cbor = cbor.encode(data_to_encode)

  ts.client_response.header['test'] = encoded_cbor
end

