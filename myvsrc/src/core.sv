`ifndef __CORE_SV
`define __CORE_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "src/IF_stage.sv"
`include "src/ID_stage.sv"
`include "src/EX_stage.sv"
`include "src/MEM_stage.sv"
`include "src/WB_stage.sv"
`endif

// 五级流水线RISC-V处理器核心模块 - 精简版
module core
  import common::*;(
    // 基本控制信号
    input  logic       clk,    reset,     // 时钟和复位信号
    // 指令总线接口
    input  ibus_resp_t iresp,             // 指令总线响应
    // 数据总线接口
    input  dbus_resp_t dresp,             // 数据总线响应
    // 指令总线接口
    output ibus_req_t  ireq,              // 指令总线请求
    // 数据总线接口
    output dbus_req_t  dreq               // 数据总线请求
);

  // 寄存器堆
  (* ram_style = "distributed" *) word_t regfile [31:0];

  // 流水线控制信号
  wire          stall;                     // 流水线暂停信号
  wire          block;                     // 流水线阻塞信号
  wire          branch_taken;             // 分支是否taken
  wire   [63:0] branch_target;            // 分支目标地址

  // IF阶段信号
  wire   [63:0] if_pc;                     // IF阶段PC值
  wire   [31:0] if_instr;                 // IF阶段指令
  wire          if_finish;                // IF阶段完成信号

  // ID阶段信号
  wire          id_branch;                // ID阶段分支信号
  wire          id_finish;                // ID阶段完成信号
  logic  [63:0] id_pc;
  logic  [31:0] id_instr;
  logic  [4:0]  id_rs1, id_rs2, id_rd;
  logic  [63:0] id_imm;
  logic  [1:0]  id_mem_size;
  logic         id_reg_write;
  logic         id_mem_read;
  logic         id_mem_write;
  logic         id_alu_src;
  logic         id_mem_to_reg;

  // EX阶段信号
  wire          ex_branch;                // EX阶段分支信号
  wire   [63:0] ex_branch_target;         // EX阶段分支目标
  wire          ex_finish;                // EX阶段完成信号
  logic  [63:0] ex_pc;
  logic  [31:0] ex_instr;
  logic  [63:0] ex_result;
  logic  [4:0]  ex_rd;
  logic         ex_mem_read;
  logic         ex_mem_write;
  logic         ex_mem_to_reg;
  logic         ex_reg_write;
  logic  [1:0]  ex_mem_size;
  logic  [4:0]  ex_rs2;
  logic         ex_valid;

  // MEM阶段信号
  wire          mem_exception;
  wire          finish_r;                  // 读操作完成标志
  logic  [63:0] mem_pc;
  logic  [31:0] mem_instr;
  logic  [63:0] mem_result;
  logic  [63:0] mem_ex_out;
  logic  [4:0]  mem_rd;
  logic         mem_reg_write;
  logic         mem_mem_to_reg;
  logic         mem_ex_result_valid;
  logic         mem_mem_read;
  logic         mem_mem_write;
  logic  [63:0] mem_addr_out;
  logic         mem_finish;

  // WB阶段信号
  wire          finish_w_wb;              // WB阶段完成信号
  logic  [63:0] wb_pc;
  logic  [63:0] wb_result;
  logic  [31:0] wb_instr;
  logic         wb_reg_write;
  logic         wb_valid;

  // 流水线控制：基于数据冒险的暂停/阻塞逻辑
  assign stall = 1'b0;  // 暂时不使用stall
  assign block = ((id_rs1 != 0) && (id_rs1 == ex_rd && ex_reg_write && ex_mem_to_reg == 1'b0)) ||
                 ((id_rs2 != 0) && (id_rs2 == ex_rd && ex_reg_write && ex_mem_to_reg == 1'b0));

  // 分支信号连接
  assign branch_taken = ex_branch;
  assign branch_target = ex_branch_target;

  // IF stage实例
  IF_stage if_stage (
      .clk(clk),
      .reset(reset),
      .pc(if_pc),
      .instr(if_instr),
      .ibus_req(ireq),
      .ibus_resp(iresp),
      .branch_taken(branch_taken),
      .branch_target(branch_target),
      .stall(stall),
      .if_finish(if_finish)
  );

  // ID stage实例
  ID_stage id_stage (
      .clk(clk),
      .reset(reset),
      .block(block),
      .pipeline_flush(1'b0),  // 精简版暂时不使用流水线冲刷
      .pc_in(if_pc),
      .instr_in(if_instr),
      .pc_out(id_pc),
      .instr_out(id_instr),
      .rs1(id_rs1),
      .rs2(id_rs2),
      .rd(id_rd),
      .imm(id_imm),
      .mem_size(id_mem_size),
      .reg_write(id_reg_write),
      .mem_read(id_mem_read),
      .mem_write(id_mem_write),
      .branch(id_branch),
      .alu_src(id_alu_src),
      .mem_to_reg(id_mem_to_reg),
      .id_finish(id_finish),
      .if_finish(if_finish)
  );

  // EX stage实例
  EX_stage ex_stage (
      .clk(clk),
      .reset(reset),
      .pc_in(id_pc),
      .instr_in(id_instr),
      .imm(id_imm),
      .rs1(id_rs1),
      .rs2(id_rs2),
      .rs2_out(ex_rs2),
      .pipeline_flush(1'b0),
      .rd_in(id_rd),
      .pc_out(ex_pc),
      .result(ex_result),
      .block(block),
      .id_finish(id_finish),
      .ex_finish(ex_finish),
      .regfile(regfile),
      .rd_out(ex_rd),
      .valid(ex_valid),
      .instr_out(ex_instr),
      .mem_size_in(id_mem_size),
      .mem_size_out(ex_mem_size),
      .mem_read_in(id_mem_read),
      .mem_write_in(id_mem_write),
      .mem_to_reg_in(id_mem_to_reg),
      .reg_write_in(id_reg_write),
      .mem_read_out(ex_mem_read),
      .mem_write_out(ex_mem_write),
      .mem_to_reg_out(ex_mem_to_reg),
      .reg_write_out(ex_reg_write),
      .branch_out(ex_branch),
      .branch_target_out(ex_branch_target)
  );

  // MEM stage实例
  MEM_stage mem_stage (
      .clk(clk),
      .reset(reset),
      .pc_in(ex_pc),
      .result_in(ex_result),
      .mem_read(ex_mem_read),
      .mem_write(ex_mem_write),
      .write_data(regfile[ex_rs2]),
      .mem_size(ex_mem_size),
      .pc_out(mem_pc),
      .result_out(mem_result),
      .ex_result_out(mem_ex_out),
      .instr_in(ex_instr),
      .dbus_req(dreq),
      .dbus_resp(dresp),
      .mem_exception(mem_exception),
      .block(block),
      .finish_w(),
      .finish_r(finish_r),
      .rd_in(ex_rd),
      .rd_out(mem_rd),
      .reg_write_in(ex_reg_write),
      .reg_write_out(mem_reg_write),
      .mem_to_reg_in(ex_mem_to_reg),
      .mem_to_reg_out(mem_mem_to_reg),
      .ex_result_valid(ex_valid),
      .mem_result_valid(mem_ex_result_valid),
      .instr_out(mem_instr),
      .mem_read_out(mem_mem_read),
      .mem_write_out(mem_mem_write),
      .mem_addr_out(mem_addr_out),
      .ex_finish(ex_finish),
      .mem_finish(mem_finish)
  );

  // WB stage实例
  WB_stage wb_stage (
      .clk(clk),
      .reset(reset),
      .pc_in(mem_pc),
      .result_in(mem_ex_out),
      .mem_data_in(mem_result),
      .rd(mem_rd),
      .reg_write(mem_reg_write),
      .mem_to_reg(mem_mem_to_reg),
      .block(block),
      .mem_finish(mem_finish),
      .pc_out(wb_pc),
      .result_out(wb_result),
      .regfile(regfile),
      .finish_w(finish_w_wb),
      .valid(wb_valid),
      .instr_in(mem_instr),
      .instr_out(wb_instr),
      .reg_write_out(wb_reg_write)
  );

endmodule

`endif
