
//-----------------------------------Data Memory -----------------------------
// Implements word-addressed data memory for load/store operations.
// - 512 x 32-bit memory (2 KB total)
// - Synchronous writes (clocked)
// - Combinational reads
// - PMP enforcement is handled externally in the datapath
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps

module DataMem(
    input  wire        clk,        // Clock for synchronous writes
    input  wire        mem_read,   // Read enable
    input  wire        mem_write,  // Write enable
    input  wire [8:0]  addr,       // Word address (not byte address)
    input  wire [31:0] write_data, // Data to be written
    output reg  [31:0] read_data   // Data read from memory
);

    // 512-word data memory
    reg [31:0] data_memory [0:511];
    integer i;

    // ---------------- Memory Initialization ----------------
    // Memory is initialized for deterministic simulation and PMP testing.
    // Specific locations are preloaded to represent different PMP regions.
    initial begin
        // Clear entire memory
        for (i = 0; i < 512; i = i + 1)
            data_memory[i] = 32'b0;

        // Region 0: Read / Write / Execute allowed
        data_memory[0] = 32'h00000001;
        data_memory[1] = 32'h00000002;
        data_memory[2] = 32'h00000003;

        // Region 1: Read / Execute only (writes blocked by PMP)
        data_memory[256] = 32'h12345678;
        data_memory[257] = 32'h9ABCDEF0;
        data_memory[258] = 32'h11111111;
    end

    // ---------------- Synchronous Write ----------------
    // Write occurs on rising edge of clock when enabled.
    always @(posedge clk) begin
        if (mem_write && addr < 512) begin
            data_memory[addr] <= write_data;
        end
    end

    // ---------------- Combinational Read ----------------
    // Read data is immediately available when mem_read is asserted.
    always @(*) begin
        if (mem_read && addr < 512)
            read_data = data_memory[addr];
        else
            read_data = 32'b0;
    end

endmodule
