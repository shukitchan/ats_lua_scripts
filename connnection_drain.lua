-- Connection draining example 
-- 1) in_rotation stat is created and set to 1
-- 2) healthchecks plugin is also used to provide healthcheck URL . i.e. '/__hc'
-- 3) A successful request (i.e. status 200 response) to the healthcheck URL will keep in_rotation as 1. Otherwise it will be set as 0. 
-- 3) in_rotation set as 0 will cause all response to have "Connection: close", therefore telling client to close connection after request

local in_rotation;

function __init__(args)
  in_rotation = ts.stat_create("in_rotation",
    TS_LUA_RECORDDATATYPE_INT,
    TS_LUA_STAT_PERSISTENT,
    TS_LUA_STAT_SYNC_COUNT)

  local value = in_rotation:get_value()
  if(value ~= 0 or value ~= 1) then
    in_rotation:set_value(1)
  end
end

function do_global_send_response()
  local value = in_rotation:get_value() or 1
  if (value == 0) then
    ts.client_response.header['Connection'] = 'close'
  end

  local req_scheme = ts.client_request.get_url_scheme() or 'http'
  local req_host = ts.client_request.get_url_host() or ''
  local req_path = ts.client_request.get_uri() or ''
  if(req_scheme == 'http' and req_host=='test3.com' and req_path=='/__hc') then
    local status = ts.client_response.get_status() or ''
    if (status == '200') then
      in_rotation:set_value(1)
    else
      in_rotation:set_value(0)
    end
  end

end
