
`timescale 1ns/1ps

//-------------------------------- Register File -----------------------------
// Implements the RISC-V integer register file (x0–x31).
// - 32 registers, each 32-bit wide
// - Two asynchronous read ports
// - One synchronous write port
// - Register x0 is hardwired to zero (writes ignored)
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps

module RegFile(
    input        clk,            // Clock for synchronous write
    input        reset,          // Asynchronous reset
    input        rg_wrt_en,       // Register write enable
    input [4:0]  rg_wrt_addr,    // Destination register address
    input [4:0]  rg_rd_addr1,    // Source register 1 address
    input [4:0]  rg_rd_addr2,    // Source register 2 address
    input [31:0] rg_wrt_data,    // Data to be written
    output reg [31:0] rg_rd_data1, // Read data from source 1
    output reg [31:0] rg_rd_data2  // Read data from source 2
);

    // Internal storage for 32 general-purpose registers
    reg [31:0] register_file [0:31];
    integer i;

    // ---------------- Write & Reset Logic ----------------
    // Reset clears all registers to zero.
    // Writes occur on the rising edge of the clock.
    // Writes to register x0 are ignored to preserve RISC-V semantics.
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < 32; i = i + 1)
                register_file[i] <= 32'b0;
        end
        else if (rg_wrt_en && rg_wrt_addr != 5'd0) begin
            register_file[rg_wrt_addr] <= rg_wrt_data;
        end
    end    

    // ---------------- Read Logic ----------------
    // Asynchronous read: outputs reflect register contents immediately
    // based on the read addresses.
    always @(*) begin
        rg_rd_data1 <= register_file[rg_rd_addr1];
        rg_rd_data2 <= register_file[rg_rd_addr2];
    end

endmodule
