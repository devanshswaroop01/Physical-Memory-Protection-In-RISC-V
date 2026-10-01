// ----------------------------------------------------------------------------
// MODULE 2: ImmGen - Immediate Generator
// ----------------------------------------------------------------------------
/**
 * IMMGEN - RISC-V Immediate Generator
 * 
 * PURPOSE:
 *   Generates the appropriate immediate value based on instruction type
 * 
 * IMMEDIATE FORMATS:
 *   I-Type (ADDI, LW, JALR): {20{instr[31]}}, instr[31:20]
 *   S-Type (SW):             {20{instr[31]}}, instr[31:25], instr[11:7]
 *   B-Type (Branch):         {20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0
 *   U-Type (LUI, AUIPC):     instr[31:12], 12'b0
 *   J-Type (JAL):            {12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0
 * 
 * INPUTS:
 *   instr_code[31:0] - Full instruction
 * 
 * OUTPUTS:
 *   imm_out[31:0] - Sign-extended immediate
 */
`timescale 1ns / 1ps

module ImmGen #(
    parameter INSTR_WIDTH = 32,
    parameter DATA_WIDTH  = 32
)(
    input  wire [INSTR_WIDTH-1:0] instr_code,
    output reg  [DATA_WIDTH-1:0]  imm_out
);

    always @(*) begin
        case (instr_code[6:0])
            // I-Type: ADDI, LW, JALR
            7'b0010011,
            7'b0000011,
            7'b1100111: begin
                imm_out = {{20{instr_code[31]}}, instr_code[31:20]};
            end

            // S-Type: SW
            7'b0100011: begin
                imm_out = {{20{instr_code[31]}}, 
                           instr_code[31:25], 
                           instr_code[11:7]};
            end

            // B-Type: Branch
            7'b1100011: begin
                imm_out = {{20{instr_code[31]}}, 
                           instr_code[7], 
                           instr_code[30:25], 
                           instr_code[11:8], 
                           1'b0};
            end

            // U-Type: LUI, AUIPC
            7'b0110111,
            7'b0010111: begin
                imm_out = {instr_code[31:12], 12'b0};
            end

            // J-Type: JAL
            7'b1101111: begin
                imm_out = {{12{instr_code[31]}}, 
                           instr_code[19:12], 
                           instr_code[20], 
                           instr_code[30:21], 
                           1'b0};
            end

            // Default: Zero
            default: begin
                imm_out = {DATA_WIDTH{1'b0}};
            end
        endcase
    end

endmodule 
