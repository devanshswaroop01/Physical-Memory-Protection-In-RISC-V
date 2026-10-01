// ============================================================================
// FILE: instrmem.v
// DESCRIPTION: Instruction Memory with PMP Test Program
// ============================================================================
/**
 * INSTRMEM - Instruction Memory
 * 
 * PURPOSE:
 *   Stores program instructions
 *   Pre-loaded with PMP test program
 * 
 * PARAMETERS:
 *   MEM_DEPTH   - Number of instructions (default 64)
 *   INSTR_WIDTH - Instruction width (default 32)
 *   ADDR_WIDTH  - Address width (default 8)
 * 
 * INPUTS:
 *   addr[ADDR_WIDTH-1:0] - Byte address (word-aligned)
 * 
 * OUTPUTS:
 *   instr[INSTR_WIDTH-1:0] - Fetched instruction
 * 
 * ADDRESSING:
 *   Uses addr[7:2] to index 32-bit words
 *   Byte address 0x00 → word 0
 *   Byte address 0x04 → word 1
 *   etc.
 * 
 * TEST PROGRAM:
 *   PMP violation test with 4 expected violations:
 *     #1: Load from Region2 (0x80) - READ denied
 *     #2: Store to Region1 (0x40) - WRITE denied
 *     #3: Execute from Region2 (0x80) - EXECUTE denied
 *     #4: Load from Default (0xC0) - READ denied
 *   Program ends with HALT (JAL x0, 0x58)
 */
`timescale 1ns / 1ps

module InstrMem #(
    parameter MEM_DEPTH   = 64,
    parameter INSTR_WIDTH = 32,
    parameter ADDR_WIDTH  = 8
)(
    input  wire [ADDR_WIDTH-1:0]  addr,
    output wire [INSTR_WIDTH-1:0] instr
);

    // Instruction memory array
    reg [INSTR_WIDTH-1:0] memory [0:MEM_DEPTH-1];
    integer i;

    // ------------------------------------------------------------------------
    // Memory Initialization
    // ------------------------------------------------------------------------
    initial begin
        // Initialize all to NOP
        for (i = 0; i < MEM_DEPTH; i = i + 1)
            memory[i] = 32'h00000013;  // NOP (addi x0, x0, 0)

        // ====================================================================
        // PMP TEST PROGRAM
        // ====================================================================
        
        // Setup addresses in registers
        memory[0]  = 32'h08000293;   // addi x5, x0, 0x80  (Region2 address)
        memory[1]  = 32'h04000313;   // addi x6, x0, 0x40  (Region1 address)
        memory[2]  = 32'h00000393;   // addi x7, x0, 0x00  (Region0 address)
        memory[3]  = 32'h0C000413;   // addi x8, x0, 0x0C0 (Default region)
        memory[4]  = 32'h00100093;   // addi x1, x0, 1     (Test value)
        
        // Allowed read from Region0
        memory[5]  = 32'h0003A083;   // lw x1, 0(x7)  - ALLOWED
        
        // Violation #1: Read from Region2
        memory[6]  = 32'h0002A103;   // lw x2, 0(x5)  - VIOLATION #1
        
        // Violation #2: Write to Region1
        memory[7]  = 32'h00132023;   // sw x1, 0(x6)  - VIOLATION #2
        
        // Allowed ALU operation
        memory[8]  = 32'h003101b3;   // add x3, x2, x3 - ALLOWED
        
        // Violation #4: Read from Default Region
        memory[9]  = 32'h00042083;   // lw x1, 0(x8)  - VIOLATION #4
        
        // Violation #3: Jump to Region2 (Execute)
        memory[10] = 32'h000280e7;   // jalr x1, x5, 0 - VIOLATION #3
        
        // HALT instruction
        memory[11] = 32'h0000006f;   // jal x0, 0x58 - HALT
        
        // HALT loop (target of HALT jump)
        memory[22] = 32'h0000006f;   // jal x0, 0x58 - HALT loop
        
        // Display initialization info
        $display("====================================");
        $display(" Instruction Memory Initialized");
        $display("====================================");
        $display("PMP Test Program Loaded");
        $display("  [0] addi x5, x0, 0x80");
        $display("  [1] addi x6, x0, 0x40");
        $display("  [2] addi x7, x0, 0x00");
        $display("  [3] addi x8, x0, 0x0C0");
        $display("  [4] addi x1, x0, 1");
        $display("  [5] lw x1, 0(x7)   - ALLOWED");
        $display("  [6] lw x2, 0(x5)   - VIOLATION #1");
        $display("  [7] sw x1, 0(x6)   - VIOLATION #2");
        $display("  [8] add x3, x2, x3");
        $display("  [9] lw x1, 0(x8)   - VIOLATION #4");
        $display("  [10] jalr x1, x5, 0 - VIOLATION #3");
        $display("  [11] jal x0, 0x58   - HALT");
        $display("====================================");
    end

    // Word-aligned access: addr[7:2] indexes 32-bit words
    assign instr = memory[addr[7:2]];

endmodule
