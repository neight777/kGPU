# kGPU

kGPU is a very simplistic SIMT GPU architecture. It is built in system verilog and synthesized through the [librelane](https://github.com/librelane/librelane) synthesis flow. kGPU comes fully featured with a warp scheduler for maximum throughput and supports branch reconvergence.

kGPU supports executing arbitrary kernels via cocotb in python. There are currently 2 kernels in gpu_testbench.py, one that does not branch and one that diverges.

<img title="" src="/images/kGPU.png" alt="Alt Text" style="display: block; margin-left: auto; margin-right: auto;" />

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