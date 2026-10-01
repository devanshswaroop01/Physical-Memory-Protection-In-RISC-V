// ----------------------------------------------------------------------------
// MODULE 1: ALUController
// ----------------------------------------------------------------------------
/**
 * ALU CONTROLLER - Generates ALU Operation from Instruction Fields
 * 
 * PURPOSE:
 *   Maps instruction fields (ALU_Op, Funct3, Funct7) to ALU operation
 * 
 * ALU_OP ENCODING:
 *   2'b00 - Load/Store (ADD for address calculation)
 *   2'b01 - Branch (SUB for comparison)
 *   2'b10 - R-Type
 *   2'b11 - I-Type
 * 
 * OUTPUT OPERATION CODES:
 *   4'b0000 - AND
 *   4'b0001 - OR
 *   4'b0010 - ADD
 *   4'b0110 - SUB
 *   4'b0111 - SLT
 */
module ALUController (
    input  wire [1:0] ALU_Op,
    input  wire [2:0] Funct3,
    input  wire [6:0] Funct7,
    output reg  [3:0] Operation
);

    always @(*) begin
        // Default: ADD
        Operation = 4'b0010;

        case (ALU_Op)
            // ----------------------------------------------------------------
            // 2'b00: Load/Store - Use ADD for address calculation
            // ----------------------------------------------------------------
            2'b00: begin
                Operation = 4'b0010;
            end

            // ----------------------------------------------------------------
            // 2'b01: Branch - Use SUB for comparison
            // ----------------------------------------------------------------
            2'b01: begin
                Operation = 4'b0110;
            end

            // ----------------------------------------------------------------
            // 2'b10: R-Type Instructions
            // ----------------------------------------------------------------
            2'b10: begin
                case (Funct3)
                    3'b000: Operation = (Funct7[5]) ? 4'b0110 : 4'b0010; // SUB/ADD
                    3'b111: Operation = 4'b0000;  // AND
                    3'b110: Operation = 4'b0001;  // OR
                    3'b010: Operation = 4'b0111;  // SLT
                    default: Operation = 4'b0010;
                endcase
            end

            // ----------------------------------------------------------------
            // 2'b11: I-Type Instructions
            // ----------------------------------------------------------------
            2'b11: begin
                case (Funct3)
                    3'b000: Operation = 4'b0010;  // ADDI
                    3'b111: Operation = 4'b0000;  // ANDI
                    3'b110: Operation = 4'b0001;  // ORI
                    3'b010: Operation = 4'b0111;  // SLTI
                    default: Operation = 4'b0010;
                endcase
            end

            default: begin
                Operation = 4'b0010;
            end
        endcase
    end

endmodule
 
