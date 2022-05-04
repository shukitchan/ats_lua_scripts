-- For ATS compiled/preloaded with Jemalloc, we can print stats in traffic.out when we issue requests with a special header

local J = require 'jemalloc'

function do_global_read_request()
    ts.http.skip_remapping_set(1);
    local header = ts.client_request.header['X-Jemalloc-Stat'] or ''
    if header == '1' then
      J.malloc_stats_print()
    end
    return 0
end
