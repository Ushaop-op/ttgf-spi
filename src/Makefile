SIM           ?= icarus
TOPLEVEL_LANG  = verilog

VERILOG_SOURCES  = $(PWD)/tt_um_spi_slave.v
VERILOG_SOURCES += $(PWD)/spi_slave.v
VERILOG_SOURCES += $(PWD)/reg_file.v

TOPLEVEL = tt_um_spi_slave
MODULE   = test

include $(shell cocotb-config --makefiles)/Makefile.sim
