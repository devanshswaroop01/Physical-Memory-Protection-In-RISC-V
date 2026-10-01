// ----------------------------------------------------------------------------
// MODULE 2: Control_Unit
// ----------------------------------------------------------------------------
/**
 * CONTROL UNIT - Generates Main Control Signals
 * 
 * PURPOSE:
 *   Decodes opcode and generates control signals for datapath
 * 
 * INPUTS:
 *   opcode[6:0] - Instruction opcode
 *   funct3[2:0] - Function field 3
 *   funct7[6:0] - Function field 7
 * 
 * OUTPUTS:
 *   reg_write  - Enable register write
 *   alu_src    - ALU source (0=register, 1=immediate)
 *   alu_cc     - ALU control code
 *   mem_read   - Enable memory read
 *   mem_write  - Enable memory write
 *   mem_to_reg - Writeback source (0=ALU, 1=memory)
 * 
 * INSTRUCTIONS SUPPORTED:
 *   R-Type: ADD, SUB, AND, OR, SLT
 *   I-Type: ADDI, ANDI, ORI, SLTI
 *   Load:   LW
 *   Store:  SW
 *   Jump:   JALR
 *   HALT:   JAL with rd=x0 (handled in datapath)
 */
`timescale 1ns / 1ps

module Control_Unit (
    input  wire [6:0] opcode,
    input  wire [2:0] funct3,
    input  wire [6:0] funct7,
    output reg        reg_write,
    output reg        alu_src,
    output reg  [3:0] alu_cc,
    output reg        mem_read,
    output reg        mem_write,
    output reg        mem_to_reg
);

    always @(*) begin
        // ----------------------------------------------------------------
        // Default Values
        // ----------------------------------------------------------------
        reg_write  = 1'b0;
        alu_src    = 1'b0;
        alu_cc     = 4'b0010;   // ADD
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        mem_to_reg = 1'b0;

        case (opcode)
            // ============================================================
            // R-Type Instructions (opcode = 7'b0110011)
            // ADD, SUB, AND, OR, SLT
            // ============================================================
            7'b0110011: begin
                reg_write = 1'b1;
                alu_src   = 1'b0;
                case (funct3)
                    3'b000: alu_cc = (funct7 == 7'b0100000) ? 4'b0110 : 4'b0010;
                    3'b111: alu_cc = 4'b0000;  // AND
                    3'b110: alu_cc = 4'b0001;  // OR
                    3'b010: alu_cc = 4'b0111;  // SLT
                    default: alu_cc = 4'b0010;
                endcase
            end

            // ============================================================
            // I-Type Instructions (opcode = 7'b0010011)
            // ADDI, ANDI, ORI, SLTI
            // ============================================================
            7'b0010011: begin
                reg_write = 1'b1;
                alu_src   = 1'b1;
                case (funct3)
                    3'b000: alu_cc = 4'b0010;  // ADDI
                    3'b111: alu_cc = 4'b0000;  // ANDI
                    3'b110: alu_cc = 4'b0001;  // ORI
                    3'b010: alu_cc = 4'b0111;  // SLTI
                    default: alu_cc = 4'b0010;
                endcase
            end

            // ============================================================
            // Load Word (opcode = 7'b0000011)
            // LW xN, offset(xM)
            // ============================================================
            7'b0000011: begin
                reg_write  = 1'b1;
                alu_src    = 1'b1;
                mem_read   = 1'b1;
                mem_to_reg = 1'b1;
                alu_cc     = 4'b0010;  // ADD for address
            end

            // ============================================================
            // Store Word (opcode = 7'b0100011)
            // SW xN, offset(xM)
            // ============================================================
            7'b0100011: begin
                alu_src   = 1'b1;
                mem_write = 1'b1;
                alu_cc    = 4'b0010;  // ADD for address
            end

            // ============================================================
            // JALR (opcode = 7'b1100111)
            // JALR xN, offset(xM)
            // ============================================================
            7'b1100111: begin
                reg_write = 1'b1;
                alu_src   = 1'b1;
                alu_cc    = 4'b0010;  // ADD for target address
            end

            // ============================================================
            // Default: NOP or Unsupported
            // ============================================================
            default: begin
                reg_write  = 1'b0;
                alu_src    = 1'b0;
                alu_cc     = 4'b0010;
                mem_read   = 1'b0;
                mem_write  = 1'b0;
                mem_to_reg = 1'b0;
            end
        endcase
    end

endmodule 
