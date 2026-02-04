
`timescale 1ns / 1ps
//--------------------------------------------------------
// 2:1 Multiplexer (32-bit)
// Used extensively in the datapath for operand and write-back selection
//--------------------------------------------------------
module Mux2_1(
    input  wire        sel,
    input  wire [31:0] in0,
    input  wire [31:0] in1,
    output wire [31:0] out
);

    // -------- Functional Behavior --------
    // sel = 0 → out = in0
    // sel = 1 → out = in1
    // This is a purely combinational module.
    assign out = sel ? in1 : in0;

endmodule // Mux2_1
