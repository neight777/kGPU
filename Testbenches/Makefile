SIM              = verilator
TOPLEVEL_LANG    = verilog

VERILOG_SOURCES  = $(shell pwd)/../RTL/ALU.sv

COMPILE_ARGS    += --sv
COMPILE_ARGS    += -I$(shell pwd)/../RTL
EXTRA_ARGS      += --timing

TOPLEVEL = ALU
MODULE   = ALU_testbench

include $(shell cocotb-config --makefiles)/Makefile.sim
