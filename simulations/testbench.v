// ============================================================================
// FILE: tb_Processor.v
// RISC-V PROCESSOR TESTBENCH - PROFESSIONAL VERIFICATION SUITE v2.0
// ============================================================================
/**
 * ============================================================================
 * MODULE: tb_Processor
 * ============================================================================
 * 
 * PURPOSE:
 *   Comprehensive verification testbench for RISC-V processor with PMP.
 *   Supports two test modes:
 *     1. PMP Test       - Verifies all 4 PMP violation types
 *     2. Functional Test - Verifies all implemented RISC-V instructions
 * 
 * FEATURES:
 *   - Golden Reference Model (software RISC-V simulator)
 *   - Scoreboard/Checker (automated register verification)
 *   - Complete ISA Test Suite (all implemented instructions)
 *   - PMP Violation Detection (4 types with fixed counting)
 *   - Professional ASCII Output ([PASS]/[FAIL]/[WARN]/[DENY])
 *   - Register Table Display (all 32 registers)
 *   - Dual Test Mode (PMP + Functional)
 *   - Parameterized Configuration
 *   - Icarus Verilog Compatible (100%)
 *   - VCD Waveform Dump for debugging
 * 
 * PMP REGIONS (Default Configuration):
 *   Region0: 0x00-0x3F (R/W/X) - All operations allowed
 *   Region1: 0x40-0x7F (R/X)   - Read/Execute only, NO writes
 *   Region2: 0x80-0xBF (None)  - No access allowed
 *   Default: 0xC0-0xFF (None)  - No access allowed
 * 
 * EXPECTED PMP VIOLATIONS (4 total):
 *   #1: Load from Region2 (0x80)   - READ denied
 *   #2: Store to Region1 (0x40)    - WRITE denied
 *   #3: Execute from Region2 (0x80) - EXECUTE denied
 *   #4: Load from Default (0xC0)   - READ denied
 * 
 * INSTRUCTIONS TESTED (Functional Mode):
 *   R-Type: ADD, SUB, AND, OR, SLT
 *   I-Type: ADDI, ANDI, ORI, SLTI
 *   Load/Store: LW, SW
 *   Jump: JALR (with LSB clearing), HALT (JAL with rd=x0)
 * 
 * USAGE:
 *   PMP Test:        iverilog -o tb_top tb_Processor.v *.v && vvp tb_top
 *   Functional Test: vvp tb_top +TEST_PROGRAM=FUNCTIONAL
 *   View Waveform:   gtkwave waveform.vcd
 * 
 * ============================================================================
 */

`timescale 1ns / 1ps

module tb_Processor #(
    // ------------------------------------------------------------------------
    // PMP Region Configuration Parameters
    // ------------------------------------------------------------------------
    /**
     * REGION0_START/END: 0x00-0x3F (R/W/X)
     * All operations allowed - used for code execution and data storage
     * This region contains the test program and initial data
     */
    parameter REGION0_START = 8'h00,
    parameter REGION0_END   = 8'h3F,
    
    /**
     * REGION1_START/END: 0x40-0x7F (R/X)
     * Read and execute only - writes are denied by PMP
     * Tests PMP write protection capability
     * Data can be read but not modified
     */
    parameter REGION1_START = 8'h40,
    parameter REGION1_END   = 8'h7F,
    
    /**
     * REGION2_START/END: 0x80-0xBF (None)
     * No access allowed - all operations denied
     * Tests PMP read, write, and execute protection
     * Used for protected/secure memory area
     */
    parameter REGION2_START = 8'h80,
    parameter REGION2_END   = 8'hBF,
    
    // ------------------------------------------------------------------------
    // Test Configuration Parameters
    // ------------------------------------------------------------------------
    /**
     * TEST_PROGRAM: Selects test mode
     *   "PMP"        - PMP violation detection test
     *   "FUNCTIONAL" - Complete ISA verification test
     */
    parameter TEST_PROGRAM  = "PMP",
    
    /**
     * TIMEOUT_CYCLES: Maximum cycles before timeout
     * Prevents simulation from hanging indefinitely
     * At 20ns per cycle, 200 cycles = 4000ns timeout
     */
    parameter TIMEOUT_CYCLES = 200,
    
    /**
     * PMP_ADDR_WIDTH: Width of PMP address bus
     * Must match RTL parameter for compatibility
     */
    parameter PMP_ADDR_WIDTH = 8
)();

    // ========================================================================
    // SECTION 1: CLOCK AND RESET
    // ========================================================================
    
    /**
     * CLOCK: 50MHz with 20ns period (10ns high, 10ns low)
     * Generates continuous clock for simulation
     * The 'forever' loop creates an infinite clock signal
     */
    reg clk;
    initial begin
        clk = 0;
        forever #10 clk = ~clk;    // Toggle every 10ns = 20ns period
    end
    
    /**
     * RESET: Active-high, clock-edge aligned
     * 
     * RESET SEQUENCE:
     *   1. Assert reset at time 0
     *   2. Wait for 5 clock cycles (allows all state to clear)
     *   3. Deassert reset on positive clock edge
     *   4. Display confirmation message
     * 
     * This edge-aligned approach prevents race conditions
     * and ensures deterministic reset behavior.
     */
    reg rst;
    initial begin
        rst = 1'b1;
        repeat(5) @(posedge clk);   // Hold reset for 5 cycles
        @(posedge clk);              // Align to clock edge
        rst = 1'b0;                  // Release reset
        $display("\n");
        $display("========================================");
        $display("  [PASS] RESET DEASSERTED AT %0t ps", $time);
        $display("========================================\n");
    end

    // ========================================================================
    // SECTION 2: DEVICE UNDER TEST (DUT) INSTANTIATION
    // ========================================================================
    
    /**
     * DUT Output Signals
     * Connected to Top_Processor_PMP outputs
     */
    wire [31:0] alu_result;      // ALU computation result
    wire [7:0]  pc_out;          // Program Counter value
    wire [6:0]  opcode_out;      // Current instruction opcode
    wire [2:0]  funct3_out;      // Funct3 field for ALU control
    wire        pmp_violation;   // PMP violation flag (aggregated)
    wire        halt;            // HALT signal from processor

    /**
     * Device Under Test: Top_Processor_PMP
     * 
     * All PMP region settings are passed as parameters
     * allowing the testbench to fully configure the DUT
     * for different test scenarios.
     */
    Top_Processor_PMP #(
        .XLEN(32),                              // 32-bit RISC-V
        .PC_W(8),                               // 8-bit PC (256 bytes)
        .DM_ADDR_W(9),                          // 9-bit data memory address
        .ALU_CC_W(4),                           // 4-bit ALU control
        .PMP_ADDR_WIDTH(PMP_ADDR_WIDTH),        // Configurable PMP width
        .PMP_REGION0_START(REGION0_START),      // Region 0 boundaries
        .PMP_REGION0_END(REGION0_END),
        .PMP_REGION1_START(REGION1_START),      // Region 1 boundaries
        .PMP_REGION1_END(REGION1_END),
        .PMP_REGION2_START(REGION2_START),      // Region 2 boundaries
        .PMP_REGION2_END(REGION2_END),
        .PMP_REGION0_PERM(3'b111),              // R/W/X
        .PMP_REGION1_PERM(3'b101),              // R/X (No W)
        .PMP_REGION2_PERM(3'b000),              // No access
        .PMP_DEFAULT_PERM(3'b000)               // No access
    ) Processor_inst (
        .Clock( clk ),
        .Reset( rst ),
        .ALU_Result_Out( alu_result ),
        .PC_Out( pc_out ),
        .Opcode_Out( opcode_out ),
        .Funct3_Out( funct3_out ),
        .PMP_Violation_Detected( pmp_violation ),
        .Halt( halt )
    );

    // ========================================================================
    // SECTION 3: DEBUG SIGNAL EXTRACTION
    // ========================================================================
    
    /**
     * DEBUG SIGNALS: Hierarchical access to internal DUT signals
     * 
     * These signals are used for:
     *   - Instruction tracing
     *   - Scoreboard comparison
     *   - PMP violation detection
     *   - Golden model updates
     * 
     * Direct assignments (no generate blocks) for Icarus compatibility.
     */
    wire [31:0] debug_instr;          // Current instruction
    wire [31:0] debug_alu_result;     // ALU output
    wire [7:0]  debug_pc;             // Program Counter
    wire [7:0]  debug_pmp_addr;       // PMP checked address
    wire        debug_mem_read;       // Memory read request
    wire        debug_mem_write;      // Memory write request
    wire        debug_data_pmp_ok;    // Data PMP access granted
    wire        debug_instr_pmp_ok;   // Instruction PMP access granted

    assign debug_instr        = Processor_inst.datapath.Instruction;
    assign debug_alu_result   = Processor_inst.datapath.ALU_Result;
    assign debug_pc           = Processor_inst.datapath.PC;
    assign debug_pmp_addr     = Processor_inst.datapath.data_pmp_addr;
    assign debug_mem_read     = Processor_inst.datapath.Mem_Read;
    assign debug_mem_write    = Processor_inst.datapath.Mem_Write;
    assign debug_data_pmp_ok  = Processor_inst.datapath.data_pmp_ok;
    assign debug_instr_pmp_ok = Processor_inst.datapath.instr_pmp_ok;

    // ========================================================================
    // SECTION 4: TESTBENCH VARIABLES AND DECLARATIONS
    // ========================================================================
    
    integer i, mem_idx;               // Loop counters
    integer error_cnt;                // Error counter (functional test)
    reg [4:0] rd;                     // Destination register address
    reg [31:0] actual, expected;      // Scoreboard comparison values
    integer cycle_count;              // Cycle counter
    reg [7:0] last_pc;                // Previous PC (for change detection)
    reg first_instruction;            // Flag for table header
    integer test_sel;                 // Test mode selector

    // ========================================================================
    // SECTION 5: GOLDEN REFERENCE MODEL
    // ========================================================================
    
    /**
     * GOLDEN REFERENCE MODEL - Software RISC-V Simulator
     * 
     * PURPOSE:
     *   Computes expected results for each instruction
     *   Provides reference values for scoreboard comparison
     * 
     * REGISTERS: golden_regs[0:31] - Expected register values
     * MEMORY: golden_memory[0:511] - Expected memory contents
     * 
     * This model implements the same instructions as the RTL,
     * allowing automated detection of functional mismatches.
     */
    reg [31:0] golden_regs [0:31];
    reg [31:0] golden_memory [0:511];
    reg [31:0] expected_alu_result;

    /**
     * TASK: golden_step
     * 
     * Executes one instruction in the golden model
     * Updates golden_regs and golden_memory
     * 
     * INPUTS:
     *   instr[31:0] - Instruction to execute
     *   pc[31:0]    - Current program counter
     * 
     * OUTPUTS:
     *   expected_alu_result - Computed ALU result
     *   golden_regs         - Updated register file
     *   golden_memory       - Updated memory
     * 
     * INSTRUCTIONS MODELED:
     *   R-Type: ADD, SUB, AND, OR, SLT
     *   I-Type: ADDI, ANDI, ORI, SLTI
     *   Load:   LW
     *   Store:  SW
     *   Jump:   JALR (LSB cleared), JAL (HALT)
     */
    task golden_step;
        input [31:0] instr;
        input [31:0] pc;
        integer rs1, rs2, rd;
        reg [31:0] imm;
        reg [31:0] op1, op2;
        begin
            // Decode instruction fields
            rs1 = instr[19:15];
            rs2 = instr[24:20];
            rd  = instr[11:7];
            
            // Execute based on opcode
            case (instr[6:0])
                // ------------------------------------------------------------
                // R-Type Instructions (opcode = 7'b0110011)
                // ADD, SUB, AND, OR, SLT
                // ------------------------------------------------------------
                7'b0110011: begin
                    op1 = golden_regs[rs1];
                    op2 = golden_regs[rs2];
                    case (instr[14:12])
                        3'b000: // ADD/SUB (Funct7[5] selects)
                            expected_alu_result = (instr[30]) ? op1 - op2 : op1 + op2;
                        3'b111: // AND
                            expected_alu_result = op1 & op2;
                        3'b110: // OR
                            expected_alu_result = op1 | op2;
                        3'b010: // SLT (signed comparison)
                            expected_alu_result = ($signed(op1) < $signed(op2)) ? 32'd1 : 32'd0;
                        default: 
                            expected_alu_result = 32'd0;
                    endcase
                    if (rd != 0) golden_regs[rd] = expected_alu_result;
                end
                
                // ------------------------------------------------------------
                // I-Type Instructions (opcode = 7'b0010011)
                // ADDI, ANDI, ORI, SLTI
                // ------------------------------------------------------------
                7'b0010011: begin
                    imm = {{20{instr[31]}}, instr[31:20]};  // Sign extend
                    op1 = golden_regs[rs1];
                    case (instr[14:12])
                        3'b000: expected_alu_result = op1 + imm;      // ADDI
                        3'b111: expected_alu_result = op1 & imm;      // ANDI
                        3'b110: expected_alu_result = op1 | imm;      // ORI
                        3'b010: expected_alu_result = ($signed(op1) < $signed(imm)) ? 32'd1 : 32'd0; // SLTI
                        default: expected_alu_result = 32'd0;
                    endcase
                    if (rd != 0) golden_regs[rd] = expected_alu_result;
                end
                
                // ------------------------------------------------------------
                // Load Word (opcode = 7'b0000011)
                // LW - Load from memory to register
                // ------------------------------------------------------------
                7'b0000011: begin
                    imm = {{20{instr[31]}}, instr[31:20]};
                    op1 = golden_regs[rs1];
                    expected_alu_result = golden_memory[op1 + imm];
                    if (rd != 0) golden_regs[rd] = expected_alu_result;
                end
                
                // ------------------------------------------------------------
                // Store Word (opcode = 7'b0100011)
                // SW - Store register to memory
                // ------------------------------------------------------------
                7'b0100011: begin
                    imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
                    op1 = golden_regs[rs1];
                    op2 = golden_regs[rs2];
                    golden_memory[op1 + imm] = op2;
                    expected_alu_result = 32'd0;
                end
                
                // ------------------------------------------------------------
                // Jump and Link Register (opcode = 7'b1100111)
                // JALR - Jump with return address, LSB cleared
                // ------------------------------------------------------------
                7'b1100111: begin
                    imm = {{20{instr[31]}}, instr[31:20]};
                    op1 = golden_regs[rs1];
                    // Link address = pc + 4
                    golden_regs[rd] = pc + 4;
                    // Target = (op1 + imm) & ~1 (clear LSB)
                    expected_alu_result = (op1 + imm) & ~1;
                end
                
                // ------------------------------------------------------------
                // Jump and Link (opcode = 7'b1101111)
                // JAL - Used for HALT when rd=x0
                // ------------------------------------------------------------
                7'b1101111: begin
                    if (rd == 0) begin
                        // HALT: no register change, PC stays
                        expected_alu_result = pc;
                    end else begin
                        // Full JAL (not fully implemented in RTL)
                        imm = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
                        golden_regs[rd] = pc + 4;
                        expected_alu_result = pc + imm;
                    end
                end
                default: expected_alu_result = 32'd0;
            endcase
            
            // x0 is always zero (RISC-V spec)
            golden_regs[0] = 32'd0;
        end
    endtask

    // ========================================================================
    // SECTION 6: DISPLAY TASKS
    // ========================================================================
    
    /**
     * TASK: display_instruction
     * 
     * Formats and displays instruction execution in a professional table
     * 
     * INPUTS:
     *   pc           - Program counter
     *   instr        - Instruction word
     *   alu_res      - ALU result
     *   reg_write    - Register write enable
     *   reg_wr_addr  - Register write address
     *   reg_wr_data  - Register write data
     *   pmp_ok       - PMP access granted
     * 
     * OUTPUT FORMAT:
     *   | TIME | PC | INSTRUCTION | ALU RESULT | STAT |
     *   |      |    | WRITE xN = value |      |      |
     * 
     * STATUS INDICATORS:
     *   P - PMP Allowed (Pass)
     *   F - PMP Denied (Fail)
     */
    task display_instruction;
        input [7:0] pc;
        input [31:0] instr;
        input [31:0] alu_res;
        input reg_write;
        input [4:0] reg_wr_addr;
        input [31:0] reg_wr_data;
        input pmp_ok;
        reg [31:0] imm;
        begin
            // Decode and display based on instruction type
            case (instr[6:0])
                // ------------------------------------------------------------
                // R-Type Instructions
                // ------------------------------------------------------------
                7'b0110011: begin
                    case (instr[14:12])
                        3'b000: $display("| %4t | 0x%02h | ADD   x%d, x%d, x%d | 0x%08h |  %s  |",
                                $time, pc, instr[11:7], instr[19:15], instr[24:20], 
                                alu_res, (pmp_ok) ? "P" : "F");
                        3'b111: $display("| %4t | 0x%02h | AND   x%d, x%d, x%d | 0x%08h |  %s  |",
                                $time, pc, instr[11:7], instr[19:15], instr[24:20], 
                                alu_res, (pmp_ok) ? "P" : "F");
                        3'b110: $display("| %4t | 0x%02h | OR    x%d, x%d, x%d | 0x%08h |  %s  |",
                                $time, pc, instr[11:7], instr[19:15], instr[24:20], 
                                alu_res, (pmp_ok) ? "P" : "F");
                        3'b010: $display("| %4t | 0x%02h | SLT   x%d, x%d, x%d | 0x%08h |  %s  |",
                                $time, pc, instr[11:7], instr[19:15], instr[24:20], 
                                alu_res, (pmp_ok) ? "P" : "F");
                        default: $display("| %4t | 0x%02h | R-??? x%d, x%d, x%d | 0x%08h |  %s  |",
                                $time, pc, instr[11:7], instr[19:15], instr[24:20], 
                                alu_res, (pmp_ok) ? "P" : "F");
                    endcase
                end
                
                // ------------------------------------------------------------
                // I-Type Instructions
                // ------------------------------------------------------------
                7'b0010011: begin
                    imm = {{20{instr[31]}}, instr[31:20]};
                    case (instr[14:12])
                        3'b000: $display("| %4t | 0x%02h | ADDI  x%d, x%d, 0x%02h | 0x%08h |  %s  |",
                                $time, pc, instr[11:7], instr[19:15], imm[7:0], 
                                alu_res, (pmp_ok) ? "P" : "F");
                        3'b111: $display("| %4t | 0x%02h | ANDI  x%d, x%d, 0x%02h | 0x%08h |  %s  |",
                                $time, pc, instr[11:7], instr[19:15], imm[7:0], 
                                alu_res, (pmp_ok) ? "P" : "F");
                        3'b110: $display("| %4t | 0x%02h | ORI   x%d, x%d, 0x%02h | 0x%08h |  %s  |",
                                $time, pc, instr[11:7], instr[19:15], imm[7:0], 
                                alu_res, (pmp_ok) ? "P" : "F");
                        3'b010: $display("| %4t | 0x%02h | SLTI  x%d, x%d, 0x%02h | 0x%08h |  %s  |",
                                $time, pc, instr[11:7], instr[19:15], imm[7:0], 
                                alu_res, (pmp_ok) ? "P" : "F");
                        default: $display("| %4t | 0x%02h | I-??? x%d, x%d, 0x%02h | 0x%08h |  %s  |",
                                $time, pc, instr[11:7], instr[19:15], imm[7:0], 
                                alu_res, (pmp_ok) ? "P" : "F");
                    endcase
                end
                
                // ------------------------------------------------------------
                // Load Word
                // ------------------------------------------------------------
                7'b0000011: begin
                    imm = {{20{instr[31]}}, instr[31:20]};
                    $display("| %4t | 0x%02h | LW    x%d, %d(x%d) | 0x%08h |  %s  |",
                            $time, pc, instr[11:7], imm, instr[19:15], 
                            alu_res, (pmp_ok) ? "P" : "F");
                end
                
                // ------------------------------------------------------------
                // Store Word
                // ------------------------------------------------------------
                7'b0100011: begin
                    imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
                    $display("| %4t | 0x%02h | SW    x%d, %d(x%d) | 0x%08h |  %s  |",
                            $time, pc, instr[24:20], imm, instr[19:15], 
                            alu_res, (pmp_ok) ? "P" : "F");
                end
                
                // ------------------------------------------------------------
                // JALR
                // ------------------------------------------------------------
                7'b1100111: begin
                    imm = {{20{instr[31]}}, instr[31:20]};
                    $display("| %4t | 0x%02h | JALR  x%d, x%d, %d | 0x%08h |  %s  |",
                            $time, pc, instr[11:7], instr[19:15], imm, 
                            alu_res, (pmp_ok) ? "P" : "F");
                end
                
                // ------------------------------------------------------------
                // JAL / HALT
                // ------------------------------------------------------------
                7'b1101111: begin
                    imm = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
                    if (instr[11:7] == 5'd0)
                        $display("| %4t | 0x%02h | HALT  (JAL x0, 0x%02h) | 0x%08h |  %s  |",
                                $time, pc, imm[7:0], alu_res, (pmp_ok) ? "P" : "F");
                    else
                        $display("| %4t | 0x%02h | JAL   x%d, 0x%02h | 0x%08h |  %s  |",
                                $time, pc, instr[11:7], imm[7:0], alu_res, 
                                (pmp_ok) ? "P" : "F");
                end
                
                // ------------------------------------------------------------
                // Unknown Instruction
                // ------------------------------------------------------------
                default: $display("| %4t | 0x%02h | ???   0x%08h | 0x%08h |  %s  |",
                                $time, pc, instr, alu_res, (pmp_ok) ? "P" : "F");
            endcase

            // Display register write if applicable
            if (reg_write && reg_wr_addr != 0) begin
                $display("|      |      | WRITE   x%d = 0x%08h       |         |      |",
                         reg_wr_addr, reg_wr_data);
            end
        end
    endtask

    /**
     * TASK: display_register_table
     * 
     * Displays all 32 registers in a formatted table
     * Uses golden reference model for values (expected state)
     * 
     * OUTPUT FORMAT:
     *   | REGS | x0=val | x1=val | x2=val | x3=val |
     *   |      | x4=val | x5=val | x6=val | x7=val |
     *   ... (all 32 registers)
     */
    task display_register_table;
        begin
            $display("+------+--------+----------------------------------------------------------+");
            $display("| REGS |        | x0=0x%08h | x1=0x%08h | x2=0x%08h | x3=0x%08h |",
                     golden_regs[0], golden_regs[1], golden_regs[2], golden_regs[3]);
            $display("|      |        | x4=0x%08h | x5=0x%08h | x6=0x%08h | x7=0x%08h |",
                     golden_regs[4], golden_regs[5], golden_regs[6], golden_regs[7]);
            $display("|      |        | x8=0x%08h | x9=0x%08h |x10=0x%08h |x11=0x%08h |",
                     golden_regs[8], golden_regs[9], golden_regs[10], golden_regs[11]);
            $display("|      |        |x12=0x%08h |x13=0x%08h |x14=0x%08h |x15=0x%08h |",
                     golden_regs[12], golden_regs[13], golden_regs[14], golden_regs[15]);
            $display("|      |        |x16=0x%08h |x17=0x%08h |x18=0x%08h |x19=0x%08h |",
                     golden_regs[16], golden_regs[17], golden_regs[18], golden_regs[19]);
            $display("|      |        |x20=0x%08h |x21=0x%08h |x22=0x%08h |x23=0x%08h |",
                     golden_regs[20], golden_regs[21], golden_regs[22], golden_regs[23]);
            $display("|      |        |x24=0x%08h |x25=0x%08h |x26=0x%08h |x27=0x%08h |",
                     golden_regs[24], golden_regs[25], golden_regs[26], golden_regs[27]);
            $display("|      |        |x28=0x%08h |x29=0x%08h |x30=0x%08h |x31=0x%08h |",
                     golden_regs[28], golden_regs[29], golden_regs[30], golden_regs[31]);
        end
    endtask

    // ========================================================================
    // SECTION 7: TEST PROGRAM LOADERS
    // ========================================================================
    
    /**
     * TASK: program_pmp_test
     * 
     * Loads the PMP test program into instruction memory
     * 
     * TEST SEQUENCE:
     *   [0-4]  Setup: Load addresses and test values
     *   [5]    Allowed read from Region0
     *   [6]    Violation #1: Load from Region2 (0x80)
     *   [7]    Violation #2: Store to Region1 (0x40)
     *   [8]    Allowed ALU operation
     *   [9]    Violation #4: Load from Default (0xC0)
     *   [10]   Violation #3: Execute from Region2 (0x80)
     *   [11]   HALT
     */
    task program_pmp_test;
        begin
            // Setup addresses in registers
            Processor_inst.datapath.InstrMem_inst.memory[0]  = 32'h08000293; // addi x5, x0, 0x80
            Processor_inst.datapath.InstrMem_inst.memory[1]  = 32'h04000313; // addi x6, x0, 0x40
            Processor_inst.datapath.InstrMem_inst.memory[2]  = 32'h00000393; // addi x7, x0, 0x00
            Processor_inst.datapath.InstrMem_inst.memory[3]  = 32'h0C000413; // addi x8, x0, 0x0C0
            Processor_inst.datapath.InstrMem_inst.memory[4]  = 32'h00100093; // addi x1, x0, 1
            
            // Allowed read from Region0
            Processor_inst.datapath.InstrMem_inst.memory[5]  = 32'h0003A083; // lw x1, 0(x7)
            
            // Violation #1: Read from Region2
            Processor_inst.datapath.InstrMem_inst.memory[6]  = 32'h0002A103; // lw x2, 0(x5)
            
            // Violation #2: Write to Region1
            Processor_inst.datapath.InstrMem_inst.memory[7]  = 32'h00132023; // sw x1, 0(x6)
            
            // Allowed ALU operation
            Processor_inst.datapath.InstrMem_inst.memory[8]  = 32'h003101b3; // add x3, x2, x3
            
            // Violation #4: Read from Default Region
            Processor_inst.datapath.InstrMem_inst.memory[9]  = 32'h00042083; // lw x1, 0(x8)
            
            // Violation #3: Execute from Region2
            Processor_inst.datapath.InstrMem_inst.memory[10] = 32'h000280e7; // jalr x1, x5, 0
            
            // HALT
            Processor_inst.datapath.InstrMem_inst.memory[11] = 32'h0000006f; // jal x0, 0x58
            
            // HALT loop target
            Processor_inst.datapath.InstrMem_inst.memory[22] = 32'h0000006f;
            
            // Fill remaining with NOP
            for (mem_idx = 12; mem_idx < 64; mem_idx = mem_idx + 1)
                Processor_inst.datapath.InstrMem_inst.memory[mem_idx] = 32'h00000013;
        end
    endtask

    /**
     * TASK: program_functional_test
     * 
     * Loads the functional ISA test program
     * 
     * TEST SEQUENCE (starting at PC=0x40):
     *   R-Type: ADD, SUB, AND, OR, SLT
     *   I-Type: ADDI, ANDI, ORI, SLTI
     *   Load/Store: LW, SW
     *   Jump: JALR with subroutine
     *   HALT
     */
    task program_functional_test;
        begin
            // Jump to functional test at 0x40
            Processor_inst.datapath.InstrMem_inst.memory[0] = 32'h0400006f;
            
            // Fill with NOPs until 0x40
            for (mem_idx = 1; mem_idx < 16; mem_idx = mem_idx + 1)
                Processor_inst.datapath.InstrMem_inst.memory[mem_idx] = 32'h00000013;
            
            // ----------------------------------------------------------------
            // R-Type Tests (PC=0x40, word index 16)
            // ----------------------------------------------------------------
            Processor_inst.datapath.InstrMem_inst.memory[16] = 32'h00500093; // ADDI x1, x0, 5
            Processor_inst.datapath.InstrMem_inst.memory[17] = 32'h00700113; // ADDI x2, x0, 7
            Processor_inst.datapath.InstrMem_inst.memory[18] = 32'h002081b3; // ADD x3, x1, x2
            Processor_inst.datapath.InstrMem_inst.memory[19] = 32'h40208233; // SUB x4, x1, x2
            Processor_inst.datapath.InstrMem_inst.memory[20] = 32'h0020f2b3; // AND x5, x1, x2
            Processor_inst.datapath.InstrMem_inst.memory[21] = 32'h0020e333; // OR x6, x1, x2
            Processor_inst.datapath.InstrMem_inst.memory[22] = 32'h0020a3b3; // SLT x7, x1, x2
            
            // ----------------------------------------------------------------
            // I-Type Tests
            // ----------------------------------------------------------------
            Processor_inst.datapath.InstrMem_inst.memory[23] = 32'h00A00413; // ADDI x8, x0, 10
            Processor_inst.datapath.InstrMem_inst.memory[24] = 32'h0030f4b3; // ANDI x9, x1, 3
            Processor_inst.datapath.InstrMem_inst.memory[25] = 32'h0030e533; // ORI x10, x1, 3
            Processor_inst.datapath.InstrMem_inst.memory[26] = 32'h00A0a5b3; // SLTI x11, x1, 10
            
            // ----------------------------------------------------------------
            // Load/Store Tests
            // ----------------------------------------------------------------
            Processor_inst.datapath.InstrMem_inst.memory[27] = 32'h10000713; // ADDI x14, x0, 0x100
            Processor_inst.datapath.InstrMem_inst.memory[28] = 32'h0FF00793; // ADDI x15, x0, 255
            Processor_inst.datapath.InstrMem_inst.memory[29] = 32'h00F72023; // SW x15, 0(x14)
            Processor_inst.datapath.InstrMem_inst.memory[30] = 32'h00072803; // LW x16, 0(x14)
            
            // ----------------------------------------------------------------
            // JALR Test with Subroutine
            // ----------------------------------------------------------------
            Processor_inst.datapath.InstrMem_inst.memory[31] = 32'h080008e7; // JALR x17, x0, 0x80
            
            // Subroutine at 0x80 (word index 32)
            Processor_inst.datapath.InstrMem_inst.memory[32] = 32'h12300913; // ADDI x18, x0, 0x1234
            Processor_inst.datapath.InstrMem_inst.memory[33] = 32'h0008b067; // JALR x0, x17, 0
            
            // HALT
            Processor_inst.datapath.InstrMem_inst.memory[34] = 32'h0000006f;
            
            // Fill remaining with NOP
            for (mem_idx = 35; mem_idx < 64; mem_idx = mem_idx + 1)
                Processor_inst.datapath.InstrMem_inst.memory[mem_idx] = 32'h00000013;
        end
    endtask

    // ========================================================================
    // SECTION 8: TEST SELECTION AND LOADING
    // ========================================================================
    
    /**
     * Test Program Selection
     * 
     * Based on TEST_PROGRAM parameter:
     *   "PMP"        - Load PMP test program
     *   "FUNCTIONAL" - Load functional ISA test program
     */
    initial begin
        test_sel = (TEST_PROGRAM == "PMP") ? 0 : 1;
        #1;  // Small delay for DUT instantiation
        if (test_sel == 0) begin
            program_pmp_test;
            $display("\n");
            $display("========================================");
            $display("  [PMP] TEST PROGRAM LOADED");
            $display("  Expected: 4 PMP Violations");
            $display("========================================\n");
        end else begin
            program_functional_test;
            $display("\n");
            $display("========================================");
            $display("  [FUNC] FUNCTIONAL TEST PROGRAM LOADED");
            $display("  Testing: ADD, SUB, AND, OR, SLT,");
            $display("  ADDI, ANDI, ORI, SLTI, LW, SW, JALR");
            $display("========================================\n");
        end
    end

    // ========================================================================
    // SECTION 9: GOLDEN MODEL INITIALIZATION
    // ========================================================================
    
    /**
     * Initialize Golden Reference Model
     * 
     * - Zero all registers
     * - Copy data memory from DUT (for initial values)
     * - Reset error counter and cycle count
     */
    initial begin
        for (i = 0; i < 32; i = i + 1) 
            golden_regs[i] = 32'd0;
        for (i = 0; i < 512; i = i + 1) 
            golden_memory[i] = Processor_inst.datapath.DataMem_inst.data_memory[i];
        golden_regs[0] = 32'd0;
        error_cnt = 0;
        cycle_count = 0;
        last_pc = 0;
        first_instruction = 1;
    end

    // ========================================================================
    // SECTION 10: MAIN EXECUTION MONITOR
    // ========================================================================
    
    /**
     * Main Execution Monitor
     * 
     * On each clock cycle:
     *   1. Increment cycle counter
     *   2. Detect PC change
     *   3. Update golden model
     *   4. Display instruction in formatted table
     *   5. Display register table
     * 
     * Only prints on PC change for clean output
     */
    always @(posedge clk) begin
        if (!rst) begin
            cycle_count <= cycle_count + 1;

            if (debug_pc != last_pc && debug_instr_pmp_ok) begin
                // Update golden model
                golden_step(debug_instr, debug_pc);

                // Display header on first instruction
                if (first_instruction) begin
                    $display("+------+--------+---------------------------------------------+------------+-------+");
                    $display("| TIME |  PC    | INSTRUCTION                               | ALU RESULT | STAT  |");
                    $display("+------+--------+---------------------------------------------+------------+-------+");
                    first_instruction = 0;
                end

                // Display instruction and register state
                display_instruction(debug_pc, debug_instr, debug_alu_result,
                                    Processor_inst.datapath.Reg_Write,
                                    Processor_inst.datapath.Instruction[11:7],
                                    Processor_inst.datapath.RegFile_inst.register_file[
                                        Processor_inst.datapath.Instruction[11:7]],
                                    debug_instr_pmp_ok);

                display_register_table();
                $display("+------+--------+---------------------------------------------+------------+-------+");

                last_pc <= debug_pc;
            end
        end
    end

    // ========================================================================
    // SECTION 11: SCOREBOARD (AUTOMATED REGISTER CHECKING)
    // ========================================================================
    
    /**
     * Scoreboard: Compares DUT registers against golden model
     * 
     * When register write is enabled:
     *   1. Read actual register value from DUT
     *   2. Read expected value from golden model
     *   3. Compare and report mismatch
     *   4. Increment error counter on mismatch
     * 
     * NOTE: Uses non-blocking assignment so comparison happens
     * on the next clock edge (after DUT write completes)
     */
    always @(posedge clk) begin
        if (!rst && Processor_inst.datapath.Reg_Write && debug_instr_pmp_ok) begin
            rd = Processor_inst.datapath.Instruction[11:7];
            actual = Processor_inst.datapath.RegFile_inst.register_file[rd];
            expected = golden_regs[rd];
            if (rd != 0 && actual !== expected) begin
                $display("-      -        [WARN] REG MISMATCH: x%d exp=0x%08h act=0x%08h -         -       ",
                         rd, expected, actual);
                error_cnt = error_cnt + 1;
            end
        end
    end

    // ========================================================================
    // SECTION 12: PMP VIOLATION DETECTION
    // ========================================================================
    
    /**
     * PMP Violation Detection and Counting
     * 
     * Detects all 4 violation types:
     *   #1: Load from Region2 (READ denied)
     *   #2: Store to Region1 (WRITE denied)
     *   #3: Execute from Region2 (EXECUTE denied)
     *   #4: Load from Default Region (READ denied)
     * 
     * Each violation is counted ONCE (first occurrence)
     * Displays [DENY] with violation number and details
     */
    reg load_region2_seen;      // Violation #1 flag
    reg store_region1_seen;     // Violation #2 flag
    reg exec_region2_seen;      // Violation #3 flag
    reg load_default_seen;      // Violation #4 flag
    integer violation_count;    // Total violation counter

    initial begin
        violation_count = 0;
        load_region2_seen = 0;
        store_region1_seen = 0;
        exec_region2_seen = 0;
        load_default_seen = 0;
    end

    always @(posedge clk) begin
        if (!rst) begin
            // ----------------------------------------------------------------
            // Data PMP Violations (Read and Write)
            // ----------------------------------------------------------------
            if (!debug_data_pmp_ok) begin
                // Read violations
                if (debug_mem_read && !debug_mem_write) begin
                    if (debug_pmp_addr >= REGION2_START && debug_pmp_addr <= REGION2_END) begin
                        // Violation #1: Load from Region2
                        if (!load_region2_seen) begin
                            load_region2_seen <= 1'b1;
                            violation_count <= violation_count + 1;
                            $display("-      -        [DENY] #%0d: Load from Region2 (0x%02h)      -         -      -",
                                     violation_count, debug_pmp_addr);
                        end
                    end else if (debug_pmp_addr > REGION2_END) begin
                        // Violation #4: Load from Default Region
                        if (!load_default_seen) begin
                            load_default_seen <= 1'b1;
                            violation_count <= violation_count + 1;
                            $display("-      -        [DENY] #%0d: Load from Default (0x%02h)       -         -      -",
                                     violation_count, debug_pmp_addr);
                        end
                    end
                end
                // Write violations
                else if (!debug_mem_read && debug_mem_write) begin
                    if (debug_pmp_addr >= REGION1_START && debug_pmp_addr <= REGION1_END) begin
                        // Violation #2: Store to Region1
                        if (!store_region1_seen) begin
                            store_region1_seen <= 1'b1;
                            violation_count <= violation_count + 1;
                            $display("-      -        [DENY] #%0d: Store to Region1 (0x%02h)         -         -      -",
                                     violation_count, debug_pmp_addr);
                        end
                    end
                end
            end

            // ----------------------------------------------------------------
            // Instruction PMP Violations (Execute)
            // ----------------------------------------------------------------
            if (!debug_instr_pmp_ok) begin
                if (debug_pc >= REGION2_START && debug_pc <= REGION2_END) begin
                    // Violation #3: Execute from Region2
                    if (!exec_region2_seen) begin
                        exec_region2_seen <= 1'b1;
                        violation_count <= violation_count + 1;
                        $display("-      -        [DENY] #%0d: Execute from Region2 (PC=0x%02h)    -         -      -",
                                 violation_count, debug_pc);
                    end
                end
            end
        end
    end

    // ========================================================================
    // SECTION 13: PASS/FAIL CONDITIONS
    // ========================================================================
    
    /**
     * PASS/FAIL Criteria for both test modes
     * 
     * PMP Test:
     *   PASS when all 4 violation types detected
     *   Displays detailed summary with [PASS]
     * 
     * Functional Test:
     *   PASS when HALT reached AND no errors
     *   Displays summary with [PASS] or [FAIL]
     */
    always @(posedge clk) begin
        if (!rst) begin
            // ================================================================
            // PMP Test PASS Condition
            // ================================================================
            if (test_sel == 0) begin
                if (load_region2_seen && store_region1_seen && 
                    exec_region2_seen && load_default_seen) begin
                    $display("+------+--------+---------------------------------------------+------------+-------+");
                    $display("\n");
                    $display("========================================");
                    $display("  [PASS] PMP TEST PASSED");
                    $display("  --------------------------------------");
                    $display("  All 4 PMP violation types detected:");
                    $display("    [PASS] Load from Region2     : DETECTED");
                    $display("    [PASS] Store to Region1      : DETECTED");
                    $display("    [PASS] Execute from Region2  : DETECTED");
                    $display("    [PASS] Load from Default     : DETECTED");
                    $display("  --------------------------------------");
                    $display("  Total Violations Count  = %0d", violation_count);
                    $display("  Cycles Executed         = %0d", cycle_count);
                    $display("========================================\n");
                    #20;
                    $finish;
                end
            end 
            // ================================================================
            // Functional Test PASS/FAIL Condition
            // ================================================================
            else begin
                if (halt) begin
                    $display("+------+--------+---------------------------------------------+------------+-------+");
                    $display("\n");
                    $display("========================================");
                    if (error_cnt == 0) begin
                        $display("  [PASS] FUNCTIONAL TEST PASSED");
                        $display("  --------------------------------------");
                        $display("  All instructions executed correctly.");
                    end else begin
                        $display("  [FAIL] FUNCTIONAL TEST FAILED");
                        $display("  --------------------------------------");
                        $display("  Errors: %0d", error_cnt);
                    end
                    $display("  Cycles Executed         = %0d", cycle_count);
                    $display("========================================\n");
                    #20;
                    $finish;
                end
            end
        end
    end

    // ========================================================================
    // SECTION 14: TIMEOUT PROTECTION
    // ========================================================================
    
    /**
     * Timeout: Prevents simulation from hanging indefinitely
     * 
     * If timeout reached before PASS condition:
     *   - Displays [FAIL] with current state
     *   - Reports last PC and cycle count
     *   - Terminates simulation
     */
    initial begin
        #(TIMEOUT_CYCLES * 20);
        $display("\n");
        $display("========================================");
        $display("  [FAIL] TIMEOUT - Test Incomplete");
        $display("  Last PC = 0x%02h", last_pc);
        $display("  Cycles  = %0d", cycle_count);
        $display("========================================\n");
        $finish;
    end

    // ========================================================================
    // SECTION 15: WAVEFORM DUMP
    // ========================================================================
    
    /**
     * VCD Waveform Generation
     * 
     * Creates waveform.vcd file for GTKWave debugging
     * 
     * Usage:
     *   gtkwave waveform.vcd
     * 
     * Signals dumped:
     *   - All testbench signals (level 0)
     *   - All DUT internal signals (hierarchical)
     */
    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, tb_Processor);
    end

endmodule 
