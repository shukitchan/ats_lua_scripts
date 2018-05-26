-- works on linuix
-- insert a new header into the request to record the TCP route trip time from TCP_INFO

local ffi = require("ffi")
ffi.cdef[[
static const int IPPROTO_TCP = 6;
static const int TCP_INFO = 11;

typedef struct tcp_info {
         uint8_t    tcpi_state;
         uint8_t    tcpi_ca_state;
         uint8_t    tcpi_retransmits;
         uint8_t    tcpi_probes;
         uint8_t    tcpi_backoff;
         uint8_t    tcpi_options;
         uint8_t    tcpi_snd_wscale : 4, tcpi_rcv_wscale : 4;

         uint32_t   tcpi_rto;
         uint32_t   tcpi_ato;
         uint32_t   tcpi_snd_mss;
         uint32_t   tcpi_rcv_mss;

         uint32_t   tcpi_unacked;
         uint32_t   tcpi_sacked;
         uint32_t   tcpi_lost;
         uint32_t   tcpi_retrans;
         uint32_t   tcpi_fackets;

         /* Times. */
         uint32_t   tcpi_last_data_sent;
         uint32_t   tcpi_last_ack_sent;     /* Not remembered, sorry. */
         uint32_t   tcpi_last_data_recv;
         uint32_t   tcpi_last_ack_recv;

         /* Metrics. */
         uint32_t   tcpi_pmtu;
         uint32_t   tcpi_rcv_ssthresh;
         uint32_t   tcpi_rtt;
         uint32_t   tcpi_rttvar;
         uint32_t   tcpi_snd_ssthresh;
         uint32_t   tcpi_snd_cwnd;
         uint32_t   tcpi_advmss;
         uint32_t   tcpi_reordering;
} info;

typedef uint32_t socklen_t;

int getsockopt(int sockfd, int level, int optname, void *optval, socklen_t *optlen);
]]

local C = ffi.C

function do_global_read_request()
    local fd = ts.http.get_client_fd() or ''
    local inf = ffi.new("info")
    local inf_size = ffi.sizeof(inf)
    local siz = ffi.new("socklen_t[1]", inf_size)
    local rc = C.getsockopt(fd, C.IPPROTO_TCP, C.TCP_INFO, inf, siz)
    ts.client_request.header['X-Tcp-Rtt'] = inf.tcpi_rtt
end
