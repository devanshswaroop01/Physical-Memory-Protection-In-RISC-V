
`timescale 1ns/1ps
//--------------------------------------------------------
// 8-bit Flip-Flop (Register)
// Used as the Program Counter (PC) register in the processor
//--------------------------------------------------------
module FlipFlop(clk, reset, d, q);

    // -------- I/O Signals --------
    // clk   : system clock
    // reset : synchronous reset (active high)
    // d     : next-state input
    // q     : registered output (current state)
    input       clk;
    input       reset;
    input [7:0] d;
    output reg [7:0] q;
 
    // -------- Functional Behavior --------
    // On every rising edge of the clock:
    // - If reset is asserted, clear the register to 0
    // - Otherwise, latch the input value 'd' into 'q'
    always @(posedge clk) begin
        if (reset) begin
            q <= 8'b0;   // Reset PC or register value
        end
        else begin
            q <= d;      // Normal state update
        end
    end

endmodule // FlipFlop
