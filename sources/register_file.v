// ============================================================================
// FILE: regfile.v
// DESCRIPTION: RISC-V Register File with RAW Hazard Forwarding
// ============================================================================
/**
 * REGFILE - RISC-V Register File (32 x 32-bit)
 * 
 * PURPOSE:
 *   Implements RISC-V register file with:
 *     - 32 registers (x0-x31)
 *     - x0 hardwired to zero
 *     - Two read ports
 *     - One write port
 *     - RAW hazard forwarding
 * 
 * PARAMETERS:
 *   DATA_WIDTH     - Register width (default 32)
 *   REG_COUNT      - Number of registers (default 32)
 *   REG_ADDR_WIDTH - Address width (default 5)
 * 
 * INPUTS:
 *   clk          - Clock
 *   reset        - Reset (clears all registers)
 *   rg_wrt_en    - Write enable
 *   rg_wrt_addr  - Write address
 *   rg_rd_addr1  - Read address 1
 *   rg_rd_addr2  - Read address 2
 *   rg_wrt_data  - Write data
 * 
 * OUTPUTS:
 *   rg_rd_data1  - Read data 1
 *   rg_rd_data2  - Read data 2
 * 
 * RAW HAZARD HANDLING:
 *   If writing to same register being read in same cycle,
 *   forward the write data to the read port (bypass).
 *   This eliminates Read-After-Write hazard without stalling.
 * 
 * REGISTER CONVENTION (RISC-V ABI):
 *   x0  - Zero (hardwired)
 *   x1  - Return address (RA)
 *   x2  - Stack pointer (SP)
 *   x3  - Global pointer (GP)
 *   x4  - Thread pointer (TP)
 *   x5-x7  - Temporaries
 *   x8-x9  - Saved registers
 *   x10-x17 - Function arguments/results
 *   x18-x27 - Saved registers
 *   x28-x31 - Temporaries
 */
`timescale 1ns / 1ps

module RegFile #(
    parameter DATA_WIDTH     = 32,
    parameter REG_COUNT      = 32,
    parameter REG_ADDR_WIDTH = 5
)(
    input  wire                      clk,
    input  wire                      reset,
    input  wire                      rg_wrt_en,
    input  wire [REG_ADDR_WIDTH-1:0] rg_wrt_addr,
    input  wire [REG_ADDR_WIDTH-1:0] rg_rd_addr1,
    input  wire [REG_ADDR_WIDTH-1:0] rg_rd_addr2,
    input  wire [DATA_WIDTH-1:0]     rg_wrt_data,
    output reg  [DATA_WIDTH-1:0]     rg_rd_data1,
    output reg  [DATA_WIDTH-1:0]     rg_rd_data2
);

    // Register file storage
    reg [DATA_WIDTH-1:0] register_file [0:REG_COUNT-1];
    integer i;

    // ------------------------------------------------------------------------
    // Write Port (Synchronous)
    // ------------------------------------------------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // Reset all registers to zero
            for (i = 0; i < REG_COUNT; i = i + 1)
                register_file[i] <= {DATA_WIDTH{1'b0}};
        end else begin
            // x0 is always zero (hardwired)
            register_file[0] <= {DATA_WIDTH{1'b0}};
            
            // Write to register if enabled and not x0
            if (rg_wrt_en && (rg_wrt_addr != {REG_ADDR_WIDTH{1'b0}}))
                register_file[rg_wrt_addr] <= rg_wrt_data;
        end
    end

    // ------------------------------------------------------------------------
    // Read Ports (Combinational with RAW Hazard Forwarding)
    // ------------------------------------------------------------------------
    always @(*) begin
        // Default: Read from register file
        rg_rd_data1 = register_file[rg_rd_addr1];
        rg_rd_data2 = register_file[rg_rd_addr2];
        
        // RAW Hazard Forwarding:
        // If writing to same register being read in same cycle,
        // forward the write data directly (bypass register file)
        if (rg_wrt_en && (rg_wrt_addr != {REG_ADDR_WIDTH{1'b0}})) begin
            if (rg_wrt_addr == rg_rd_addr1)
                rg_rd_data1 = rg_wrt_data;
            if (rg_wrt_addr == rg_rd_addr2)
                rg_rd_data2 = rg_wrt_data;
        end
        
        // x0 always reads zero (even with forwarding)
        if (rg_rd_addr1 == {REG_ADDR_WIDTH{1'b0}})
            rg_rd_data1 = {DATA_WIDTH{1'b0}};
        if (rg_rd_addr2 == {REG_ADDR_WIDTH{1'b0}})
            rg_rd_data2 = {DATA_WIDTH{1'b0}};
    end

endmodule 
