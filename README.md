# RISC-V RV32I Processor with Hardware PMP Protection

A synthesizable educational implementation of a compact **RISC-V RV32I-subset single-cycle processor** with an integrated **fixed-region Physical Memory Protection (PMP)-style access-control mechanism**.

The project combines processor RTL design, instruction execution, memory access control, and a directed verification environment with a reference model, scoreboard, PMP violation tests, simulation logging, and waveform analysis.

---

## 📌 Project Overview

This project implements a lightweight RISC-V processor designed to demonstrate the fundamental principles of:

- RISC-V processor datapath design
- Instruction decoding
- Register-file based execution
- ALU operations
- Immediate generation
- Load/store memory operations
- Control-flow operations
- Hardware access-control checking
- PMP-style R/W/X permission enforcement logic
- RTL verification and simulation-based debugging

The processor follows a compact **single-cycle architecture**, where an instruction is fetched, decoded, executed, and completed within one processor cycle.

The project is intended primarily as an **educational RTL/VLSI design and verification project** rather than a complete commercial RISC-V implementation.

---

## ✨ Key Features

### Processor

- 32-bit RISC-V datapath
- RV32I-subset instruction support
- Single-cycle processor organization
- 32 general-purpose registers
- Register `x0` permanently represents zero
- ALU-based arithmetic and logical execution
- Immediate generation for supported instruction formats
- Load/store data-memory interface
- Program-counter based instruction sequencing
- JALR control-flow support
- Simulation-oriented HALT convention

### PMP Protection

The processor incorporates a fixed-region PMP-style protection mechanism.

Each configured region contains independent:

- Read (`R`)
- Write (`W`)
- Execute (`X`)

permission information.

The PMP logic checks:

1. Access address
2. Access type
3. Corresponding region
4. Configured permissions
5. Access approval or violation

---

## 🏗️ High-Level Architecture

```
                       ┌───────────────────────────┐
                       │      RISC-V Processor     │
                       │                           │
                       │        Program Counter    │
                       └─────────────┬─────────────┘
                                     │
                                     ▼
                         ┌──────────────────────┐
                         │  Instruction Memory  │
                         └──────────┬───────────┘
                                    │
                                    ▼
                         ┌──────────────────────┐
                         │ Instruction PMP      │
                         │       R/W/X          │
                         └──────────┬───────────┘
                                    │
                                    ▼
                         ┌──────────────────────┐
                         │ Instruction Decoder  │
                         └──────────┬───────────┘
                                    │
                 ┌──────────────────┼──────────────────┐
                 │                  │                  │
                 ▼                  ▼                  ▼
          ┌────────────┐     ┌────────────┐    ┌──────────────┐
          │ Register   │     │ Immediate  │    │ Control      │
          │ File       │     │ Generator  │    │ Logic        │
          └─────┬──────┘     └──────┬─────┘    └──────────────┘
                │                   │
                └──────────┬────────┘
                           ▼
                    ┌─────────────┐
                    │     ALU     │
                    └──────┬──────┘
                           │
              ┌────────────┴────────────┐
              │                         │
              ▼                         ▼
       ┌──────────────┐        ┌────────────────┐
       │ Data Memory  │        │ Branch / Jump  │
       └──────┬───────┘        │ Target Logic   │
              │                └────────────────┘
              ▼
       ┌──────────────┐
       │ Data PMP     │
       │    R/W/X     │
       └──────┬───────┘
              │
              ▼
        ┌────────────┐
        │ Writeback  │
        └────────────┘
```

---

## 🔐 PMP Architecture

The project uses a fixed-region PMP-style configuration.

| Region | Address Range | Read | Write | Execute |
|--------|---------------|------|-------|---------|
| Region 0 | 0x00 – 0x3F | ✓ | ✓ | ✓ |
| Region 1 | 0x40 – 0x7F | ✓ | ✗ | ✓ |
| Region 2 | 0x80 – 0xBF | ✗ | ✗ | ✗ |
| Default | 0xC0 – 0xFF | ✗ | ✗ | ✗ |

The simulation testbench initializes and reports these regions explicitly.

---

## 🧠 PMP Access Flow

For every protected access:

```
                Access Request
                     │
                     ▼
              Access Address
                     │
                     ▼
              Region Selection
                     │
                     ▼
             Permission Lookup
                     │
          ┌──────────┼──────────┐
          │          │          │
          ▼          ▼          ▼
       Read        Write      Execute
          │          │          │
          └──────────┼──────────┘
                     ▼
             Permission Check
                     │
             ┌───────┴───────┐
             │               │
             ▼               ▼
          Allowed          Denied
             │               │
             ▼               ▼
          Continue       PMP Violation
```

---

## 🧩 Processor Datapath

The processor datapath contains the major components required for instruction execution:

**Program Counter** — Maintains the current instruction address and generates the sequential instruction flow.

**Instruction Memory** — Stores the processor program and supplies the current instruction based on the program counter.

**Instruction Decoder** — Extracts opcode, rd, rs1, rs2, funct3, funct7 and generates the corresponding control signals.

**Register File** — Contains 32 general-purpose 32-bit registers. Register x0 represents the architectural zero register.

**Immediate Generator** — Generates sign-extended immediates for the supported instruction formats.

**ALU** — Performs operations such as ADD, SUB, AND, OR, SLT and is also used for address generation.

**Data Memory** — Provides the load/store data path.

**Control Logic** — Generates control signals for register write, memory read, memory write, ALU operation, ALU source selection, writeback selection, and jump/control-flow operation.

---

## 📚 Supported Instruction Subset

The processor focuses on a practical subset of RV32I instructions used for demonstrating the datapath and memory system.

**R-Type:** ADD, SUB, AND, OR, SLT

**I-Type:** ADDI, ANDI, ORI, SLTI

**Memory:** LW, SW

**Control Flow:** JALR, Project-specific HALT convention

The project should therefore be considered an RV32I-subset implementation, rather than a complete implementation of every RV32I instruction and architectural feature.

---

## 🧪 Verification Environment

The project includes a directed RTL verification environment designed to exercise both normal processor functionality and PMP access-control behavior.

The verification environment contains:

```
                    ┌─────────────────────┐
                    │    Test Program     │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │        DUT          │
                    │ RISC-V + PMP RTL    │
                    └──────────┬──────────┘
                               │
             ┌─────────────────┼─────────────────┐
             │                 │                 │
             ▼                 ▼                 ▼
       RTL Monitor       Reference Model     PMP Checker
             │                 │                 │
             └─────────────────┼─────────────────┘
                               ▼
                         ┌────────────┐
                         │ Scoreboard │
                         └─────┬──────┘
                               │
                               ▼
                        PASS / FAIL
```

---

## 🔬 PMP Verification Tests

The PMP verification program intentionally generates four access-control violations.

**Test 1 — Load from Region 2**
Address = 0x80, Operation = Load, Permission = R = 0, Expected = PMP violation

**Test 2 — Store to Region 1**
Address = 0x40, Operation = Store, Permission = W = 0, Expected = PMP violation

**Test 3 — Execute from Region 2**
Address = 0x80, Operation = Instruction Fetch, Permission = X = 0, Expected = PMP violation

**Test 4 — Load from Default Region**
Address = 0xC0, Operation = Load, Permission = R = 0, Expected = PMP violation

The simulation reports all four violation categories as detected.

---

## 📊 Verification Output

The directed PMP test reports:

```
[PMP] TEST PROGRAM LOADED
Expected: 4 PMP Violations
```

and ultimately:

```
[PMP] TEST PASSED

All 4 PMP violation types detected:

[PASS] Load from Region2
[PASS] Store to Region1
[PASS] Execute from Region2
[PASS] Load from Default

Total Violations Count = 4
```

This demonstrates the operation of the PMP permission-checking and violation-detection logic for the configured test cases.

---

## 📈 Waveform Debugging

The verification environment exposes important internal signals for simulation and debugging.

Examples include:

- debug_pc
- debug_instr
- debug_alu_result
- debug_data_pmp_addr
- debug_data_pmp_ok
- debug_instr_pmp_ok
- debug_mem_read
- debug_mem_write
- pmp_violation
- violation_count

These signals allow the designer to correlate:

```
Instruction → PC → ALU / Address Generation → PMP Address → Permission Decision → Memory / Instruction Access
```

This was particularly useful for debugging PMP boundary and access-control behavior.

---

## 🛠️ Design Approach

The project was developed with an RTL-first methodology:

```
Specification → Instruction Set Selection → Datapath Design → Control Logic
→ Memory Interface → PMP Integration → RTL Simulation → Directed Verification
→ Reference Model / Scoreboard → Waveform Debugging → Final Verification
```

The architecture was intentionally kept compact enough to understand at RTL while still demonstrating processor-level design concepts.

---

## 💻 Technology / Tools

**HDL:** Verilog HDL

**Processor Architecture:** RISC-V, RV32I subset

**Design Concepts:** RTL Design, Single-Cycle CPU, Datapath and Control, Memory Interface, Hardware Access Control, PMP-style Protection

**Verification:** Directed simulation, Behavioral reference model, Scoreboard, Assertions/checking logic, Waveform analysis, VCD generation

**Simulator:** Icarus Verilog, Verilog/SystemVerilog simulators supporting the used RTL constructs

---

## 📁 Suggested Project Structure

```
riscv-pmp/
│
├── rtl/
│   ├── processor/
│   ├── datapath/
│   ├── control/
│   ├── alu/
│   ├── register_file/
│   ├── memory/
│   └── pmp/
│
├── tb/
│   └── tb_Processor.v
│
├── sim/
│   └── waveform.vcd
│
├── docs/
│   ├── architecture/
│   ├── waveforms/
│   └── verification/
│
└── README.md
```

The exact directory organization can be adapted to the final repository structure.

---

## 🎯 Project Objectives

The main objectives were:

- Design a functional 32-bit RISC-V processor datapath.
- Implement a practical subset of RV32I instructions.
- Develop the processor using synthesizable RTL.
- Integrate hardware access-control checking.
- Implement R/W/X-based fixed-region PMP protection.
- Verify legal and illegal memory accesses.
- Build a reference-model based verification environment.
- Analyze processor behavior through simulation waveforms.
- Develop experience debugging processor-level RTL.

---

## 🧠 Key Learning Outcomes

**RTL Design:** Modular RTL architecture, Combinational and sequential logic, Datapath/control separation, Parameterized modules, Memory modeling

**Processor Design:** RISC-V instruction formats, Instruction decoding, ALU control, Register-file operation, Immediate generation, PC/control-flow logic, Load/store execution

**Hardware Security:** Access permissions, Read/write/execute protection, Memory-region classification, Instruction-access protection, Data-access protection, Hardware security policy enforcement

**Verification:** Directed test generation, Reference modeling, Scoreboarding, Internal signal monitoring, Violation detection, Simulation debugging, Waveform analysis

---

## ⚖️ Design Trade-offs

The project intentionally uses a compact architecture rather than attempting to implement a complete production-grade RISC-V processor.

**Single-Cycle Architecture**
- Advantages: Simple datapath, Easy instruction-level tracing, Easy waveform debugging, Straightforward control
- Trade-off: Limited performance scalability compared with pipelined implementations

**Fixed-Region PMP**
- Advantages: Simple hardware implementation, Easy to understand, Easy to verify, Clear R/W/X permission model
- Trade-off: Does not attempt to reproduce every feature of a complete architectural PMP implementation

**Directed Verification**
- Advantages: Deterministic tests, Easy waveform correlation, Fast debugging, Simple regression flow
- Trade-off: Smaller coverage compared with a large constrained-random/UVM verification environment

---

## 🚧 Scope and Limitations

This project is intentionally an educational RTL implementation.

Important scope boundaries include:

- The processor implements a selected RV32I instruction subset.
- The PMP mechanism is implemented as a fixed-region R/W/X protection mechanism.
- Full RISC-V privilege architecture is outside the current project scope.
- A complete machine-mode trap/exception architecture is outside the current scope.
- The design is intended for RTL learning, architectural experimentation and portfolio demonstration rather than production CPU deployment.
- The current verification environment primarily uses directed testing.

These limitations define the project's scope and provide natural directions for future development.

---

## 🔮 Possible Future Extensions

**Processor:** Complete RV32I instruction coverage, Branch instructions, Full JAL support, CSR subsystem, Machine-mode support, Exception handling, Interrupt handling, Trap/return mechanism

**PMP:** More PMP regions, Configurable region modes, Dynamic PMP configuration, Full architectural PMP behavior, Access-size checking, Boundary-crossing access verification

**Microarchitecture:** 5-stage pipeline, Hazard detection, Forwarding, Branch handling, Performance counters

**Memory System:** Instruction/data bus interfaces, Memory-mapped peripherals, Cache subsystem, AXI/APB interface

**Verification:** SystemVerilog assertions, Functional coverage, Constrained-random testing, UVM-based verification, Automated regression, Formal verification, Reference ISS comparison

---

## 🎓 Interview / Defense Discussion Points

This project is particularly suitable for discussing:

- Why RISC-V?
- Why a single-cycle architecture?
- How does an instruction travel through the datapath?
- How does the ALU generate memory addresses?
- How does the register file work?
- How are immediates generated?
- How is JALR implemented?
- What is PMP?
- Why are R/W/X permissions required?
- How is the PMP region selected?
- What happens when an access is denied?
- How did you verify PMP behavior?
- Why use a reference model?
- What does the scoreboard compare?
- How did waveform analysis help debugging?
- What are the limitations of a single-cycle CPU?
- How would you pipeline this processor?
- How would you implement traps?
- How would you make PMP dynamically configurable?
- How would you extend the verification environment to UVM?

---

## 📝 Example Defense Explanation

A concise explanation of the project:

> "I designed a 32-bit single-cycle RISC-V processor in Verilog implementing a selected RV32I instruction subset. I integrated a fixed-region PMP-style hardware protection mechanism that checks read, write and execute permissions for configured address regions. I also developed a directed verification environment containing a behavioral reference model, scoreboard, PMP violation checker and waveform-based debug infrastructure. The verification program specifically exercises permitted accesses and four classes of PMP violations: unauthorized load, unauthorized store, unauthorized instruction execution and access to the default protected region."

---

## 📌 Project Significance

The main value of this project is the integration of three areas:

```
PROCESSOR RTL + HARDWARE SECURITY + VERIFICATION
```

Instead of implementing the CPU and PMP as isolated modules, the project demonstrates how an access-control mechanism can be integrated into the processor's instruction and data access paths and then evaluated through simulation.

---

## 👨‍💻 Author

**Devansh Swaroop**

Electronics & Communication Engineering

Interests: RTL Design, VLSI, RISC-V, SystemVerilog, FPGA, Digital Design, Hardware Verification, Computer Architecture
