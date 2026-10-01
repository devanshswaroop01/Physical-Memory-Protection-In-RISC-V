

// ----------------------------------------------------------------------------
// MODULE 3: FlipFlop - Parameterized D Flip-Flop with Reset
// ----------------------------------------------------------------------------
/**
 * FLIPFLOP - D Flip-Flop with Synchronous Reset
 * 
 * PURPOSE:
 *   Stores state for Program Counter
 *   Updates on positive clock edge
 * 
 * PARAMETERS:
 *   WIDTH - Data width (default 8)
 * 
 * INPUTS:
 *   clk   - Clock signal (rising edge triggered)
 *   reset - Active-high reset
 *   d     - Data input
 * 
 * OUTPUTS:
 *   q     - Stored data
 * 
 * TIMING:
 *   - Reset is synchronous (sampled on clock edge)
 *   - Data captured on rising edge
 */
module FlipFlop #(
    parameter WIDTH = 8
)(
    input  wire             clk,
    input  wire             reset,
    input  wire [WIDTH-1:0] d,
    output reg  [WIDTH-1:0] q
);
    always @(posedge clk) begin
        if (reset)
            q <= {WIDTH{1'b0}};
        else
            q <= d;
