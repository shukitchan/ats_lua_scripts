-- put all lua and c library in /usr/local/var/lua/
ts.add_package_cpath('/usr/local/var/lua/?.so')
ts.add_package_path('/usr/local/var/lua/?.lua')

-- it is from power.so generated from power.c in github.com/shukitchan/ats_lua_scripts/tree/master/power
require("power")
-- it is from lib.lua
local lib = require("lib")

function send_response()
    ts.debug ( 'send_response')
    ts.client_response.header['Rhost'] = ts.ctx['rhost']

    -- e.g. can't run this
    -- ts.debug(os.clock())

    return 0
end

function do_remap()

    local req_host = ts.client_request.header['Host']
    ts.ctx['rhost'] = string.reverse(req_host)
    ts.hook(TS_LUA_HOOK_SEND_RESPONSE_HDR, send_response)

    -- print result from function in power.so
    ts.debug (tostring(square(5)))

    -- calling function in lib.lua
    lib.test()

    -- e.g can't run this
    -- ts.debug(os.clock())

    return 0
end

function __init__(args)
  local env = {
    -- variables and functions from 'ts'
    ts = { debug = ts.debug, ctx = ts.ctx, hook = ts.hook,
           client_request = {header = ts.client_request.header},
           client_response = {header = ts.client_response.header}  },
    TS_LUA_HOOK_SEND_RESPONSE_HDR = TS_LUA_HOOK_SEND_RESPONSE_HDR,

    -- white-listed lua global functions
    tostring = tostring,
    string = {reverse = string.reverse},

    -- global functions in this file
    do_remap = do_remap,
    send_response = send_response,

    -- functions from power.so and lib.lua
    square = square,
    lib = { test = lib.test }
  }

  -- set sandbox env for all lua functions
  -- we can find out all functions in a module using getfenv(module)
  setfenv(do_remap, env)
  setfenv(send_response, env)
  setfenv(lib.test, env)
end

