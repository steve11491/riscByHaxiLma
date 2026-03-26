`ifndef __IBUSTOCBUS_SV
`define __IBUSTOCBUS_SV

`ifdef VERILATOR
`include "include/common.sv"
`else

#endif

module IBusToCBus
    import common::*;(
    input  ibus_req_t  ireq,
    output ibus_resp_t iresp,
    output cbus_req_t  icreq,
    input  cbus_resp_t icresp
);
    // IBus转换为CBus
    assign icreq.valid = ireq.valid;
    assign icreq.is_write = 1'b0;  // 指令总是读操作
    assign icreq.size = MSIZE4;
    assign icreq.addr = ireq.addr;
    assign icreq.strobe = 8'h0;
    assign icreq.data = 64'h0;
    assign icreq.len = MLEN1;
    assign icreq.burst = AXI_BURST_FIXED;

    // CBus响应转换为IBus响应
    logic okay;
    assign okay = icresp.ready && icresp.last;

    assign iresp.addr_ok = okay;
    assign iresp.data_ok = okay;
    assign iresp.data = icresp.data[31:0];  // 取32位指令
endmodule

`endif
