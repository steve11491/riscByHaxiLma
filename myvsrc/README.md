# myvsrc - 精简版五级流水线RISC-V处理器

## 项目概述

`myvsrc` 是一个精简版的五级流水线RISC-V处理器实现,从完整的RISCVfudan项目中提取核心功能而来。

## 核心功能

### 1. 五级流水线处理器核心
- **经典流水线设计**: 实现了标准的IF(取指) → ID(译码) → EX(执行) → MEM(访存) → WB(写回)五级流水线
- **数据冒险处理**: 完整的前递(Forwarding)机制,解决RAW数据相关性问题
- **控制冒险优化**: 简化的分支处理逻辑
- **结构冒险避免**: 哈佛结构设计,指令总线(IBus)与数据总线(DBus)分离

## 目录结构

```
myvsrc/
├── include/           # 头文件
│   ├── common.sv     # 通用定义和类型
│   └── config.sv     # 配置参数
├── src/              # 源文件
│   ├── core.sv       # 处理器核心(五级流水线集成)
│   ├── IF_stage.sv   # 取指阶段
│   ├── ID_stage.sv   # 译码阶段
│   ├── EX_stage.sv   # 执行阶段(包含前递机制)
│   ├── MEM_stage.sv  # 访存阶段
│   └── WB_stage.sv   # 写回阶段
├── util/             # 工具模块
│   ├── IBusToCBus.sv    # 指令总线转换
│   ├── DBusToCBus.sv    # 数据总线转换
│   └── CBusArbiter.sv   # 总线仲裁器
├── VTop.sv          # 顶层模块
├── SimTop.sv        # 仿真顶层模块
└── mycpu_top.sv     # 处理器顶层接口
```

## 支持的指令集

### 基础算术指令 (RV64I)
- **R-type**: ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND
- **I-type**: ADDI, SLLI, SLTI, SLTIU, XORI, SRLI, SRAI, ORI, ANDI
- **Load**: LB, LH, LW, LD, LBU, LHU, LWU
- **Store**: SB, SH, SW, SD
- **Branch**: BEQ, BNE, BLT, BGE, BLTU, BGEU
- **Jump**: JAL, JALR
- **Upper Imm**: LUI, AUIPC

## 主要特性

### 1. 前递机制 (Forwarding)
EX_stage实现了完整的前递机制,用于解决RAW(Read After Write)数据冒险:
- **WB → EX**: WB阶段的写回结果可以直接前递给EX阶段
- **MEM → EX**: MEM阶段的ALU结果可以前递给EX阶段
- 优先级: WB > MEM > 寄存器文件

### 2. 流水线控制
- **Block**: 当检测到数据冒险时,阻塞ID阶段的指令流动
- **Stall**: 流水线暂停信号(当前简化版本中未启用)
- **Finish signals**: 各阶段的完成信号用于同步流水线

### 3. 分支处理
- 支持所有标准分支指令的比较逻辑
- 分支目标地址计算
- 静态预测(默认不跳转)

## 与完整项目的区别

### 简化的功能
- ❌ 分支预测器 (BTB, BHT, RAS)
- ❌ CSR寄存器和特权级
- ❌ 异常和中断处理
- ❌ 原子指令 (AMO, LR/SC)
- ❌ 乘除法扩展 (M扩展)
- ❌ PMP内存保护
- ❌ MMU虚拟内存

### 保留的核心功能
- ✅ 五级流水线结构
- ✅ 前递机制
- ✅ 数据冒险检测
- ✅ 基本的分支处理
- ✅ Load/Store指令
- ✅ 算术逻辑运算

## 编译和仿真

### 使用Verilator
```bash
cd D:\project_PLF\RISCVfudan
verilator --cc myvsrc/SimTop.sv \
    --exe verilate/main.cpp \
    -I myvsrc/include \
    -I myvsrc/src \
    -I myvsrc/util \
    -DVERILATOR \
    -CFLAGS "-std=c++14"
```

### 仿真运行
```bash
./obj_dir/VSimTop +is_dump_wave=1
```

## 学习路线

1. **理解五级流水线**: 从 `core.sv` 开始,理解IF-ID-EX-MEM-WB的基本结构
2. **研究每个阶段**: 逐个阅读各阶段实现,重点关注:
   - `IF_stage.sv`: PC更新和指令获取
   - `ID_stage.sv`: 指令解码和立即数生成
   - `EX_stage.sv`: ALU运算和前递机制
   - `MEM_stage.sv`: 内存访问状态机
   - `WB_stage.sv`: 寄存器写回
3. **前递机制**: 深入理解 `EX_stage.sv` 中的前递逻辑
4. **总线接口**: 了解IBus/DBus和CBus的转换

## 变量命名一致性

所有变量名保持与原RISCVfudan项目一致,便于对照学习和理解:
- 流水线信号: `pc`, `instr`, `rd`, `rs1`, `rs2`, `imm`
- 控制信号: `reg_write`, `mem_read`, `mem_write`, `mem_to_reg`, `alu_src`, `branch`
- 阶段信号: `id_finish`, `ex_finish`, `mem_finish`, `if_finish`
- 完成信号: `finish_r`, `finish_w`

## 扩展功能

如果需要添加更多功能,可以参考原项目的实现:
1. **分支预测**: 参考 `vsrc/src/branch_predictor.sv`
2. **CSR和特权级**: 参考 `vsrc/include/csr.sv` 和 `vsrc/src/WB_stage.sv`
3. **异常处理**: 参考 `vsrc/src/IF_stage.sv` 和 `vsrc/src/WB_stage.sv`
4. **乘除法**: 参考 `vsrc/src/multiplier.sv` 和 `vsrc/src/divider.sv`

## 注意事项

1. 这是精简版本,仅用于学习和理解流水线基本原理
2. 未实现完整的异常和中断处理
3. 分支预测功能已简化,采用静态预测
4. 测试程序需要自行准备或从原项目中提取

## 许可证

本项目基于RISCVfudan项目修改,遵循原项目的许可证。
