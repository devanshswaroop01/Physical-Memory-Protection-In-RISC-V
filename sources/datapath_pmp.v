
`timescale 1ns/1ps

//----------------------------------- DATAPATH WITH PMP -----------------
// This module implements a single-cycle RISC-V datapath integrated with
// Physical Memory Protection (PMP).
//
// The datapath enforces security checks for:
//  - Instruction fetch (execute permission)
//  - Data memory access (read / write permissions)
//
// Design principles followed:
// 1. Instruction PMP violations are architectural → PC is frozen.
// 2. Illegal instruction fetches are squashed into NOPs to avoid side effects.
// 3. Data PMP violations block memory access without corrupting state.
//-------------------------------------------------------------------------------

`timescale 1ns / 1ps

module Datapath_PMP #(
    parameter PC_W      = 8,    // Program Counter width
    parameter INSTR_W   = 32,   // Instruction width
    parameter DATA_W    = 32,   // Datapath width
    parameter DM_ADDR_W = 9,    // Data memory address width
    parameter ALU_CC_W  = 4     // ALU control width
)(
    input                Clock,       // System clock
    input                Reset,       // Global reset
    input                Reg_Write,   // Register file write enable
    input                ALU_Src,     // ALU operand source select
    input [ALU_CC_W-1:0] ALU_CC,      // ALU control code
    input                Mem_Read,    // Data memory read enable
    input                Mem_Write,   // Data memory write enable
    input                Mem_to_Reg,  // Write-back source select

    output [2:0]          Funct3,      // Decoded funct3 field
    output [6:0]          Funct7,      // Decoded funct7 field
    output [6:0]          Opcode,      // Decoded opcode
    output [DATA_W-1:0]   Datapath_Result, // ALU result (for observation/debug)
    output                data_pmp_ok, // Data access PMP status
    output                instr_pmp_ok,// Instruction fetch PMP status
    output reg [PC_W-1:0] PC           // Program Counter
);

    //---------------- INTERNAL SIGNALS ----------------
    // PC and instruction handling
    wire [PC_W-1:0]    PC_Next;          // Next sequential PC
    wire [INSTR_W-1:0] Instruction;      // Raw instruction from memory
    wire [INSTR_W-1:0] Instruction_eff;  // Effective instruction after PMP

    // Execution datapath signals
    wire [31:0] Ext_Imm;                 // Sign-extended immediate
    wire [31:0] Reg1, Reg2;              // Register file read data
    wire [31:0] Src_B;                   // Selected ALU operand B
    wire [DATA_W-1:0] ALU_Result;        // ALU output
    wire [31:0] DataMem_Read;             // Data memory read output
    wire [31:0] Write_Back_Data;          // Final write-back value

    //---------------- PROGRAM COUNTER LOGIC ----------------
    // Computes PC + 4 for sequential execution
    PC_Increment PC_INC (
        .pc_current(PC),
        .pc_next(PC_Next)
    );

    // PC update behavior:
    // - Reset initializes PC to zero
    // - PC advances only if instruction PMP allows execution
    // - PC is frozen on instruction execute violation
    always @(posedge Clock) begin
        if (Reset)
            PC <= {PC_W{1'b0}};
        else if (instr_pmp_ok)
            PC <= PC_Next;
        else
            PC <= PC; // Hold PC on PMP execute violation
    end

    //---------------- INSTRUCTION FETCH ----------------
    // Fetch instruction from instruction memory using current PC
    InstrMem IMEM (
        .addr(PC),
        .instr(Instruction)
    );

    //---------------- INSTRUCTION PMP CHECK ----------------
    // Instruction fetch is treated as a read + execute operation.
    // PMP checker validates execute permission for current PC.
    PMP_Checker PMP_INSTR (
        .addr(PC),
        .read_enable(1'b1),
        .write_enable(1'b0),
        .exec_enable(1'b1),
        .access_granted(instr_pmp_ok)
    );

    // On instruction PMP violation, replace instruction with NOP
    // This prevents unintended register or memory side effects.
    assign Instruction_eff = instr_pmp_ok ? Instruction : 32'h00000013;

    //---------------- INSTRUCTION DECODE ----------------
    // Decode opcode and function fields from effective instruction
    Instruction_Decoder DEC (
        .instruction(Instruction_eff),
        .opcode(Opcode),
        .funct3(Funct3),
        .funct7(Funct7),
        .valid()
    );

    // Generate immediate value based on instruction format
    ImmGen IMM (
        .instr_code(Instruction_eff),
        .imm_out(Ext_Imm)
    );

    //---------------- REGISTER FILE ----------------
    // Register and memory operations are gated by instruction PMP status
    // This ensures no architectural updates occur after an execute violation.
    wire Reg_Write_eff = Reg_Write & instr_pmp_ok;
    wire Mem_Read_eff  = Mem_Read  & instr_pmp_ok;
    wire Mem_Write_eff = Mem_Write & instr_pmp_ok;

    RegFile RF (
        .clk(Clock),
        .reset(Reset),
        .rg_wrt_en(Reg_Write_eff),
        .rg_wrt_addr(Instruction_eff[11:7]),
        .rg_rd_addr1(Instruction_eff[19:15]),
        .rg_rd_addr2(Instruction_eff[24:20]),
        .rg_wrt_data(Write_Back_Data),
        .rg_rd_data1(Reg1),
        .rg_rd_data2(Reg2)
    );

    //---------------- ALU EXECUTION ----------------
    // Select ALU operand B:
    //  - Register operand for R-type
    //  - Immediate for I-type / load / store
    Mux2_1 MUX_EX (
        .sel(ALU_Src),
        .in0(Reg2),
        .in1(Ext_Imm),
        .out(Src_B)
    );

    // Perform arithmetic / logical operation
    ALU ALU_CORE (
        .alu_sel(ALU_CC),
        .a_in(Reg1),
        .b_in(Src_B),
        .alu_out(ALU_Result)
    );

    //---------------- DATA PMP CHECK ----------------
    // PMP check for data memory access:
    //  - Read permission for loads
    //  - Write permission for stores
    // Execute permission is not applicable for data memory.
    PMP_Checker PMP_DATA (
        .addr(ALU_Result[7:0]),
        .read_enable(Mem_Read_eff),
        .write_enable(Mem_Write_eff),
        .exec_enable(1'b0),
        .access_granted(data_pmp_ok)
    );

    //---------------- DATA MEMORY ACCESS ----------------
    // Memory access is fully gated by PMP decision.
    // Illegal accesses do not modify memory and return no valid data.
    DataMem DMEM (
        .clk(Clock),
        .mem_read(Mem_Read_eff & data_pmp_ok),
        .mem_write(Mem_Write_eff & data_pmp_ok),
        .addr(ALU_Result[DM_ADDR_W-1:0]),
        .write_data(Reg2),
        .read_data(DataMem_Read)
    );

    //---------------- WRITE BACK ----------------
    // Select write-back source:
    //  - ALU result for arithmetic instructions
    //  - Data memory output for load instructions
    Mux2_1 MUX_WB (
        .sel(Mem_to_Reg),
        .in0(ALU_Result),
        .in1(DataMem_Read),
        .out(Write_Back_Data)
    );

    // Expose ALU result externally for debugging / monitoring
    assign Datapath_Result = ALU_Result;

endmodule
