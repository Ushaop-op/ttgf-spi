SIM           ?= icarus
TOPLEVEL_LANG  = verilog

VERILOG_SOURCES  = $(shell pwd)/../src/tt_um_spi_slave.v
VERILOG_SOURCES += $(shell pwd)/../src/spi_slave.v
VERILOG_SOURCES += $(shell pwd)/../src/reg_file.v
VERILOG_SOURCES += $(shell pwd)/tb.v

TOPLEVEL = tb
MODULE   = test

include $(shell cocotb-config --makefiles)/Makefile.sim
