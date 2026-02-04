
//----------------------------------------------------
// Arithmetic Logic Unit
// Performs all arithmetic and logical operations required by the RISC-V datapath
//-----------------------------------------------------
module ALU(
    input  [3:0]  alu_sel,     // ALU control signal selecting the operation
    input  [31:0] a_in,         // Operand A (from register file)
    input  [31:0] b_in,         // Operand B (register or immediate)
    output reg    carry_out,    // Carry flag (useful for unsigned operations)
    output reg    overflow,     // Overflow flag (signed arithmetic)
    output        zero,         // Zero flag (result == 0)
    output [31:0] alu_out       // ALU result
);

    // Internal registers for computation
    reg [31:0] alu_result;      // Final ALU result
    reg [32:0] temp;            // Extended register for carry detection
    reg [32:0] twos_com;        // Two’s complement helper for subtraction

    // Continuous assignments
    assign alu_out = alu_result;
    assign zero    = (alu_result == 32'b0);

    // Combinational ALU logic
    always @(*) begin
        // ---------------- Mandatory Initialization ----------------
        // Prevents inferred latches and ensures deterministic behavior
        alu_result = 32'b0;
        carry_out  = 1'b0;
        overflow   = 1'b0;
        temp       = 33'b0;
        twos_com   = 33'b0;

        // ---------------- Operation Selection ----------------
        case (alu_sel)

            4'b0000: // AND
                alu_result = a_in & b_in;

            4'b0001: // OR
                alu_result = a_in | b_in;

            4'b0010: begin // ADD (signed)
                alu_result = $signed(a_in) + $signed(b_in);
                temp       = {1'b0, a_in} + {1'b0, b_in};
                carry_out  = temp[32];

                // Signed overflow detection
                if ((a_in[31] & b_in[31] & ~alu_result[31]) |
                    (~a_in[31] & ~b_in[31] & alu_result[31]))
                    overflow = 1'b1;
            end

            4'b0110: begin // SUB (signed)
                alu_result = $signed(a_in) - $signed(b_in);
                twos_com   = {1'b0, ~b_in} + 1'b1;

                // Signed overflow detection for subtraction
                if ((a_in[31] & twos_com[31] & ~alu_result[31]) |
                    (~a_in[31] & ~twos_com[31] & alu_result[31]))
                    overflow = 1'b1;
            end

            4'b0111: // SLT (Set Less Than, signed)
                alu_result = ($signed(a_in) < $signed(b_in)) ? 32'd1 : 32'd0;

            4'b1100: // NOR
                alu_result = ~(a_in | b_in);

            4'b1111: // SEQ (Set Equal)
                alu_result = (a_in == b_in) ? 32'd1 : 32'd0;

            default: // Safe default
                alu_result = 32'b0;
        endcase
    end

endmodule
 
