SIM              = verilator
TOPLEVEL_LANG    = verilog
EXTRA_ARGS      := --timing

COCOTB_MAKEFILES := $(shell cocotb-config --makefiles)
RTL_DIR          := $(shell pwd)/../RTL

RTL_PKG          := $(RTL_DIR)/pkg/types.sv
RTL_SOURCES      := $(RTL_PKG) $(filter-out $(RTL_PKG),$(shell find $(RTL_DIR) -name '*.sv' | sort))

TB_FILES  := $(wildcard *_testbench.py)
TB_NAMES  := $(patsubst %_testbench.py,%,$(TB_FILES))

.PHONY: all clean $(TB_NAMES:%=%_testbench)

all: $(TB_NAMES:%=%_testbench)

define make_tb_target
$(1)_testbench:
	$(MAKE) \
		VERILOG_SOURCES="$(RTL_SOURCES)" \
		COCOTB_TOPLEVEL=$(1) \
		COCOTB_TEST_MODULES=$(1)_testbench \
		SIM=$(SIM) \
		TOPLEVEL_LANG=$(TOPLEVEL_LANG) \
		EXTRA_ARGS="$(EXTRA_ARGS)" \
		SIM_BUILD=sim_build_$(1) \
		-f $(COCOTB_MAKEFILES)/Makefile.sim
endef

$(foreach tb,$(TB_NAMES),$(eval $(call make_tb_target,$(tb))))

clean:
	rm -rf sim_build* results.xml __pycache__ *.fst
