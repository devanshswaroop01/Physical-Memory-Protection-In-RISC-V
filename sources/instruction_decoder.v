// ----------------------------------------------------------------------------
// MODULE 1: Instruction_Decoder
// ----------------------------------------------------------------------------
/**
 * INSTRUCTION_DECODER - Extracts Fields from Instruction
 * 
 * PURPOSE:
 *   Extracts opcode, funct3, and funct7 fields
 *   Validates that opcode is a supported RISC-V opcode
 * 
 * INPUTS:
 *   instruction[31:0] - 32-bit RISC-V instruction
 * 
 * OUTPUTS:
 *   opcode[6:0] - Instruction opcode (bits 6:0)
 *   funct3[2:0] - Function field 3 (bits 14:12)
 *   funct7[6:0] - Function field 7 (bits 31:25)
 *   valid       - Instruction is valid RISC-V opcode
 * 
 * SUPPORTED OPCODES:
 *   7'b0110111 - LUI
 *   7'b0010111 - AUIPC
 *   7'b1101111 - JAL
 *   7'b1100111 - JALR
 *   7'b1100011 - Branch
 *   7'b0000011 - Load
 *   7'b0100011 - Store
 *   7'b0010011 - I-Type ALU
 *   7'b0110011 - R-Type ALU
 *   7'b0001111 - Fence
 *   7'b1110011 - System
 */
`timescale 1ns / 1ps

module Instruction_Decoder (
    input  wire [31:0] instruction,
    output wire [6:0]  opcode,
    output wire [2:0]  funct3,
    output wire [6:0]  funct7,
    output wire        valid
);

    // Field extraction
    assign opcode = instruction[6:0];
    assign funct3 = instruction[14:12];
    assign funct7 = instruction[31:25];

    // Opcode validation function
    function check_opcode;
        input [6:0] opcode_in;
        begin
            case (opcode_in)
                7'b0110111,  // LUI
                7'b0010111,  // AUIPC
                7'b1101111,  // JAL
                7'b1100111,  // JALR
                7'b1100011,  // Branch
                7'b0000011,  // Load
                7'b0100011,  // Store
                7'b0010011,  // I-Type
                7'b0110011,  // R-Type
                7'b0001111,  // Fence
                7'b1110011:  // System
                    check_opcode = 1'b1;
                default:
                    check_opcode = 1'b0;
            endcase
        end
    endfunction

    assign valid = check_opcode(opcode);

endmodule
 
