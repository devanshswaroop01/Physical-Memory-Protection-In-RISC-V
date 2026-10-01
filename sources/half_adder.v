// ============================================================================
// FILE: basic_blocks.v
// DESCRIPTION: Basic Building Blocks for RISC-V Processor
// ============================================================================
/**
 * ============================================================================
 * MODULE LIST:
 * ============================================================================
 *   1. HalfAdder    - 8-bit Adder for PC+4
 *   2. Mux2_1       - Parameterized 2-to-1 Multiplexer
 *   3. FlipFlop     - Parameterized D Flip-Flop with Reset
 * ============================================================================
 */

// ----------------------------------------------------------------------------
// MODULE 1: HalfAdder - 8-bit Adder for PC+4
// ----------------------------------------------------------------------------
/**
 * HALFADDER - Simple 8-bit Adder
 * 
 * PURPOSE:
 *   Computes PC + 4 for sequential instruction fetch
 *   Despite the name, this is a full adder (computes a + b)
 * 
 * INPUTS:
 *   a[7:0] - First operand (usually PC)
 *   b[7:0] - Second operand (usually 4)
 * 
 * OUTPUTS:
 *   sum[7:0] - Result (PC+4)
 * 
 * NOTE:
 *   No carry output - overflow beyond 8 bits is ignored
 *   This is acceptable since instruction memory is 256 bytes
 */
module HalfAdder(
    input  [7:0] a,
    input  [7:0] b,
    output [7:0] sum
);
    assign sum = a + b;
endmodule

    end
endmodule
