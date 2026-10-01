// ============================================================================
// FILE: alu.v
// DESCRIPTION: Arithmetic Logic Unit for RISC-V Processor
// ============================================================================
/**
 * ALU - Arithmetic Logic Unit
 * 
 * PURPOSE:
 *   Performs arithmetic and logical operations for RISC-V instructions
 * 
 * OPERATIONS SUPPORTED (alu_sel):
 *   4'b0000 - AND    : Bitwise AND
 *   4'b0001 - OR     : Bitwise OR
 *   4'b0010 - ADD    : Addition with carry/overflow
 *   4'b0110 - SUB    : Subtraction with overflow
 *   4'b0111 - SLT    : Set Less Than (signed)
 *   4'b1100 - NOR    : Bitwise NOR
 *   4'b1111 - SEQ    : Set Equal (compare)
 * 
 * PARAMETERS:
 *   WIDTH - Data width (default 32)
 * 
 * INPUTS:
 *   alu_sel[3:0]    - Operation selector
 *   a_in[WIDTH-1:0] - First operand
 *   b_in[WIDTH-1:0] - Second operand
 * 
 * OUTPUTS:
 *   carry_out - Carry from addition (unsigned overflow)
 *   overflow  - Signed overflow flag
 *   zero      - Zero flag (result == 0)
 *   alu_out   - Operation result
 * 
 * FLAGS:
 *   carry_out : Set for unsigned addition overflow
 *   overflow  : Set for signed addition/subtraction overflow
 *   zero      : Set when result is zero (used for branches)
 */
`timescale 1ns / 1ps

module ALU #(
    parameter WIDTH = 32
)(
    input  wire [3:0]        alu_sel,
    input  wire [WIDTH-1:0]  a_in,
    input  wire [WIDTH-1:0]  b_in,
    output reg               carry_out,
    output reg               overflow,
    output wire              zero,
    output reg  [WIDTH-1:0]  alu_out
);

    // Internal signals
    reg [WIDTH-1:0] alu_result;
    reg [WIDTH:0]   temp;          // Extra bit for carry detection

    // Zero flag (combinational)
    assign zero = (alu_result == {WIDTH{1'b0}});

    always @(*) begin
        // Default values
        alu_result = {WIDTH{1'b0}};
        carry_out  = 1'b0;
        overflow   = 1'b0;
        temp       = {(WIDTH+1){1'b0}};

        case (alu_sel)
            // ----------------------------------------------------------------
            // AND Operation (4'b0000)
            // ----------------------------------------------------------------
            4'b0000: begin
                alu_result = a_in & b_in;
            end

            // ----------------------------------------------------------------
            // OR Operation (4'b0001)
            // ----------------------------------------------------------------
            4'b0001: begin
                alu_result = a_in | b_in;
            end

            // ----------------------------------------------------------------
            // ADD Operation (4'b0010)
            // ----------------------------------------------------------------
            // Carry detection: Use extra bit
            // Overflow detection: Same sign inputs, different sign output
            4'b0010: begin
                temp       = {1'b0, a_in} + {1'b0, b_in};
                alu_result = temp[WIDTH-1:0];
                carry_out  = temp[WIDTH];
                // Signed overflow: positive + positive = negative
                //                  negative + negative = positive
                overflow   = (a_in[WIDTH-1] &  b_in[WIDTH-1] & ~alu_result[WIDTH-1]) |
                             (~a_in[WIDTH-1] & ~b_in[WIDTH-1] &  alu_result[WIDTH-1]);
            end

            // ----------------------------------------------------------------
            // SUB Operation (4'b0110)
            // ----------------------------------------------------------------
            // Overflow: Different sign inputs, output differs from a_in
            4'b0110: begin
                alu_result = a_in - b_in;
                overflow   = (a_in[WIDTH-1] & ~b_in[WIDTH-1] & ~alu_result[WIDTH-1]) |
                             (~a_in[WIDTH-1] &  b_in[WIDTH-1] &  alu_result[WIDTH-1]);
            end

            // ----------------------------------------------------------------
            // SLT Operation (4'b0111) - Set Less Than (Signed)
            // ----------------------------------------------------------------
            4'b0111: begin
                alu_result = ($signed(a_in) < $signed(b_in)) ? 
                             {{WIDTH-1{1'b0}}, 1'b1} : {WIDTH{1'b0}};
            end

            // ----------------------------------------------------------------
            // NOR Operation (4'b1100)
            // ----------------------------------------------------------------
            4'b1100: begin
                alu_result = ~(a_in | b_in);
            end

            // ----------------------------------------------------------------
            // SEQ Operation (4'b1111) - Set Equal
            // ----------------------------------------------------------------
            4'b1111: begin
                alu_result = (a_in == b_in) ? 
                             {{WIDTH-1{1'b0}}, 1'b1} : {WIDTH{1'b0}};
            end

            // ----------------------------------------------------------------
            // Default: Output Zero
            // ----------------------------------------------------------------
            default: begin
                alu_result = {WIDTH{1'b0}};
            end
        endcase
    end

    // Output assignment
    assign alu_out = alu_result;

endmodule 
