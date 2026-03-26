`ifndef __WB_STAGE_SV
`define __WB_STAGE_SV

`ifdef VERILATOR
`include "include/common.sv"
`else

#endif

// 写回阶段模块 - 精简版
// 功能：将结果写回寄存器文件
module WB_stage
  import common::*;(
    input  logic         clk,               // 时钟信号
    input  logic         reset,             // 复位信号
    input  logic  [63:0] pc_in,             // PC输入
    input  logic  [63:0] result_in,        // ALU结果输入
    input  logic  [63:0] mem_data_in,      // 内存数据输入
    input  logic  [ 4:0] rd,               // 目标寄存器地址
    input  logic         reg_write,        // 寄存器写使能
    input  logic         mem_to_reg,        // 内存到寄存器控制信号
    input  logic         block,             // 阻塞信号
    input  logic         mem_finish,        // MEM阶段完成
    output logic  [63:0] pc_out,            // PC输出
    output logic  [63:0] result_out,       // 结果输出
    output word_t        regfile      [31:0],// 寄存器文件
    output logic         finish_w,          // 写完成信号
    output logic         valid,             // 有效信号
    output logic  [31:0] instr_out,        // 指令输出
    output logic         reg_write_out,    // 寄存器写使能输出
    input  logic  [31:0] instr_in          // 指令输入
);

    // 写回数据选择
    logic [63:0] write_data;

    // 选择写回数据
    always_comb begin
        if (mem_to_reg) begin
            write_data = mem_data_in;  // 从内存读取的数据
        end else begin
            write_data = result_in;    // ALU计算结果
        end
    end

    // 时序逻辑：寄存器写回
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            pc_out <= 64'h0;
            result_out <= 64'h0;
            instr_out <= 32'h0;
            reg_write_out <= 1'b0;
            valid <= 1'b0;
            finish_w <= 1'b0;
        end else if (block) begin
            // 阻塞状态
            finish_w <= 1'b0;
            valid <= 1'b0;
        end else if (mem_finish) begin
            pc_out <= pc_in;
            result_out <= write_data;
            instr_out <= instr_in;
            reg_write_out <= reg_write;
            valid <= 1'b1;
            finish_w <= 1'b1;

            // 写回寄存器
            if (reg_write && (rd != 5'b0)) begin
                regfile[rd] <= write_data;
            end
        end else begin
            finish_w <= 1'b0;
            valid <= 1'b0;
        end
    end

endmodule

`endif
