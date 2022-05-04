-- Copy from https://github.com/neomantra/luajit-jemalloc

local ffi = require 'ffi'
local C = ffi.C

local JEMALLOC_PREFIX = JEMALLOC_PREFIX or
                        os.getenv('JEMALLOC_PREFIX') or
                        (ffi.os == 'OSX' and 'je_' or '')

do
    local cdef_template = [[
void !_!malloc_stats_print(void (*write_cb) (void *, const char *),
void *cbopaque, const char *opts);
]]
    local cdef_str = string.gsub(cdef_template, '!_!', JEMALLOC_PREFIX)
    ffi.cdef(cdef_str)
end

-- our public API
local J = {}

function J.get_prefix()
    return JEMALLOC_PREFIX
end

-------------------------------------------------------------------------------
-- bind "non-standard" API

do
    local malloc_stats_print_fname = JEMALLOC_PREFIX..'malloc_stats_print'
    function J.malloc_stats_print()  -- TODO allow user-supplied callback
        C[malloc_stats_print_fname]( nil, nil, nil )
    end
end

-- return public API
return J
