`ifndef __IF_STAGE_SV
`define __IF_STAGE_SV

`ifdef VERILATOR
`include "include/common.sv"
`else

#endif

// 取指阶段模块 - 精简版
// 该模块负责从内存中获取指令并更新程序计数器(PC)
module IF_stage
  import common::*;(
    input  logic              clk,
    input  logic              reset,
    output logic       [63:0] pc,             // 程序计数器
    output logic       [31:0] instr,          // 当前指令
    output ibus_req_t         ibus_req,       // 指令总线请求
    input  ibus_resp_t        ibus_resp,      // 指令总线响应
    input  logic              branch_taken,   // 分支跳转信号
    input  logic       [63:0] branch_target,  // 分支跳转目标地址
    input  logic              stall,          // 流水线暂停信号
    output logic              if_finish       // PC更新完成信号
);

  logic [63:0] current_pc, next_pc;
  logic [31:0] instruction;

  // 简化的状态机：只支持基本的取指和分支
  enum logic [1:0] {
    IDLE,           // 空闲状态
    REQUEST_SENT    // 已发送取指请求，等待响应
  } state;

  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      state <= IDLE;
      current_pc <= PCINIT;
      pc <= PCINIT;
      instr <= 32'b0;
      ibus_req.valid <= 1'b0;
      ibus_req.addr <= 64'b0;
    end else begin
      case (state)
        IDLE: begin
          if (!stall) begin
            // 发送取指请求
            ibus_req.valid <= 1'b1;
            ibus_req.addr <= current_pc;
            state <= REQUEST_SENT;
          end
        end

        REQUEST_SENT: begin
          if (ibus_resp.addr_ok) begin
            ibus_req.valid <= 1'b0;  // 清除请求
          end

          if (ibus_resp.data_ok) begin
            // 收到指令数据
            instruction <= ibus_resp.data;
            pc <= current_pc;
            instr <= ibus_resp.data;
            if_finish <= 1'b1;

            // 计算下一个PC
            if (branch_taken) begin
              next_pc <= branch_target;
            end else begin
              next_pc <= current_pc + 4;
            end

            current_pc <= branch_taken ? branch_target : (current_pc + 4);
            state <= IDLE;
          end else begin
            if_finish <= 1'b0;
          end
        end

        default: begin
          state <= IDLE;
        end
      endcase
    end
  end

endmodule

`endif
