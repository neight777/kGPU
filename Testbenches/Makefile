SIM              = verilator
TOPLEVEL_LANG    = verilog
EXTRA_ARGS      := --timing

COCOTB_MAKEFILES := $(shell cocotb-config --makefiles)
RTL_DIR          := $(shell pwd)/../RTL

# Auto-discover *_testbench.py files; derive DUT name by stripping _testbench suffix
TB_FILES  := $(wildcard *_testbench.py)
TB_NAMES  := $(patsubst %_testbench.py,%,$(TB_FILES))

.PHONY: all clean $(TB_NAMES:%=%_testbench)

all: $(TB_NAMES:%=%_testbench)

# Generate one make target per testbench
define make_tb_target
$(1)_testbench:
	$(MAKE) \
		VERILOG_SOURCES=$(RTL_DIR)/$(1).sv \
		TOPLEVEL=$(1) \
		MODULE=$(1)_testbench \
		SIM=$(SIM) \
		TOPLEVEL_LANG=$(TOPLEVEL_LANG) \
		VERILOG_INCLUDE_DIRS=$(RTL_DIR) \
		EXTRA_ARGS="$(EXTRA_ARGS)" \
		SIM_BUILD=sim_build_$(1) \
		-f $(COCOTB_MAKEFILES)/Makefile.sim
endef

$(foreach tb,$(TB_NAMES),$(eval $(call make_tb_target,$(tb))))

clean:
	rm -rf sim_build* results.xml __pycache__
