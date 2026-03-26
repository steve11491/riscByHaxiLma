`ifndef __VTOP_SV
`define __VTOP_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "src/core.sv"
`include "util/IBusToCBus.sv"
`include "util/DBusToCBus.sv"
`include "util/CBusArbiter.sv"
#endif

module VTop
	import common::*;(
	input logic clk, reset,

	output cbus_req_t  oreq,
	input  cbus_resp_t oresp
);

    ibus_req_t  ireq;
    ibus_resp_t iresp;
    dbus_req_t  dreq;
    dbus_resp_t dresp;
    cbus_req_t  icreq,  dcreq;
    cbus_resp_t icresp, dcresp;

    core core(
        .clk,
        .reset,
        .ireq,
        .iresp,
        .dreq,
        .dresp
    );

    IBusToCBus icvt(
        .ireq,
        .iresp,
        .icreq,
        .icresp
    );

    DBusToCBus dcvt(
        .dreq,
        .dresp,
        .dcreq,
        .dcresp
    );

    CBusArbiter mux(
        .clk,
        .reset,
        .ireqs({icreq, dcreq}),
        .iresps({icresp, dcresp}),
        .oreq,
        .oresp
    );

endmodule

`endif
