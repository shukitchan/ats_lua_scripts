-- killswitch example using ATS statistics API
-- 1) Kill switch originally off
-- 2) Send a request from localhost with KILLSWITCHON method to turn on the switch (i.e. curl -x KILLSWITCHON )
-- 3) Send a request from localhost with KILLSWITCHOFF method to turn off the switch (i.e. curl -x KILLSWITCHOFF )

local killswitch;
local killswitch_active;

function __init__(args)
  killswitch = ts.stat_create("killswitch",
    TS_LUA_RECORDDATATYPE_INT,
    TS_LUA_STAT_PERSISTENT,
    TS_LUA_STAT_SYNC_COUNT)
    
  local value = killswitch:get_value()
  if(value ~= 0 or value ~= 1) then
    killswitch:set_value(0)
  end
end

function do_global_read_request()
  local method = ts.client_request.get_method()
  if(method == 'KILLSWITCHON') then
    killswitch:set_value(1)
    ts.http.set_resp(200, 'Kill Switch On')
  elseif (method == 'KILLSWITCHOFF') then
    killswitch:set_value(0)
    ts.http.set_resp(200, 'Kill Switch Off')
  end
end

function do_global_send_response()
  local ks_value = killswitch:get_value()
  ts.client_response.header['X-KillSwitch'] = ks_value
end

