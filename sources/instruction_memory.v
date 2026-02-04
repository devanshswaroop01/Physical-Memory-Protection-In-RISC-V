`timescale 1ns/1ps

//--------------------------- Instruction Memory ----------------------------
// Provides instruction fetch functionality.
// Uses word-aligned addressing (PC[7:2]) since each instruction is 4 bytes.
// Contains a small test program designed to verify PMP behavior.
//-----------------------------------------------------------------------------
module InstrMem(
    input wire [7:0] addr,      // Program Counter (byte address)
    output wire [31:0] instr     // Fetched instruction
);

    // 64-word instruction memory (64 x 32-bit)
    reg [31:0] memory [0:63];
    integer i;

    // ---------------- Initialization ----------------
    // Preloads a test program that exercises:
    //  - Legal accesses
    //  - PMP read violations
    //  - PMP write violations
    //  - PMP execute violations
    initial begin
        // Initialize all locations to NOP for safety
        for (i = 0; i < 64; i = i + 1)
            memory[i] = 32'h00000013; // RISC-V NOP (addi x0, x0, 0)

        // -------- Register Setup --------
        // Registers point to different PMP regions
        memory[0] = 32'h08000293; // x5 = 0x80 → Region 2 (NO ACCESS)
        memory[1] = 32'h04000313; // x6 = 0x40 → Region 1 (READ / EXECUTE)
        memory[2] = 32'h00000393; // x7 = 0x00 → Region 0 (RWX)
        memory[3] = 32'hC0000413; // x8 = 0xC0 → Default region (NO ACCESS)

        // -------- Legal Operations --------
        memory[4] = 32'h00100093; // addi x1, x0, 1
        memory[5] = 32'h0003A083; // lw x1, 0(x7) → legal read from Region 0

        // -------- PMP Violation Tests --------
        memory[6] = 32'h0002A103; // lw from Region 2 → READ violation
        memory[7] = 32'h00132023; // sw to Region 1 → WRITE violation

        // -------- Legal Register Operation --------
        memory[8] = 32'h003101b3; // add x3, x2, x3

        // -------- PMP Execute Violation --------
        memory[9]  = 32'h000280e7; // jalr to Region 2 → EXECUTE violation

        // -------- Default Region Violation --------
        memory[10] = 32'h00042083; // lw from 0xC0 → NO ACCESS

        // -------- Program End --------
        memory[11] = 32'h00000013;
        memory[12] = 32'h00000013;
        memory[13] = 32'h00000013;
    end

    // Word-aligned instruction fetch
    assign instr = memory[addr[7:2]];

endmodule
 
