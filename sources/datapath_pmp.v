// ============================================================================
// FILE: datapath.v
// DESCRIPTION: Complete Processor Datapath with PMP Integration
// ============================================================================
/**
 * DATAPATH_PMP - Complete Processor Datapath
 * 
 * PURPOSE:
 *   Integrates all datapath components:
 *     - ALU
 *     - Register File
 *     - Instruction/Data Memory
 *     - PMP Checkers
 *     - Control Logic
 * 
 * PIPELINE STAGES (Single-Cycle):
 *   1. Fetch: Get instruction from memory
 *   2. Decode: Extract fields, generate immediate
 *   3. Execute: ALU operation
 *   4. Memory: Load/Store with PMP check
 *   5. Writeback: Update register file
 * 
 * FEATURES:
 *   - HALT detection (JAL with rd=x0)
 *   - JALR with LSB clearing
 *   - PMP gating for data and instruction accesses
 *   - RAW hazard forwarding in register file
 * 
 * PARAMETERS:
 *   PC_W           - Program counter width (default 8)
 *   INSTR_W        - Instruction width (default 32)
 *   DATA_W         - Data width (default 32)
 *   DM_ADDR_W      - Data memory address width (default 9)
 *   ALU_CC_W       - ALU control width (default 4)
 *   PMP_ADDR_WIDTH - PMP address width (default 8)
 */
`timescale 1ns / 1ps

module Datapath_PMP #(
    parameter PC_W           = 8,
    parameter INSTR_W        = 32,
    parameter DATA_W         = 32,
    parameter DM_ADDR_W      = 9,
    parameter ALU_CC_W       = 4,
    parameter PMP_ADDR_WIDTH = 8,
    // PMP region parameters
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
    // Control inputs
    input  wire                  Clock,
    input  wire                  Reset,
    input  wire                  Reg_Write,
    input  wire                  ALU_Src,
    input  wire [ALU_CC_W-1:0]   ALU_CC,
    input  wire                  Mem_Read,
    input  wire                  Mem_Write,
    input  wire                  Mem_to_Reg,
    
    // Outputs
    output wire [2:0]            Funct3,
    output wire [6:0]            Funct7,
    output wire [6:0]            Opcode,
    output wire [DATA_W-1:0]     Datapath_Result,
    output wire                  data_pmp_ok,
    output wire                  instr_pmp_ok,
    output wire [PC_W-1:0]       PC,
    output wire                  halt
);

    // ------------------------------------------------------------------------
    // Internal Signals
    // ------------------------------------------------------------------------
    wire [PC_W-1:0]     PC_Plus4;         // PC + 4
    wire [PC_W-1:0]     PC_Next;          // Next PC value
    wire [INSTR_W-1:0]  Instruction;      // Current instruction
    
    wire [DATA_W-1:0]   Ext_Imm;          // Sign-extended immediate
    wire [DATA_W-1:0]   Reg1;             // Register 1 data
    wire [DATA_W-1:0]   Reg2;             // Register 2 data
    wire [DATA_W-1:0]   Src_B;            // ALU B input (register or immediate)
    wire [DATA_W-1:0]   ALU_Result;       // ALU output
    wire [DATA_W-1:0]   DataMem_Read;     // Data memory read output
    wire [DATA_W-1:0]   Write_Back_Data;  // Data to write back to register file
    
    wire                mem_read_gated;   // PMP-gated read enable
    wire                mem_write_gated;  // PMP-gated write enable
    
    wire [PMP_ADDR_WIDTH-1:0] data_pmp_addr;  // Address for PMP check
    
    // ALU status flags (unused but available)
    wire alu_carry;
    wire alu_overflow;
    wire alu_zero;
    
    // HALT and JALR detection
    wire                halt_instruction;
    wire [6:0]          opcode_local;
    wire [4:0]          rd_local;
    wire                jalr_instr;
    wire [PC_W-1:0]     jalr_target;

    // ------------------------------------------------------------------------
    // Instruction Field Extraction
    // ------------------------------------------------------------------------
    assign opcode_local = Instruction[6:0];
    assign rd_local     = Instruction[11:7];

    // ------------------------------------------------------------------------
    // HALT Detection: JAL with rd=x0
    // ------------------------------------------------------------------------
    // A JAL instruction with rd=0 means "jump and discard return address"
    // This is used as HALT in our test program.
    // When HALT is detected, PC stays at current value.
    assign halt_instruction = (opcode_local == 7'b1101111) && (rd_local == 5'd0);

    // ------------------------------------------------------------------------
    // JALR Detection and Target Calculation
    // ------------------------------------------------------------------------
    assign jalr_instr = (Opcode == 7'b1100111);
    
    // JALR target: (rs1 + imm) with LSB cleared
    // This is required by RISC-V spec: "The indirect jump target 
    // address is obtained by adding the sign-extended 12-bit I-immediate 
    // to the value in rs1, and then setting the LSB of the result to zero."
    assign jalr_target = (jalr_instr) ? 
                         {ALU_Result[PC_W-1:1], 1'b0} :  // Clear LSB
                         PC_Plus4;

    // ------------------------------------------------------------------------
    // PC Next Logic
    // ------------------------------------------------------------------------
    // Priority: HALT > JALR > Sequential (PC+4)
    assign PC_Next = (halt_instruction) ? PC :            // HALT: stay
                     (jalr_instr)       ? jalr_target :   // JALR: jump
                     PC_Plus4;                            // Sequential

    // ------------------------------------------------------------------------
    // PMP Address for Data Access
    // ------------------------------------------------------------------------
    assign data_pmp_addr = ALU_Result[PMP_ADDR_WIDTH-1:0];

    // ------------------------------------------------------------------------
    // Module Instantiations
    // ------------------------------------------------------------------------

    // ========================================================================
    // ALU - Arithmetic Logic Unit
    // ========================================================================
    ALU #(
        .WIDTH(DATA_W)
    ) ALU_inst (
        .alu_sel(ALU_CC),
        .a_in(Reg1),
        .b_in(Src_B),
        .carry_out(alu_carry),
        .overflow(alu_overflow),
        .zero(alu_zero),
        .alu_out(ALU_Result)
    );

    // ========================================================================
    // Data PMP Checker
    // ========================================================================
    PMP_Checker #(
        .ADDR_WIDTH(PMP_ADDR_WIDTH),
        .REGION0_START(PMP_REGION0_START),
        .REGION0_END(PMP_REGION0_END),
        .REGION0_PERM(PMP_REGION0_PERM),
        .REGION1_START(PMP_REGION1_START),
        .REGION1_END(PMP_REGION1_END),
        .REGION1_PERM(PMP_REGION1_PERM),
        .REGION2_START(PMP_REGION2_START),
        .REGION2_END(PMP_REGION2_END),
        .REGION2_PERM(PMP_REGION2_PERM),
        .DEFAULT_PERM(PMP_DEFAULT_PERM)
    ) data_pmp_inst (
        .addr(data_pmp_addr),
        .read_enable(Mem_Read),
        .write_enable(Mem_Write),
        .execute_enable(1'b0),
        .access_granted(data_pmp_ok),
        .current_perm_out()
    );

    // ========================================================================
    // Instruction PMP Checker
    // ========================================================================
    PMP_Checker #(
        .ADDR_WIDTH(PC_W),
        .REGION0_START(PMP_REGION0_START),
        .REGION0_END(PMP_REGION0_END),
        .REGION0_PERM(PMP_REGION0_PERM),
        .REGION1_START(PMP_REGION1_START),
        .REGION1_END(PMP_REGION1_END),
        .REGION1_PERM(PMP_REGION1_PERM),
        .REGION2_START(PMP_REGION2_START),
        .REGION2_END(PMP_REGION2_END),
        .REGION2_PERM(PMP_REGION2_PERM),
        .DEFAULT_PERM(PMP_DEFAULT_PERM)
    ) instr_pmp_inst (
        .addr(PC),
        .read_enable(1'b0),
        .write_enable(1'b0),
        .execute_enable(1'b1),
        .access_granted(instr_pmp_ok),
        .current_perm_out()
    );

    // ========================================================================
    // PMP-Gated Memory Access
    // ========================================================================
    // Memory accesses are gated by PMP permission
    assign mem_read_gated  = Mem_Read  & data_pmp_ok;
    assign mem_write_gated = Mem_Write & data_pmp_ok;

    // ========================================================================
    // Data Memory
    // ========================================================================
    DataMem #(
        .MEM_DEPTH(512),
        .DATA_WIDTH(DATA_W),
        .ADDR_WIDTH(DM_ADDR_W)
    ) DataMem_inst (
        .clk(Clock),
        .mem_read(mem_read_gated),
        .mem_write(mem_write_gated),
        .addr(ALU_Result[DM_ADDR_W-1:0]),
        .write_data(Reg2),
        .read_data(DataMem_Read)
    );

    // ========================================================================
    // Instruction Memory
    // ========================================================================
    InstrMem #(
        .MEM_DEPTH(64),
        .INSTR_WIDTH(INSTR_W),
        .ADDR_WIDTH(PC_W)
    ) InstrMem_inst (
        .addr(PC),
        .instr(Instruction)
    );

    // ========================================================================
    // Instruction Decoder
    // ========================================================================
    Instruction_Decoder Decoder_inst (
        .instruction(Instruction),
        .opcode(Opcode),
        .funct3(Funct3),
        .funct7(Funct7),
        .valid()
    );

    // ========================================================================
    // Immediate Generator
    // ========================================================================
    ImmGen #(
        .INSTR_WIDTH(INSTR_W),
        .DATA_WIDTH(DATA_W)
    ) ImmGen_inst (
        .instr_code(Instruction),
        .imm_out(Ext_Imm)
    );

    // ========================================================================
    // Execute Stage MUX
    // Selects between register value and immediate for ALU B input
    // ========================================================================
    Mux2_1 #(
        .WIDTH(DATA_W)
    ) Mux_EX (
        .sel(ALU_Src),
        .in0(Reg2),
        .in1(Ext_Imm),
        .out(Src_B)
    );

    // ========================================================================
    // Writeback MUX
    // Selects between ALU result and memory data for register write
    // ========================================================================
    Mux2_1 #(
        .WIDTH(DATA_W)
    ) Mux_WB (
        .sel(Mem_to_Reg),
        .in0(ALU_Result),
        .in1(DataMem_Read),
        .out(Write_Back_Data)
    );

    // ========================================================================
    // Register File
    // ========================================================================
    RegFile #(
        .DATA_WIDTH(DATA_W),
        .REG_COUNT(32),
        .REG_ADDR_WIDTH(5)
    ) RegFile_inst (
        .clk(Clock),
        .reset(Reset),
        .rg_wrt_en(Reg_Write),
        .rg_wrt_addr(Instruction[11:7]),    // rd
        .rg_rd_addr1(Instruction[19:15]),   // rs1
        .rg_rd_addr2(Instruction[24:20]),   // rs2
        .rg_wrt_data(Write_Back_Data),
        .rg_rd_data1(Reg1),
        .rg_rd_data2(Reg2)
    );

    // ========================================================================
    // PC + 4 Adder
    // ========================================================================
    HalfAdder HalfAdder_inst (
        .a(PC),
        .b(8'd4),
        .sum(PC_Plus4)
    );

    // ========================================================================
    // PC Register
    // ========================================================================
    FlipFlop #(
        .WIDTH(PC_W)
    ) FlipFlop_inst (
        .clk(Clock),
        .reset(Reset),
        .d(PC_Next),
        .q(PC)
    );

    // ------------------------------------------------------------------------
    // Output Assignments
    // ------------------------------------------------------------------------
    assign Datapath_Result = ALU_Result;
    assign halt            = halt_instruction;

endmodule
