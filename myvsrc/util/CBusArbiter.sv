`ifndef __CBUSARBITER_SV
`define __CBUSARBITER_SV

`ifdef VERILATOR
`include "include/common.sv"
`else

#endif

/**
 * CBus仲裁器 - 精简版
 * 用于在指令总线和数据总线之间进行仲裁
 */

module CBusArbiter
    import common::*;#(
    parameter int NUM_INPUTS = 2,
    localparam int MAX_INDEX = NUM_INPUTS - 1
) (
    input logic clk, reset,
    input  cbus_req_t  [MAX_INDEX:0] ireqs,  // 输入请求数组
    output cbus_resp_t [MAX_INDEX:0] iresps,  // 输出响应数组
    output cbus_req_t  oreq,                   // 输出请求
    input  cbus_resp_t oresp                   // 输入响应
);

    logic busy;  // 忙状态标志
    int index, select;  // 当前处理的索引和选择的索引
    cbus_req_t saved_req, selected_req;  // 保存的请求和选择的请求

    // 选择一个优先的请求
    always_comb begin
        select = 0;
        for (int i = 0; i < NUM_INPUTS; i++) begin
            if (ireqs[i].valid) begin
                select = i;
                break;
            end
        end
    end

    assign selected_req = ireqs[select];

    // 输出请求
    assign oreq = busy ? ireqs[index] : '0;

    // 将响应反馈给选中的请求
    always_comb begin
        iresps = '0;
        if (busy) begin
            for (int i = 0; i < NUM_INPUTS; i++) begin
                if (index == i)
                    iresps[i] = oresp;
            end
        end
    end

    // 状态控制
    always_ff @(posedge clk)
    if (~reset) begin
        if (busy) begin
            if (oresp.last)
                {busy, saved_req} <= '0;
        end else begin
            busy <= selected_req.valid;
            index <= select;
            saved_req <= selected_req;
        end
    end else begin
        {busy, index, saved_req} <= '0;
    end

    `UNUSED_OK({saved_req});

endmodule

`endif
