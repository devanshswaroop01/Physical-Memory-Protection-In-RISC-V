
// ----------------------------------------------------------------------------
// MODULE 2: Mux2_1 - Parameterized 2-to-1 Multiplexer
// ----------------------------------------------------------------------------
/**
 * MUX2_1 - 2-to-1 Multiplexer (Parameterized Width)
 * 
 * PURPOSE:
 *   Selects between two inputs based on select signal
 *   Used for:
 *     - ALU source selection (register vs immediate)
 *     - Writeback selection (ALU result vs memory data)
 * 
 * PARAMETERS:
 *   WIDTH - Data width (default 32)
 * 
 * INPUTS:
 *   sel  - Select signal (0 = in0, 1 = in1)
 *   in0  - First input
 *   in1  - Second input
 * 
 * OUTPUTS:
 *   out  - Selected input
 */
`timescale 1ns / 1ps

module Mux2_1 #(
    parameter WIDTH = 32
)(
    input  wire             sel,
    input  wire [WIDTH-1:0] in0,
    input  wire [WIDTH-1:0] in1,
    output wire [WIDTH-1:0] out
);
    assign out = sel ? in1 : in0;
endmodule 
