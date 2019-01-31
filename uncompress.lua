-- depends on "lua-zlib"

-- Setup Instructions
-- 1) install lua-zlib - v1.2

ts.add_package_cpath('/usr/lib/lua/5.1/?.so')

local zlib = require "zlib"

function upper_transform(data, eos)
    ts.ctx['text'] = ts.ctx['text'] .. data

    if eos ==1 then
      local stream = zlib.inflate()
      local inflated, eof, bytes_in, bytes_out = stream(ts.ctx['text'])
      if (eof == true) then
         ts.debug("==== eof ====")
      end
      ts.debug("==== bytes_in: "..(bytes_in or ''))
      ts.debug("==== bytes_out:"..(bytes_out or ''))
      ts.debug("==== uncompressed data begin ===")
      ts.debug(inflated or 'no data')
      ts.debug("==== uncompressed data end ===")
    end

    return string.upper(data), eos
end

function do_remap()
    ts.hook(TS_LUA_RESPONSE_TRANSFORM, upper_transform)
    ts.ctx['text'] = ''
    return 0
end
