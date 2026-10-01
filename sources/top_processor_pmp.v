// ============================================================================
// FILE: top_processor.v
// DESCRIPTION: Top-Level RISC-V Processor with PMP
// ============================================================================
/**
 * TOP_PROCESSOR_PMP - Top-Level RISC-V Processor with PMP
 * 
 * PURPOSE:
 *   Top-level module that integrates:
 *     - Control Unit
 *     - Datapath with PMP
 *   Provides external interface for testbench
 * 
 * PARAMETERS:
 *   XLEN           - Data width (default 32)
 *   PC_W           - Program counter width (default 8)
 *   DM_ADDR_W      - Data memory address width (default 9)
 *   ALU_CC_W       - ALU control width (default 4)
 *   PMP_ADDR_WIDTH - PMP address width (default 8)
 *   PMP_REGIONx_*  - PMP region configuration
 * 
 * INPUTS:
 *   Clock - System clock
 *   Reset - Active-high reset
 * 
 * OUTPUTS:
 *   ALU_Result_Out        - ALU result (debug)
 *   PC_Out                - Program counter (debug)
 *   Opcode_Out            - Current opcode (debug)
 *   Funct3_Out            - Current funct3 (debug)
 *   PMP_Violation_Detected - PMP violation flag
 *   Halt                  - HALT signal
 * 
 * USAGE:
 *   Top_Processor_PMP #(
 *       .XLEN(32),
 *       .PC_W(8),
 *       .PMP_REGION0_START(8'h00),
 *       // ... other parameters
 *   ) processor (
 *       .Clock(clk),
 *       .Reset(rst),
 *       // ... outputs
 *   );
 */
`timescale 1ns / 1ps

module Top_Processor_PMP #(
    parameter XLEN           = 32,
    parameter PC_W           = 8,
    parameter DM_ADDR_W      = 9,
    parameter ALU_CC_W       = 4,
    parameter PMP_ADDR_WIDTH = 8,
    // PMP Region Configuration
    parameter [PMP_ADDR_WIDTH-1:0] PMP_REGION0_START = 8'h00,
    parameter [PMP_ADDR_WIDTH-1:0] PMP_REGION0_END   = 8'h3F,
    parameter [PMP_ADDR_WIDTH-1:0] PMP_REGION1_START = 8'h40,
    parameter [PMP_ADDR_WIDTH-1:0] PMP_REGION1_END   = 8'h7F,
    parameter [PMP_ADDR_WIDTH-1:0] PMP_REGION2_START = 8'h80,
    parameter [PMP_ADDR_WIDTH-1:0] PMP_REGION2_END   = 8'hBF,
    parameter [2:0] PMP_REGION0_PERM = 3'b111,
    parameter [2:0] PMP_REGION1_PERM = 3'b101,
    parameter [2:0] PMP_REGION2_PERM = 3'b000,
    parameter [2:0] PMP_DEFAULT_PERM = 3'b000
)(
    // Clock and Reset
    input  wire              Clock,
    input  wire              Reset,
    
    // Debug Outputs
    output wire [XLEN-1:0]   ALU_Result_Out,
    output wire [PC_W-1:0]   PC_Out,
    output wire [6:0]        Opcode_Out,
    output wire [2:0]        Funct3_Out,
    
    // Status Outputs
    output wire              PMP_Violation_Detected,
    output wire              Halt
);

    // ------------------------------------------------------------------------
    // Internal Control Signals
    // ------------------------------------------------------------------------
    wire                  Reg_Write;
    wire                  ALU_Src;
    wire [ALU_CC_W-1:0]   ALU_CC;
    wire                  Mem_Read;
    wire                  Mem_Write;
    wire                  Mem_to_Reg;
    
    wire [2:0]            Funct3;
    wire [6:0]            Funct7;
    wire [6:0]            Opcode;
    wire [XLEN-1:0]       Datapath_Result;
    wire                  data_pmp_ok;
    wire                  instr_pmp_ok;
    wire                  halt_internal;

    // ------------------------------------------------------------------------
    // Control Unit
    // ------------------------------------------------------------------------
    Control_Unit control_unit (
        .opcode(Opcode),
        .funct3(Funct3),
        .funct7(Funct7),
        .reg_write(Reg_Write),
        .alu_src(ALU_Src),
        .alu_cc(ALU_CC),
        .mem_read(Mem_Read),
        .mem_write(Mem_Write),
        .mem_to_reg(Mem_to_Reg)
    );

    // ------------------------------------------------------------------------
    // Datapath with PMP
    // ------------------------------------------------------------------------
    Datapath_PMP #(
        .PC_W(PC_W),
        .INSTR_W(32),
        .DATA_W(XLEN),
        .DM_ADDR_W(DM_ADDR_W),
        .ALU_CC_W(ALU_CC_W),
        .PMP_ADDR_WIDTH(PMP_ADDR_WIDTH),
        .PMP_REGION0_START(PMP_REGION0_START),
        .PMP_REGION0_END(PMP_REGION0_END),
        .PMP_REGION0_PERM(PMP_REGION0_PERM),
        .PMP_REGION1_START(PMP_REGION1_START),
        .PMP_REGION1_END(PMP_REGION1_END),
        .PMP_REGION1_PERM(PMP_REGION1_PERM),
        .PMP_REGION2_START(PMP_REGION2_START),
        .PMP_REGION2_END(PMP_REGION2_END),
        .PMP_REGION2_PERM(PMP_REGION2_PERM),
        .PMP_DEFAULT_PERM(PMP_DEFAULT_PERM)
    ) datapath (
        .Clock(Clock),
        .Reset(Reset),
        .Reg_Write(Reg_Write),
        .ALU_Src(ALU_Src),
        .ALU_CC(ALU_CC),
        .Mem_Read(Mem_Read),
        .Mem_Write(Mem_Write),
        .Mem_to_Reg(Mem_to_Reg),
        .Funct3(Funct3),
        .Funct7(Funct7),
        .Opcode(Opcode),
        .Datapath_Result(Datapath_Result),
        .data_pmp_ok(data_pmp_ok),
        .instr_pmp_ok(instr_pmp_ok),
        .PC(PC_Out),
        .halt(halt_internal)
    );

    // ------------------------------------------------------------------------
    // Output Assignments
    // ------------------------------------------------------------------------
    assign ALU_Result_Out = Datapath_Result;
    assign Opcode_Out     = Opcode;
    assign Funct3_Out     = Funct3;
    
    // PMP violation: Either data or instruction access denied
    assign PMP_Violation_Detected = ~data_pmp_ok | ~instr_pmp_ok;
    
    assign Halt = halt_internal;

endmodule
