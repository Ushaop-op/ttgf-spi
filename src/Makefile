SIM           ?= icarus
TOPLEVEL_LANG  = verilog

# Inside test/Makefile
VERILOG_SOURCES += $(PWD)/../src/tt_um_spi_slave.v
VERILOG_SOURCES += $(PWD)/../src/spi_slave.v
VERILOG_SOURCES += $(PWD)/../src/reg_file.v

TOPLEVEL = tt_um_spi_slave
MODULE   = test

include $(shell cocotb-config --makefiles)/Makefile.sim
