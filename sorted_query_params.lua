-- Check out https://docs.trafficserver.apache.org/en/latest/admin-guide/plugins/ts_lua.en.html
-- for information on how to run the script
-- 
-- This script is for sorting query parameters on incoming requests before doing cache lookup
-- so we can get better cache hit ratio

function pairsByKeys (t, f)
  local a = {}
  for n in pairs(t) do table.insert(a, n) end
  table.sort(a, f)
  local i = 0      -- iterator variable
  local iter = function ()   -- iterator function
    i = i + 1
    if a[i] == nil then return nil
    else return a[i], t[a[i]]
    end
  end
  return iter
end

function do_remap()
  t = {} 
  s = ts.client_request.get_uri_args() or ''
  -- Original String
  i = 1
  for k, v in string.gmatch(s, "([0-9a-zA-Z-_]+)=([0-9a-zA-Z-_]+)") do
    t[k] = v
  end

  output = ''
  for name, line in pairsByKeys(t) do
    output = output .. '&' .. name .. '=' .. line
  end
  output = string.sub(output, 2)
  -- Modified String 
  ts.client_request.set_uri_args(output)
  return 0
end 
