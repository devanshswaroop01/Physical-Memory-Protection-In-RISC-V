
`timescale 1ns / 1ps

//--------------------------------------------------------
// PC Incrementer
// Computes next sequential PC = PC + 4
// Separated from PC register for clarity and reuse
//--------------------------------------------------------
module PC_Increment(
    input  wire [7:0] pc_current, // Current program counter
    output wire [7:0] pc_next      // Next sequential PC
);

    // RISC-V instructions are 4 bytes wide
    assign pc_next = pc_current + 8'd4;

endmodule

// PC register implemented using FlipFlop
