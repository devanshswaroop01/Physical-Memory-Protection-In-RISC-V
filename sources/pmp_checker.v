// ============================================================================
// FILE: pmp_checker.v
// DESCRIPTION: Physical Memory Protection Checker
// ============================================================================
/**
 * PMP_CHECKER - Physical Memory Protection
 * 
 * PURPOSE:
 *   Enforces memory access permissions based on address regions
 *   Provides hardware security for protected memory areas
 * 
 * PERMISSION BITS:
 *   bit 0: R (Read)    - 1 = allowed, 0 = denied
 *   bit 1: W (Write)   - 1 = allowed, 0 = denied
 *   bit 2: X (Execute) - 1 = allowed, 0 = denied
 * 
 * REGION CONFIGURATION (Default):
 *   Region 0: 0x00-0x3F (R/W/X) - Full access
 *   Region 1: 0x40-0x7F (R/X)   - Read/Execute only
 *   Region 2: 0x80-0xBF (None)  - No access
 *   Default:  0xC0-0xFF (None)  - No access
 * 
 * PARAMETERS:
 *   ADDR_WIDTH       - Address width (default 8)
 *   REGIONx_START/END - Region boundaries
 *   REGIONx_PERM     - Permission bits
 *   DEFAULT_PERM     - Permission for unassigned region
 * 
 * INPUTS:
 *   addr            - Address to check
 *   read_enable     - Read access requested
 *   write_enable    - Write access requested
 *   execute_enable  - Execute access requested
 * 
 * OUTPUTS:
 *   access_granted  - 1 = allowed, 0 = denied
 *   current_perm_out - Current permission bits (debug)
 * 
 * BEHAVIOR:
 *   - First matching region determines permission
 *   - Violation logged when access denied
 *   - Denied accesses gate memory operations
 */
`timescale 1ns / 1ps

module PMP_Checker #(
    parameter ADDR_WIDTH = 8,
    // Region boundaries
    parameter [ADDR_WIDTH-1:0] REGION0_START = 8'h00,
    parameter [ADDR_WIDTH-1:0] REGION0_END   = 8'h3F,
    parameter [ADDR_WIDTH-1:0] REGION1_START = 8'h40,
    parameter [ADDR_WIDTH-1:0] REGION1_END   = 8'h7F,
    parameter [ADDR_WIDTH-1:0] REGION2_START = 8'h80,
    parameter [ADDR_WIDTH-1:0] REGION2_END   = 8'hBF,
    // Region permissions
    parameter [2:0] REGION0_PERM = 3'b111,  // R/W/X
    parameter [2:0] REGION1_PERM = 3'b101,  // R/X
    parameter [2:0] REGION2_PERM = 3'b000,  // None
    parameter [2:0] DEFAULT_PERM = 3'b000   // None
)(
    input  wire [ADDR_WIDTH-1:0] addr,
    input  wire                  read_enable,
    input  wire                  write_enable,
    input  wire                  execute_enable,
    output reg                   access_granted,
    output reg  [2:0]            current_perm_out
);

    reg [2:0] current_perm;

    always @(*) begin
        // ----------------------------------------------------------------
        // Region Detection (Priority: Region0 > Region1 > Region2 > Default)
        // ----------------------------------------------------------------
        if (addr >= REGION0_START && addr <= REGION0_END)
            current_perm = REGION0_PERM;
        else if (addr >= REGION1_START && addr <= REGION1_END)
            current_perm = REGION1_PERM;
        else if (addr >= REGION2_START && addr <= REGION2_END)
            current_perm = REGION2_PERM;
        else
            current_perm = DEFAULT_PERM;

        current_perm_out = current_perm;

        // ----------------------------------------------------------------
        // Permission Check Based on Access Type
        // ----------------------------------------------------------------
        if (execute_enable) begin
            // Execute: Check X bit
            access_granted = current_perm[2];
        end 
        else if (read_enable && !write_enable) begin
            // Read only: Check R bit
            access_granted = current_perm[0];
        end 
        else if (!read_enable && write_enable) begin
            // Write only: Check W bit
            access_granted = current_perm[1];
        end 
        else if (read_enable && write_enable) begin
            // Read + Write: Check both R and W
            access_granted = current_perm[0] & current_perm[1];
        end 
        else begin
            // No access requested
            access_granted = 1'b1;
        end

        // ----------------------------------------------------------------
        // Violation Logging
        // ----------------------------------------------------------------
        if ((read_enable || write_enable || execute_enable) && !access_granted) begin
            $display("[%0t] PMP DENIED Addr=0x%h R=%b W=%b X=%b Perm=%b",
                     $time, addr, read_enable, write_enable, 
                     execute_enable, current_perm);
        end
    end

endmodule
