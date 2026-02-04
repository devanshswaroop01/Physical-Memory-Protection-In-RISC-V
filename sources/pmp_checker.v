
//-----------------------------------  PMP_Checker -----------------------------
// Physical Memory Protection (PMP) Checker
//
// This module implements a priority-based PMP mechanism to control
// instruction and data access in a RISC-V processor.
//
// Functionality overview:
// - Matches the requested address against multiple PMP entries
// - Selects the highest-priority matching entry
// - Validates Read / Write / Execute permissions
// - Grants or denies access based on PMP configuration
//
// The logic is purely combinational and enforces a secure default-deny policy.
//
// Permission encoding:
//   active_perm[2] → Execute (X)
//   active_perm[1] → Write   (W)
//   active_perm[0] → Read    (R)
//-------------------------------------------------------------------------------

`timescale 1ns / 1ps

module PMP_Checker #(
    parameter PMP_ENTRIES = 4          // Number of PMP regions supported
)(
    input  wire [7:0] addr,            // Address to be checked
    input  wire       read_enable,     // Read access request
    input  wire       write_enable,    // Write access request
    input  wire       exec_enable,     // Execute access request
    output reg        access_granted   // Final PMP decision (1 = allow, 0 = deny)
);

    // ---------------- PMP ENTRY TABLE ----------------
    // Each PMP entry defines:
    // - A start and end address range
    // - Permission bits {Execute, Write, Read}
    // - An enable bit
    //
    // PMP entries are evaluated in ascending index order,
    // where Entry 0 has the highest priority.
    //--------------------------------------------------
    reg [7:0] pmp_start [0:PMP_ENTRIES-1];  // Region start addresses
    reg [7:0] pmp_end   [0:PMP_ENTRIES-1];  // Region end addresses
    reg [2:0] pmp_perm  [0:PMP_ENTRIES-1];  // Permissions {X, W, R}
    reg       pmp_en    [0:PMP_ENTRIES-1];  // Entry enable flags

    integer i;                  // Loop index
    reg hit;                    // Indicates a matching PMP entry
    reg [2:0] active_perm;      // Permissions of selected PMP entry

    // ---------------- INITIAL PMP CONFIGURATION ----------------
    // Static PMP configuration for simulation and demonstration.
    // In a full implementation, these values can be programmed
    // dynamically via Control and Status Registers (CSRs).
    //------------------------------------------------------------
    initial begin
        // Entry 0 : Full access (RWX) - highest priority region
        pmp_start[0] = 8'h00;
        pmp_end[0]   = 8'h3F;
        pmp_perm[0]  = 3'b111;
        pmp_en[0]    = 1'b1;

        // Entry 1 : Read and Execute only (RX)
        pmp_start[1] = 8'h40;
        pmp_end[1]   = 8'h7F;
        pmp_perm[1]  = 3'b101;
        pmp_en[1]    = 1'b1;

        // Entry 2 : No access region
        pmp_start[2] = 8'h80;
        pmp_end[2]   = 8'hBF;
        pmp_perm[2]  = 3'b000;
        pmp_en[2]    = 1'b1;

        // Entry 3 : Catch-all default deny region
        pmp_start[3] = 8'h00;
        pmp_end[3]   = 8'hFF;
        pmp_perm[3]  = 3'b000;
        pmp_en[3]    = 1'b1;
    end

    // ---------------- PMP MATCH & PERMISSION CHECK ----------------
    // This combinational block performs:
    // 1. Address range matching across PMP entries
    // 2. Priority-based entry selection (first match wins)
    // 3. Permission validation for requested access type
    //---------------------------------------------------------------
    always @(*) begin
        // Default initialization
        hit             = 1'b0;
        active_perm     = 3'b000;
        access_granted  = 1'b1;

        // -------- Address Match Phase --------
        // Scan PMP entries in priority order and select
        // the first enabled entry whose address range matches.
        for (i = 0; i < PMP_ENTRIES; i = i + 1) begin
            if (!hit &&
                pmp_en[i] &&
                (addr >= pmp_start[i]) &&
                (addr <= pmp_end[i])) begin

                hit          = 1'b1;
                active_perm  = pmp_perm[i];
            end
        end

        // -------- Permission Validation Phase --------
        // If a matching entry is found, validate requested
        // access type against its permission bits.
        if (hit) begin
            if (read_enable  && !active_perm[0]) access_granted = 1'b0;
            if (write_enable && !active_perm[1]) access_granted = 1'b0;
            if (exec_enable  && !active_perm[2]) access_granted = 1'b0;
        end
        else begin
            // No matching PMP entry → default deny
            access_granted = 1'b0;
        end

        // -------- Optional Debug Output --------
        // Displays PMP violations during simulation for visibility.
        if ((read_enable || write_enable || exec_enable) && !access_granted) begin
            $display("[%0t] PMP DENIED | Addr=0x%h R=%b W=%b X=%b",
                     $time, addr, read_enable, write_enable, exec_enable);
        end
    end

endmodule

 
