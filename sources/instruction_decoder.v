 
`timescale 1ns / 1ps

//--------------------------- Instruction Decoder ---------------------------
// Extracts opcode and function fields from the instruction.
// Also performs a basic legality check on supported RISC-V opcodes.
//-----------------------------------------------------------------------------
module Instruction_Decoder(
    input  wire [31:0] instruction, // Current instruction
    output wire [6:0]  opcode,       // Instruction opcode
    output wire [2:0]  funct3,       // Function field (funct3)
    output wire [6:0]  funct7,       // Function field (funct7)
    output wire        valid         // Indicates supported instruction
);

    // Direct field extraction (pure combinational logic)
    assign opcode = instruction[6:0];
    assign funct3 = instruction[14:12];
    assign funct7 = instruction[31:25];

    // ---------------- Opcode Validity Check ----------------
    // Ensures only supported RISC-V instructions are treated as valid.
    function check_opcode;
        input [6:0] opcode_in;
        begin
            case (opcode_in)
                // U, J, I, B, R, Load, Store, System
                7'b0110111, // LUI
                7'b0010111, // AUIPC
                7'b1101111, // JAL
                7'b1100111, // JALR
                7'b1100011, // Branch
                7'b0000011, // Load
                7'b0100011, // Store
                7'b0010011, // I-type ALU
                7'b0110011, // R-type ALU
                7'b0001111, // Fence
                7'b1110011: // System
                    check_opcode = 1'b1;
                default:
                    check_opcode = 1'b0;
            endcase
        end
    endfunction

    assign valid = check_opcode(opcode);

endmodule
