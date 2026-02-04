
`timescale 1ns/1ps
//---------------------ALU Controller -------------------------
// Generates ALU operation codes based on instruction type
// Decouples instruction decoding from ALU implementation
//-------------------------------------------------------------
module ALUController (
    input  [1:0] ALU_Op,       // High-level ALU operation from main controller
    input  [2:0] Funct3,       // Instruction funct3 field
    input  [6:0] Funct7,       // Instruction funct7 field
    output reg [3:0] Operation // Final ALU control signal
);

    always @(*) begin
        // Default safe operation (AND)
        Operation = 4'b0000;

        case (ALU_Op)

            // Load / Store instructions → address calculation
            2'b00: begin
                Operation = 4'b0010; // ADD
            end

            // Branch instructions → comparison via subtraction
            2'b01: begin
                Operation = 4'b0110; // SUB
            end

            // R-type / I-type arithmetic instructions
            2'b10: begin
                case (Funct3)
                    3'b000: Operation = (Funct7[5]) ? 4'b0110 : 4'b0010; // SUB / ADD
                    3'b111: Operation = 4'b0000; // AND
                    3'b110: Operation = 4'b0001; // OR
                    3'b100: Operation = 4'b1100; // NOR
                    3'b010: Operation = 4'b0111; // SLT
                    default: Operation = 4'b0000;
                endcase
            end

            // Any undefined ALU_Op maps to safe default
            default: Operation = 4'b0000;
        endcase
    end

endmodule
