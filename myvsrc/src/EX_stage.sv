`ifndef __EX_STAGE_SV
`define __EX_STAGE_SV

`ifdef VERILATOR
`include "include/common.sv"
`else

#endif

// 执行阶段模块 - 精简版
// 功能：执行算术逻辑运算、分支跳转判断和地址计算
// 支持前递(Forwarding)机制解决RAW数据冒险
module EX_stage
  import common::*;(
    // 时钟和复位信号
    input  logic         clk,
                        reset,
    // 输入信号
    input  logic  [63:0] pc_in,          // 程序计数器输入
    input  logic  [31:0] instr_in,       // 指令输入
    input  logic  [63:0] imm,            // 立即数
    input  logic  [ 4:0] rs1,            // 源寄存器1地址
                        rs2,             // 源寄存器2地址
    input  logic         block,          // 阻塞信号
    input  logic         pipeline_flush, // 流水线冲刷信号
    input  logic         reg_write_in,   // 寄存器写使能输入
    input  logic  [ 4:0] rd_in,          // 目标寄存器
    input  logic         mem_read_in,    // 内存读使能输入
    input  logic         mem_write_in,   // 内存写使能输入
    input  logic         mem_to_reg_in,  // 内存到寄存器控制输入
    input  logic   [1:0] mem_size_in,
    // 输出信号
    output logic  [ 4:0] rd_out,         // 目标寄存器
    output logic  [63:0] pc_out,         // 程序计数器输出
    output logic  [63:0] result,         // ALU结果
    input  logic         id_finish,      // ID 阶段完成信号
    output logic         ex_finish,      // EX 阶段完成信号
    input  word_t        regfile  [31:0], // 寄存器文件
    output logic         valid,          // 有效信号
    output logic  [31:0] instr_out,      // 指令输出
    output logic         mem_read_out,   // 内存读使能输出
    output logic         mem_write_out,  // 内存写使能输出
    output logic         mem_to_reg_out, // 内存到寄存器控制输出
    output logic         reg_write_out,  // 寄存器写使能输出
    output logic   [1:0] mem_size_out,
    output logic   [4:0] rs2_out,
    output logic         branch_out,     // 分支输出
    output logic  [63:0] branch_target_out  // 分支目标输出
);

    // 内部信号定义
    logic [63:0] alu_result = '0;
    logic [63:0] branch_target = '0;
    logic        branch_taken = '0;
    logic [63:0] rs1_data;
    logic [63:0] rs2_data;
    logic [63:0] op1;    // ALU操作数1
    logic [63:0] op2;    // ALU操作数2

    // 前递信号 - 来自MEM和WB阶段
    logic [63:0] mem_forward_data;  // MEM阶段前递数据
    logic [63:0] wb_forward_data;   // WB阶段前递数据
    logic        mem_reg_write;    // MEM阶段寄存器写使能
    logic [4:0]  mem_rd;            // MEM阶段目标寄存器
    logic        wb_reg_write;     // WB阶段寄存器写使能
    logic [4:0]  wb_rd;             // WB阶段目标寄存器

    // 指令类型标志
    logic is_rtype, is_itype, is_load, is_store, is_branch, is_jal, is_jalr, is_lui, is_auipc;
    logic [2:0] funct3;
    logic [6:0] funct7;

    // 初始化MEM和WB阶段的前递信号（默认为0，实际应连接到MEM_stage和WB_stage）
    assign mem_forward_data = 64'h0;
    assign wb_forward_data = 64'h0;
    assign mem_reg_write = 1'b0;
    assign mem_rd = 5'h0;
    assign wb_reg_write = 1'b0;
    assign wb_rd = 5'h0;

    // 组合逻辑：前递机制和数据准备
    always_comb begin
        // 默认值：从寄存器文件读取
        rs1_data = regfile[rs1];
        rs2_data = regfile[rs2];

        // 前递逻辑：解决RAW数据冒险
        // 优先级：WB > MEM > 寄存器文件
        // rs1前递
        if (rs1 != 5'b0) begin
            // WB阶段前递（最高优先级）
            if (wb_reg_write && (wb_rd == rs1)) begin
                rs1_data = wb_forward_data;
            end
            // MEM阶段前递（次高优先级）
            else if (mem_reg_write && (mem_rd == rs1)) begin
                rs1_data = mem_forward_data;
            end
        end

        // rs2前递
        if (rs2 != 5'b0) begin
            // WB阶段前递（最高优先级）
            if (wb_reg_write && (wb_rd == rs2)) begin
                rs2_data = wb_forward_data;
            end
            // MEM阶段前递（次高优先级）
            else if (mem_reg_write && (mem_rd == rs2)) begin
                rs2_data = mem_forward_data;
            end
        end

        // 解码指令类型
        is_rtype = (instr_in[6:0] == 7'b0110011) || (instr_in[6:0] == 7'b0111011);
        is_itype = (instr_in[6:0] == 7'b0010011) || (instr_in[6:0] == 7'b0011011);
        is_load  = (instr_in[6:0] == 7'b0000011);
        is_store = (instr_in[6:0] == 7'b0100011);
        is_branch = (instr_in[6:0] == 7'b1100011);
        is_jal   = (instr_in[6:0] == 7'b1101111);
        is_jalr  = (instr_in[6:0] == 7'b1100111);
        is_lui   = (instr_in[6:0] == 7'b0110111);
        is_auipc = (instr_in[6:0] == 7'b0010111);

        funct3 = instr_in[14:12];
        funct7 = instr_in[31:25];

        // 选择ALU操作数
        if (alu_src == 1'b1) begin
            op1 = rs1_data;
            op2 = imm;  // I-type指令使用立即数
        end else if (is_lui) begin
            op1 = 64'h0;
            op2 = imm;
        end else if (is_auipc) begin
            op1 = pc_in;
            op2 = imm;
        end else if (is_jalr) begin
            op1 = rs1_data;
            op2 = imm;
        end else if (is_branch || is_jal) begin
            op1 = rs1_data;
            op2 = rs2_data;
        end else begin
            op1 = rs1_data;
            op2 = rs2_data;
        end

        // ALU运算
        alu_result = 64'h0;
        branch_taken = 1'b0;
        branch_target = 64'h0;

        if (is_rtype) begin
            // R-type算术指令
            case (funct3)
                3'b000: begin  // ADD/SUB
                    if (funct7 == 7'b0100000)
                        alu_result = op1 - op2;  // SUB
                    else
                        alu_result = op1 + op2;  // ADD
                end
                3'b001: alu_result = op1 << op2[5:0];  // SLL
                3'b010: alu_result = ($signed(op1) < $signed(op2)) ? 64'h1 : 64'h0;  // SLT
                3'b011: alu_result = (op1 < op2) ? 64'h1 : 64'h0;  // SLTU
                3'b100: alu_result = op1 ^ op2;  // XOR
                3'b101: begin  // SRL/SRA
                    if (funct7 == 7'b0100000)
                        alu_result = $signed(op1) >>> op2[5:0];  // SRA
                    else
                        alu_result = op1 >> op2[5:0];  // SRL
                end
                3'b110: alu_result = op1 | op2;  // OR
                3'b111: alu_result = op1 & op2;  // AND
                default: alu_result = op1 + op2;
            endcase
        end else if (is_itype) begin
            // I-type算术指令
            case (funct3)
                3'b000: alu_result = op1 + op2;  // ADDI
                3'b001: alu_result = op1 << op2[5:0];  // SLLI
                3'b010: alu_result = ($signed(op1) < $signed(op2)) ? 64'h1 : 64'h0;  // SLTI
                3'b011: alu_result = (op1 < op2) ? 64'h1 : 64'h0;  // SLTIU
                3'b100: alu_result = op1 ^ op2;  // XORI
                3'b101: begin  // SRLI/SRAI
                    if (funct7[5] == 1'b1)
                        alu_result = $signed(op1) >>> op2[5:0];  // SRAI
                    else
                        alu_result = op1 >> op2[5:0];  // SRLI
                end
                3'b110: alu_result = op1 | op2;  // ORI
                3'b111: alu_result = op1 & op2;  // ANDI
                default: alu_result = op1 + op2;
            endcase
        end else if (is_load || is_store) begin
            // Load/Store指令：计算内存地址
            alu_result = op1 + op2;
        end else if (is_branch) begin
            // 分支指令：计算分支目标
            branch_target = pc_in + {{52{imm[63]}}, imm[63:0]};
            case (funct3)
                3'b000: branch_taken = (rs1_data == rs2_data);  // BEQ
                3'b001: branch_taken = (rs1_data != rs2_data);  // BNE
                3'b100: branch_taken = ($signed(rs1_data) < $signed(rs2_data));  // BLT
                3'b101: branch_taken = ($signed(rs1_data) >= $signed(rs2_data));  // BGE
                3'b110: branch_taken = (rs1_data < rs2_data);  // BLTU
                3'b111: branch_taken = (rs1_data >= rs2_data);  // BGEU
                default: branch_taken = 1'b0;
            endcase
            if (branch_taken)
                alu_result = branch_target;
            else
                alu_result = pc_in + 4;
        end else if (is_jal) begin
            // JAL指令：跳转并保存返回地址
            branch_target = pc_in + {{44{imm[63]}}, imm[63:0]};
            branch_taken = 1'b1;
            alu_result = branch_target;
        end else if (is_jalr) begin
            // JALR指令：寄存器间接跳转
            branch_target = (op1 + op2) & ~64'h1;
            branch_taken = 1'b1;
            alu_result = branch_target;
        end else if (is_lui) begin
            // LUI指令
            alu_result = imm;
        end else if (is_auipc) begin
            // AUIPC指令
            alu_result = pc_in + imm;
        end else begin
            alu_result = op1 + op2;
        end

        // 保存返回地址（JAL/JALR）
        if (is_jal || is_jalr) begin
            alu_result = branch_taken ? branch_target : pc_in + 4;
        end
    end

    // 时序逻辑：状态更新
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            pc_out <= 64'h0;
            result <= 64'h0;
            rd_out <= 5'h0;
            instr_out <= 32'h0;
            mem_read_out <= 1'b0;
            mem_write_out <= 1'b0;
            mem_to_reg_out <= 1'b0;
            reg_write_out <= 1'b0;
            mem_size_out <= 2'b00;
            rs2_out <= 5'h0;
            valid <= 1'b0;
            ex_finish <= 1'b0;
            branch_out <= 1'b0;
            branch_target_out <= 64'h0;
        end else if (pipeline_flush) begin
            // 流水线冲刷
            pc_out <= 64'h0;
            result <= 64'h0;
            rd_out <= 5'h0;
            instr_out <= 32'h0;
            mem_read_out <= 1'b0;
            mem_write_out <= 1'b0;
            mem_to_reg_out <= 1'b0;
            reg_write_out <= 1'b0;
            mem_size_out <= 2'b00;
            rs2_out <= 5'h0;
            valid <= 1'b0;
            ex_finish <= 1'b0;
            branch_out <= 1'b0;
            branch_target_out <= 64'h0;
        end else if (id_finish && !block) begin
            pc_out <= pc_in;
            result <= alu_result;
            rd_out <= rd_in;
            instr_out <= instr_in;
            mem_read_out <= mem_read_in;
            mem_write_out <= mem_write_in;
            mem_to_reg_out <= mem_to_reg_in;
            reg_write_out <= reg_write_in;
            mem_size_out <= mem_size_in;
            rs2_out <= rs2;
            valid <= 1'b1;
            ex_finish <= 1'b1;
            branch_out <= branch_taken;
            branch_target_out <= branch_taken ? branch_target : (pc_in + 4);
        end else begin
            ex_finish <= 1'b0;
        end
    end

endmodule

`endif
