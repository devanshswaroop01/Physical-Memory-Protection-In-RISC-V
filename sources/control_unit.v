
`timescale 1ns/1ps
//----------------------------------- Control Unit ----------------------------
// Generates all high-level control signals for the single-cycle RISC-V datapath.
// Decodes the opcode (and funct fields where required) to control:
//  - Register write-back
//  - ALU operand selection
//  - ALU operation
//  - Memory read/write
//  - Write-back data source
//
// This unit is purely combinational and defaults to a safe NOP-like state.
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps

module Control_Unit(
    input  wire [6:0] opcode,     // Instruction opcode
    input  wire [2:0] funct3,     // Function field (used for ALU ops)
    input  wire [6:0] funct7,     // Function field (used for ADD/SUB)
    output reg        reg_write,  // Enables register file write
    output reg        alu_src,    // Selects ALU operand (0=Reg2, 1=Immediate)
    output reg [3:0]  alu_cc,     // ALU control code
    output reg        mem_read,   // Enables data memory read
    output reg        mem_write,  // Enables data memory write
    output reg        mem_to_reg  // Selects write-back source (0=ALU, 1=Memory)
);

    always @(*) begin
        // ---------------- SAFE DEFAULTS ----------------
        // These defaults ensure a NOP-like behavior for
        // unsupported or invalid instructions.
        reg_write  = 1'b0;
        alu_src    = 1'b0;
        alu_cc     = 4'b0010; // Default ALU operation = ADD
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        mem_to_reg = 1'b0;

        case (opcode)

            // ---------------- R-TYPE INSTRUCTIONS ----------------
            // Examples: ADD, SUB, AND, OR, SLT
            // Operands come from registers, result written back.
            7'b0110011: begin
                reg_write = 1'b1;
                alu_src   = 1'b0;  // Use register operand
                case (funct3)
                    3'b000: alu_cc = funct7[5] ? 4'b0110 : 4'b0010; // SUB / ADD
                    3'b111: alu_cc = 4'b0000; // AND
                    3'b110: alu_cc = 4'b0001; // OR
                    3'b010: alu_cc = 4'b0111; // SLT
                    default: alu_cc = 4'b0010;
                endcase
            end

            // ---------------- I-TYPE INSTRUCTIONS ----------------
            // Example: ADDI
            // One register operand + immediate
            7'b0010011: begin
                reg_write = 1'b1;
                alu_src   = 1'b1;  // Use immediate
                alu_cc    = 4'b0010; // ADD
            end

            // ---------------- LOAD (LW) ----------------
            // Address = base register + immediate
            // Data loaded from memory is written back to register
            7'b0000011: begin
                reg_write  = 1'b1;
                alu_src    = 1'b1;
                mem_read   = 1'b1;
                mem_to_reg = 1'b1; // Select memory data for write-back
                alu_cc     = 4'b0010; // Address calculation
            end

            // ---------------- STORE (SW) ----------------
            // Address = base register + immediate
            // Data written to memory, no register write-back
            7'b0100011: begin
                alu_src   = 1'b1;
                mem_write = 1'b1;
                alu_cc    = 4'b0010;
            end

            // ---------------- JALR ----------------
            // Computes jump target using register + immediate
            // Writes return address to destination register
            7'b1100111: begin
                reg_write = 1'b1;
                alu_src   = 1'b1;
                alu_cc    = 4'b0010;
            end

            // ---------------- DEFAULT ----------------
            // Unsupported instructions behave as NOP
            default: ; 
        endcase
    end

endmodule
 
