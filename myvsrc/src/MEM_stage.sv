`ifndef __MEM_STAGE_SV
`define __MEM_STAGE_SV

`ifdef VERILATOR
`include "include/common.sv"
`else

#endif

// 访存阶段模块 - 精简版
// 功能：处理内存读写操作，支持Load和Store指令
module MEM_stage
  import common::*;(
    input  logic         clk,               // 时钟信号
    input  logic         reset,             // 复位信号
    input  logic  [63:0] pc_in,             // PC输入
    input  logic  [63:0] result_in,         // ALU结果输入（内存地址或写入数据）
    input  logic         mem_read,          // 内存读使能
    input  logic         mem_write,         // 内存写使能
    input  logic  [63:0] write_data,        // 写入数据
    input  logic  [1:0]  mem_size,          // 内存访问大小
    output logic  [63:0] pc_out,            // PC输出
    output logic  [63:0] result_out,        // ALU结果输出（传递给WB）
    output logic  [63:0] mem_data_out,      // 内存读取数据输出
    input  logic  [31:0] instr_in,          // 指令输入
    output dbus_req_t    dbus_req,          // 数据总线请求
    input  dbus_resp_t   dbus_resp,         // 数据总线响应
    output logic         mem_exception,     // 内存异常信号
    input  logic         block,             // 阻塞信号
    output logic         finish_w,          // 写完成信号
    output logic         finish_r,          // 读完成信号
    input  logic  [4:0]  rd_in,             // 目标寄存器
    output logic  [4:0]  rd_out,            // 目标寄存器输出
    input  logic         reg_write_in,      // 寄存器写使能输入
    output logic         reg_write_out,     // 寄存器写使能输出
    input  logic         mem_to_reg_in,     // 内存到寄存器控制输入
    output logic         mem_to_reg_out,    // 内存到寄存器控制输出
    input  logic         ex_result_valid,   // EX结果有效
    output logic         mem_result_valid,  // MEM结果有效
    output logic  [31:0] instr_out,         // 指令输出
    output logic         mem_read_out,      // 内存读使能输出
    output logic         mem_write_out,     // 内存写使能输出
    output logic  [63:0] mem_addr_out,      // 内存地址输出
    input  logic         ex_finish,         // EX阶段完成
    output logic         mem_finish         // MEM阶段完成
);

    // 简化的状态机：只处理基本的内存读写
    enum logic [1:0] {
        IDLE,           // 空闲状态
        REQUEST_SENT,   // 已发送内存请求，等待响应
        RESPONSE_RECEIVED  // 收到内存响应
    } state;

    logic [63:0] mem_addr;
    logic [63:0] read_data;
    logic [1:0]  size_encoding;

    // 将mem_size转换为size编码
    always_comb begin
        case (mem_size)
            2'b00: size_encoding = MSIZE1;  // 字节
            2'b01: size_encoding = MSIZE2;  // 半字
            2'b10: size_encoding = MSIZE4;  // 字
            2'b11: size_encoding = MSIZE8;  // 双字
            default: size_encoding = MSIZE4;
        endcase
    end

    // 时序逻辑：内存访问状态机
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            pc_out <= 64'h0;
            result_out <= 64'h0;
            mem_data_out <= 64'h0;
            instr_out <= 32'h0;
            rd_out <= 5'h0;
            reg_write_out <= 1'b0;
            mem_to_reg_out <= 1'b0;
            mem_read_out <= 1'b0;
            mem_write_out <= 1'b0;
            mem_addr_out <= 64'h0;
            mem_exception <= 1'b0;
            finish_w <= 1'b0;
            finish_r <= 1'b0;
            mem_result_valid <= 1'b0;
            mem_finish <= 1'b0;
            dbus_req.valid <= 1'b0;
            dbus_req.addr <= 64'h0;
            dbus_req.data <= 64'h0;
            dbus_req.size <= MSIZE4;
            dbus_req.strobe <= 8'h0;
        end else if (block) begin
            // 阻塞状态
            finish_w <= 1'b0;
            finish_r <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    finish_w <= 1'b0;
                    finish_r <= 1'b0;

                    if (ex_finish && ex_result_valid) begin
                        // 保存输入信号
                        pc_out <= pc_in;
                        result_out <= result_in;
                        instr_out <= instr_in;
                        rd_out <= rd_in;
                        reg_write_out <= reg_write_in;
                        mem_to_reg_out <= mem_to_reg_in;
                        mem_read_out <= mem_read;
                        mem_write_out <= mem_write;
                        mem_addr_out <= result_in;
                        mem_addr <= result_in;

                        if (mem_read || mem_write) begin
                            // 发送内存请求
                            dbus_req.valid <= 1'b1;
                            dbus_req.addr <= result_in;
                            dbus_req.size <= size_encoding;

                            if (mem_write) begin
                                // 写操作
                                dbus_req.data <= write_data;
                                case (mem_size)
                                    2'b00: dbus_req.strobe <= 8'b00000001 << result_in[2:0];  // 字节
                                    2'b01: dbus_req.strobe <= 8'b00000011 << result_in[2:0];  // 半字
                                    2'b10: dbus_req.strobe <= 8'b00001111 << result_in[2:0];  // 字
                                    2'b11: dbus_req.strobe <= 8'b11111111;                 // 双字
                                    default: dbus_req.strobe <= 8'h0;
                                endcase
                            end else begin
                                // 读操作
                                dbus_req.data <= 64'h0;
                                dbus_req.strobe <= 8'h0;
                            end

                            state <= REQUEST_SENT;
                        end else begin
                            // 非内存访问指令，直接传递
                            mem_result_valid <= 1'b1;
                            mem_finish <= 1'b1;
                            finish_w <= 1'b1;
                        end
                    end else begin
                        mem_result_valid <= 1'b0;
                        mem_finish <= 1'b0;
                    end
                end

                REQUEST_SENT: begin
                    if (dbus_resp.addr_ok) begin
                        dbus_req.valid <= 1'b0;  // 清除请求
                    end

                    if (dbus_resp.data_ok) begin
                        // 收到内存响应
                        read_data <= dbus_resp.data;
                        mem_data_out <= dbus_resp.data;
                        mem_result_valid <= 1'b1;
                        mem_finish <= 1'b1;

                        if (mem_write) begin
                            finish_w <= 1'b1;
                        end else if (mem_read) begin
                            finish_r <= 1'b1;
                        end

                        state <= IDLE;
                    end else begin
                        finish_w <= 1'b0;
                        finish_r <= 1'b0;
                    end
                end

                RESPONSE_RECEIVED: begin
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule

`endif
