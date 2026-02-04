
`timescale 1ns/1ps
//--------------------------------------------------------
// 8-bit HalfAdder
// Used for simple arithmetic such as PC increment logic
//--------------------------------------------------------
module HalfAdder(a, b, c_out, sum);

    // -------- I/O Signals --------
    // a, b  : 8-bit input operands
    // c_out : carry-out generated from addition
    // sum   : 8-bit sum result
    input  [7:0] a;
    input  [7:0] b;
    output       c_out;
    output [7:0] sum;
        
    // -------- Functional Behavior --------
    // Performs an 8-bit addition.
    // The concatenation captures both carry and sum in one operation.
    assign {c_out, sum} = a + b; 

endmodule // HalfAdder 
