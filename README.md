# kGPU

kGPU is a very simplistic SIMT GPU architecture. It is built in system verilog and synthesized through the [librelane](https://github.com/librelane/librelane) synthesis flow. kGPU comes fully featured with a warp scheduler for maximum throughput and supports branch reconvergence.

kGPU supports executing arbitrary kernels via cocotb in python. There are currently 2 kernels in gpu_testbench.py, one that does not branch and one that diverges.

![Alt text](images/kGPU.png)

# Description

There are a few good resources out there for learning the architecture of GPUs but very few for the goal I was trying to reach. I wanted to try and cover some modern abstraction while keeping the SM simple and lightweight. Here is a run through of the architecture of the GPU and all of the details that went in to it

## Tooling/Workflow

### Simulator

The majority of the project is dominated by SystemVerilog and Verilator. I chose Verilator as the compiler due to its simple 2 state simulator design (0, 1) rather than four states (0, 1, X, Z). I had no use for the extra Unknown, and High Impedance values so I opted for the less strict 2 state simulator. 

### Verification

For me python was the go to language for verification of functionality. I liked the implementation of cocotb as the arbiter due to its flexibility and writability. I based my configuration off of [tiny-gpu](https://github.com/adam-maj/tiny-gpu) using cocotb to interface with the gpu to schedule kernels and manage the off chip memory that the hardware communicates with. This gave me an easy workflow for compiling and simulate using Makefile and Verilator. It drastically simplified the steps without sacrificing efficiency or correctness.

### Synthesis

The RTL &rarr; GDSII pipeline was satisfied by [librelane](https://github.com/librelane/librelane). This includes [yosys](https://github.com/yosyshq/yosys) for gate-level netlist synthesis, [OpenROAD](https://github.com/The-OpenROAD-Project/OpenROAD) for PnR, [Magic](https://opencircuitdesign.com/magic/) and [KLayout](https://www.klayout.de/) for physical verification, and [Netgen](https://opencircuitdesign.com/netgen/) for netlist comparison. The specs were kept to 1 SM, 2 warps, and 8 threads per warp to keep the PPA within reasonable limits for a personal project.  

# Architecture

kGPU is built bottom up as **GPU → Dispatcher → SM → Warps/Lanes**. Everything is parameterized, so the same RTL can scale from my small synthesied config up to something closer to a real part.

## Instruction Set

kGPU uses a fixed 32-bit instruction width. The below tables describes all operations:

| $\textsf{\color{white}Opcode}$ | $\textsf{\color{white}Function}$                                                                                                   | $\textsf{\color{white}Structure}$                                                                                                                         |
|:------------------------------:|:----------------------------------------------------------------------------------------------------------------------------------:|:---------------------------------------------------------------------------------------------------------------------------------------------------------:|
| $\textsf{\color{white}NOP}$    | $\textsf{\color{white}PC = PC + 1}$                                                                                                | $\textsf{\color{white}000000}$ $\textsf{\color{gray}xxxxx}$ $\textsf{\color{gray}xxxxx}$ $\textsf{\color{gray}xxxxxxxxxxxxxxxx}$                          |
| $\textsf{\color{white}ADD}$    | $\textsf{\color{red}Rd}$ $\textsf{\color{white}=}$ $\textsf{\color{teal}Rs}$ $\textsf{\color{white}+}$ $\textsf{\color{yellow}Rt}$ | $\textsf{\color{white}000001}$ $\textsf{\color{teal}sssss}$ $\textsf{\color{yellow}ttttt}$ $\textsf{\color{red}ddddd}$ $\textsf{\color{gray}xxxxxxxxxxx}$ |
| $\textsf{\color{white}SUB}$    | $\textsf{\color{red}Rd}$ $\textsf{\color{white}=}$ $\textsf{\color{teal}Rs}$ $\textsf{\color{white}-}$ $\textsf{\color{yellow}Rt}$ | $\textsf{\color{white}000010}$ $\textsf{\color{teal}sssss}$ $\textsf{\color{yellow}ttttt}$ $\textsf{\color{red}ddddd}$ $\textsf{\color{gray}xxxxxxxxxxx}$ |
| $\textsf{\color{white}MUL}$    | $\textsf{\color{red}Rd}$ $\textsf{\color{white}=}$ $\textsf{\color{teal}Rs}$ $\textsf{\color{white}*}$ $\textsf{\color{yellow}Rt}$ | $\textsf{\color{white}000011}$ $\textsf{\color{teal}sssss}$ $\textsf{\color{yellow}ttttt}$ $\textsf{\color{red}ddddd}$ $\textsf{\color{gray}xxxxxxxxxxx}$ |
| $\textsf{\color{white}DIV}$    | $\textsf{\color{red}Rd}$ $\textsf{\color{white}=}$ $\textsf{\color{teal}Rs}$ $\textsf{\color{white}/}$ $\textsf{\color{yellow}Rt}$ | $\textsf{\color{white}000100}$ $\textsf{\color{teal}sssss}$ $\textsf{\color{yellow}ttttt}$ $\textsf{\color{red}ddddd}$ $\textsf{\color{gray}xxxxxxxxxxx}$ |
| $\textsf{\color{white}STR}$    | $\textsf{\color{white}Mem[\color{yellow}Rt\color{white}] = \color{teal}Rs}$                                                        | $\textsf{\color{white}000101}$ $\textsf{\color{teal}sssss}$ $\textsf{\color{yellow}ttttt}$  $\textsf{\color{gray}xxxxxxxxxxxxxxxx}$                       |
| $\textsf{\color{white}LDR}$    | $\textsf{\color{teal}Rs\color{white} =\color{white} Mem[\color{yellow}Rt\color{white}]}$                                           | $\textsf{\color{white}000110}$ $\textsf{\color{teal}sssss}$ $\textsf{\color{yellow}ttttt}$  $\textsf{\color{gray}xxxxxxxxxxxxxxxx}$                       |
| $\textsf{\color{white}RET}$    | $\textsf{\color{gray}finished}$                                                                                                    | $\textsf{\color{white}000111}$ $\textsf{\color{gray}xxxxxxxxxxxxxxxxxxxxxxxxxx}$                                                                          |
| $\textsf{\color{white}MOV}$    | $\textsf{\color{teal}Rs \color{white}= \color{orange}IMM16}$                                                                       | $\textsf{\color{white}001000}$ $\textsf{\color{teal}sssss}$ $\textsf{\color{gray}xxxxx}$  $\textsf{\color{orange}iiiiiiiiiiiiiiii}$                       |
| $\textsf{\color{white}BEQ}$    | $\textsf{\color{teal}Rs \color{white}== \color{yellow}Rt \color{white} → PC = \color{orange}IMM16}$                                | $\textsf{\color{white}001001}$ $\textsf{\color{teal}sssss}$ $\textsf{\color{yellow}ttttt}$  $\textsf{\color{orange}iiiiiiiiiiiiiiii}$                     |
| $\textsf{\color{white}BNE}$    | $\textsf{\color{teal}Rs \color{white}!= \color{yellow}Rt \color{white} → PC = \color{orange}IMM16}$                                | $\textsf{\color{white}001010}$ $\textsf{\color{teal}sssss}$ $\textsf{\color{yellow}ttttt}$  $\textsf{\color{orange}iiiiiiiiiiiiiiii}$                     |
| $\textsf{\color{white}BLT}$    | $\textsf{\color{teal}Rs \color{white}< \color{yellow}Rt \color{white} → PC = \color{orange}IMM16}$                                 | $\textsf{\color{white}001011}$ $\textsf{\color{teal}sssss}$ $\textsf{\color{yellow}ttttt}$  $\textsf{\color{orange}iiiiiiiiiiiiiiii}$                     |
| $\textsf{\color{white}B}$      | $\textsf{\color{white}PC = \color{orange}IMM16}$                                                                                   | $\textsf{\color{white}001100}$ $\textsf{\color{teal}sssss}$ $\textsf{\color{gray}xxxxx}$  $\textsf{\color{orange}iiiiiiiiiiiiiiii}$                       |