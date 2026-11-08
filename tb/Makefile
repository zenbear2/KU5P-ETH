# SPDX-License-Identifier: CERN-OHL-S-2.0
# Verilator Simulation Makefile for KU5P-ETH

VERILATOR ?= verilator
BUILD_DIR ?= $(CURDIR)/build
TOP = test_taxi_eth_gmii_axi_wrapper

# Read sources directly from local self-contained filelist
SOURCES := $(addprefix ../rtl/,$(shell grep -v '^//' ../rtl/taxi_eth_gmii_axi_wrapper.f | grep -v '^\s*$$'))

.PHONY: all test lint clean
all: test

test: $(BUILD_DIR)/V$(TOP)
	$(BUILD_DIR)/V$(TOP)

$(BUILD_DIR)/V$(TOP): $(SOURCES) $(TOP).sv Makefile
	$(VERILATOR) --binary --timing --top-module $(TOP) --Mdir $(BUILD_DIR) $(SOURCES) $(TOP).sv

lint:
	$(VERILATOR) --lint-only --timing --top-module $(TOP) $(SOURCES) $(TOP).sv

clean:
	rm -rf $(BUILD_DIR)

