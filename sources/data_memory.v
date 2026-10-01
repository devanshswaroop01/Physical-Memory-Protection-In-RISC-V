// ============================================================================
// FILE: datamem.v
// DESCRIPTION: Data Memory with PMP Region Configuration
// ============================================================================
/**
 * DATAMEM - Data Memory
 * 
 * PURPOSE:
 *   Stores data with PMP region configuration
 *   Supports asynchronous read and synchronous write
 * 
 * PARAMETERS:
 *   MEM_DEPTH  - Number of words (default 512)
 *   DATA_WIDTH - Data width (default 32)
 *   ADDR_WIDTH - Address width (default 9)
 * 
 * INPUTS:
 *   clk        - Clock
 *   mem_read   - Read enable (gated by PMP)
 *   mem_write  - Write enable (gated by PMP)
 *   addr       - Word address
 *   write_data - Data to write
 * 
 * OUTPUTS:
 *   read_data  - Data read
 * 
 * PMP REGIONS:
 *   Region 0: 0x00-0x3F (R/W/X) - Data + Code
 *   Region 1: 0x40-0x7F (R/X)   - Read-only data
 *   Region 2: 0x80-0xBF (None)  - Protected
 *   Default:  0xC0-0xFF (None)  - Protected
 */
`timescale 1ns / 1ps

module DataMem #(
    parameter MEM_DEPTH  = 512,
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 9
)(
    input  wire                  clk,
    input  wire                  mem_read,
    input  wire                  mem_write,
    input  wire [ADDR_WIDTH-1:0] addr,
    input  wire [DATA_WIDTH-1:0] write_data,
    output reg  [DATA_WIDTH-1:0] read_data
);

    // Data memory array
    reg [DATA_WIDTH-1:0] data_memory [0:MEM_DEPTH-1];
    integer i;

    // ------------------------------------------------------------------------
    // Memory Initialization with PMP Region Data
    // ------------------------------------------------------------------------
    initial begin
        // Initialize all memory to zero
        for (i = 0; i < MEM_DEPTH; i = i + 1)
            data_memory[i] = {DATA_WIDTH{1'b0}};

        // ----------------------------------------------------------------
        // Region 0: 0x00-0x3F (R/W/X)
        // ----------------------------------------------------------------
        data_memory[0] = 32'h00000001;
        data_memory[1] = 32'h00000002;
        data_memory[2] = 32'h00000003;
        data_memory[3] = 32'h00000004;
        data_memory[4] = 32'h00000005;

        // ----------------------------------------------------------------
        // Region 1: 0x40-0x7F (R/X) - Read-only
        // ----------------------------------------------------------------
        data_memory[64]  = 32'h12345678;
        data_memory[65]  = 32'h9ABCDEF0;
        data_memory[66]  = 32'h11111111;
        data_memory[67]  = 32'h22222222;
        data_memory[68]  = 32'h33333333;

        // ----------------------------------------------------------------
        // Region 2: 0x80-0xBF (No Access)
        // ----------------------------------------------------------------
        data_memory[128] = 32'hDEADBEEF;
        data_memory[129] = 32'hCAFEBABE;
        data_memory[130] = 32'hBAADF00D;
        data_memory[131] = 32'hDEADBEEF;
        data_memory[132] = 32'hCAFEBABE;

        // ----------------------------------------------------------------
        // Default Region: 0xC0-0xFF (No Access)
        // ----------------------------------------------------------------
        data_memory[192] = 32'hFFFFFFFF;
        data_memory[193] = 32'hAAAAAAAA;
        data_memory[194] = 32'h55555555;

        // Display initialization
        $display("====================================");
        $display(" Data Memory Initialized");
        $display("====================================");
        $display("Region0 : 0x00 - 0x3F  (R/W/X)");
        $display("Region1 : 0x40 - 0x7F  (R/X)");
        $display("Region2 : 0x80 - 0xBF  (No Access)");
        $display("Default : 0xC0 - 0xFF (No Access)");
        $display("====================================");
    end

    // ------------------------------------------------------------------------
    // Asynchronous Read
    // ------------------------------------------------------------------------
    always @(*) begin
        read_data = {DATA_WIDTH{1'b0}};
        
        if (mem_read) begin
            if (addr < MEM_DEPTH) begin
                read_data = data_memory[addr];
                $display("DATA MEM READ : Addr=0x%h Data=0x%h Time=%0t",
                         addr, read_data, $time);
            end else begin
                $display("DATA MEM READ : INVALID Addr=0x%h Time=%0t",
                         addr, $time);
            end
        end
    end

    // ------------------------------------------------------------------------
    // Synchronous Write
    // ------------------------------------------------------------------------
    always @(posedge clk) begin
        if (mem_write) begin
            if (addr < MEM_DEPTH) begin
                data_memory[addr] <= write_data;
                $display("DATA MEM WRITE: Addr=0x%h Data=0x%h Time=%0t",
                         addr, write_data, $time);
            end else begin
                $display("DATA MEM WRITE: INVALID Addr=0x%h Time=%0t",
                         addr, $time);
            end
        end
    end

    // ------------------------------------------------------------------------
    // Read/Write Collision Warning
    // ------------------------------------------------------------------------
    always @(*) begin
        if (mem_read && mem_write) begin
            $display("WARNING: Simultaneous Read and Write Time=%0t", $time);
        end
    end

endmodule 
