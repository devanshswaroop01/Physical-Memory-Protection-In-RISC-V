
`timescale 1ns / 1ps

//--------------------------- Immediate Generator ---------------------------
// Generates sign-extended immediate values for different RISC-V formats.
// Supports I, S, B, U, and J instruction types.
//-----------------------------------------------------------------------------
module ImmGen (
    input  wire [31:0] instr_code, // Instruction word
    output reg  [31:0] imm_out     // Decoded immediate
);

    always @(*) begin
        case (instr_code[6:0])

            // I-type immediates (ADDI, LW, JALR)
            7'b0010011,
            7'b0000011,
            7'b1100111:
                imm_out = {{20{instr_code[31]}}, instr_code[31:20]};

            // S-type immediates (SW)
            7'b0100011:
                imm_out = {{20{instr_code[31]}},
                            instr_code[31:25],
                            instr_code[11:7]};

            // B-type immediates (Branches)
            7'b1100011:
                imm_out = {{20{instr_code[31]}},
                            instr_code[7],
                            instr_code[30:25],
                            instr_code[11:8],
                            1'b0};

            // U-type immediates (LUI, AUIPC)
            7'b0110111,
            7'b0010111:
                imm_out = {instr_code[31:12], 12'b0};

            // J-type immediates (JAL)
            7'b1101111:
                imm_out = {{12{instr_code[31]}},
                            instr_code[19:12],
                            instr_code[20],
                            instr_code[30:21],
                            1'b0};

            // Unsupported instruction
            default:
                imm_out = 32'b0;
        endcase
    end

endmodule
