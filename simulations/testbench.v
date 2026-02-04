//---------------------------------FINAL TESTBENCH -----------------------------
// Testbench for RISC-V Processor with PMP support
//
// Purpose of this testbench:
//  - Generate clock and reset signals
//  - Instantiate the top-level PMP-enabled processor
//  - Monitor instruction and data PMP behavior
//  - Verify architectural correctness of PMP enforcement
//
// Key architectural properties verified:
//  1. Data PMP violations can occur before instruction violations
//     based on program order.
//  2. Instruction execute violation freezes the Program Counter (PC).
//  3. No further architectural side effects occur after PC halt.
//-------------------------------------------------------------------------------
`timescale 1ns / 1ps

module tb_Processor;

    // ---------------- Clock & Reset ----------------
    // Generates a 50 MHz clock and a global reset pulse
    reg clk;
    reg rst;

    // Clock generation: toggles every 10 ns
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    // Reset asserted initially, then deasserted
    initial begin
        rst = 1;
        #100;
        rst = 0;
    end

    // ---------------- DUT Outputs ----------------
    // Exposed signals from the processor for verification
    wire [7:0] PC_Out;                     // Program Counter
    wire       data_pmp_ok;                // Data PMP permission status
    wire       instr_pmp_ok;               // Instruction PMP permission status

    wire       instr_exec_violation;       // Instruction execute violation flag
    wire       data_read_violation;        // Data read violation flag
    wire       data_write_violation;       // Data write violation flag
    wire       PMP_Violation_Detected;     // Aggregate PMP violation flag

    // ---------------- DUT Instance ----------------
    // Instantiates the complete RISC-V processor with PMP support
    Top_Processor_PMP dut (
        .Clock(clk),
        .Reset(rst),
        .PC_Out(PC_Out),
        .data_pmp_ok(data_pmp_ok),
        .instr_pmp_ok(instr_pmp_ok),
        .instr_exec_violation(instr_exec_violation),
        .data_read_violation(data_read_violation),
        .data_write_violation(data_write_violation),
        .PMP_Violation_Detected(PMP_Violation_Detected)
    );

    // ---------------- Violation Counters ----------------
    // Used to track number and type of PMP violations
    integer instr_exec_violations = 0;
    integer data_read_violations  = 0;
    integer data_write_violations = 0;
    integer total_violations      = 0;

    // Latches ensure each violation is counted only once
    reg instr_latched = 0;
    reg data_latched  = 0;

    // PC tracking for halt verification
    reg [7:0] pc_hold;
    reg       halt_seen = 0;

    // ---------------- MAIN MONITOR ----------------
    // Observes PMP signals and validates architectural behavior
    always @(posedge clk) begin
        if (!rst) begin

            // ---- Instruction EXEC Violation Detection ----
            // Instruction execute violation must halt the processor
            if (instr_exec_violation && !instr_latched) begin
                instr_latched         <= 1'b1;
                instr_exec_violations <= instr_exec_violations + 1;
                total_violations      <= total_violations + 1;

                // Capture PC value at halt point
                pc_hold   <= PC_Out;
                halt_seen <= 1'b1;

                $display("[%0t] PMP EXEC VIOLATION at PC = 0x%h",
                         $time, PC_Out);
            end

            // ---- PC Stall Verification ----
            // Once an execute violation occurs, PC must not advance
            if (halt_seen && PC_Out !== pc_hold) begin
                $display("[%0t] ❌ ERROR: PC advanced after PMP halt!", $time);
                $finish;
            end

            // ---- Data READ Violation Detection ----
            // Data read violations are expected before instruction halt
            if (data_read_violation && !data_latched) begin
                data_latched         <= 1'b1;
                data_read_violations <= data_read_violations + 1;
                total_violations     <= total_violations + 1;

                $display("[%0t] PMP DATA READ VIOLATION at PC = 0x%h",
                         $time, PC_Out);
            end

            // ---- Data WRITE Violation Detection ----
            // Data write violations are monitored independently
            if (data_write_violation && !data_latched) begin
                data_latched          <= 1'b1;
                data_write_violations <= data_write_violations + 1;
                total_violations      <= total_violations + 1;

                $display("[%0t] PMP DATA WRITE VIOLATION at PC = 0x%h",
                         $time, PC_Out);
            end

            // Clear data latch once access becomes valid again
            if (data_pmp_ok)
                data_latched <= 1'b0;
        end
    end

    // ---------------- FINAL RESULT CHECK ----------------
    // Evaluates whether observed PMP behavior matches expectations
    initial begin
        $display("\n===============================================");
        $display("   PMP MULTI-ENTRY VERIFICATION TEST (FIXED)");
        $display("===============================================\n");

        #12000; // Allow full program execution

        $display("\n===============================================");
        $display("   SIMULATION SUMMARY");
        $display("===============================================");
        $display("Instruction EXEC Violations : %0d", instr_exec_violations);
        $display("Data READ Violations        : %0d", data_read_violations);
        $display("Data WRITE Violations       : %0d", data_write_violations);
        $display("Total PMP Violations        : %0d", total_violations);

        // Expected architectural outcome:
        //  - One data read violation (from protected region)
        //  - One instruction execute violation (halts execution)
        //  - No data violations after halt
        if (instr_exec_violations == 1 &&
            data_read_violations  == 1 &&
            data_write_violations == 0 &&
            total_violations      == 2) begin

            $display("\n✅ SUCCESS: PMP behavior is architecturally correct.");
        end
        else begin
            $display("\n❌ FAILURE: PMP behavior incorrect.");
        end

        $display("===============================================\n");
        $finish;
    end

    // ---------------- SAFETY TIMEOUT ----------------
    // Prevents simulation from running indefinitely
    initial begin
        #20000;
        $display("❌ ERROR: Simulation timeout");
        $finish;
    end

    // ---------------- WAVEFORM DUMP ----------------
    // Enables waveform viewing for post-simulation analysis
    initial begin
        $dumpfile("pmp_multi_entry_tb_fixed.vcd");
        $dumpvars(0, tb_Processor);
    end

endmodule
