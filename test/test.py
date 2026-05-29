"""
test.py — cocotb testbench for tt_um_spi_slave
Run with: cd test && make

Tests:
  1. Reset — all outputs are 0
  2. SPI write — write 0xAB to reg[0], check uo_out
  3. SPI write different reg — write 0x5A to reg[3]
  4. SPI read  — read back reg[0] via MISO
  5. SPI read  — read back reg[3] via MISO
  6. Multiple writes — verify each register holds its value
"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles, Timer


# ── SPI helper: one full 16-clock transaction ─────────────────────────────────
async def spi_txn(dut, addr, data=0x00, read=False):
    """
    addr  : 3-bit register address (0–7)
    data  : 8-bit data to write (ignored on read)
    read  : True = read transaction
    Returns received MISO byte on read, else None.
    """
    HALF = 100  # ns — 5 MHz SPI, well within 50 MHz system clock

    addr_byte = ((0x80 if read else 0x00) | (addr & 0x07))
    miso_bits = []

    # CS assert (active low)
    dut.uio_in.value = dut.uio_in.value & ~(1 << 2)  # CS low
    await Timer(HALF, units='ns')

    # Send address byte MSB first
    for i in range(7, -1, -1):
        bit = (addr_byte >> i) & 1
        # set MOSI and SCLK low
        uio = (dut.uio_in.value & ~0x03) | (bit << 1)
        dut.uio_in.value = uio
        await Timer(HALF, units='ns')
        # SCLK high — slave samples MOSI
        dut.uio_in.value = uio | 0x01
        miso_bits.append(int((dut.uio_out.value >> 3) & 1))
        await Timer(HALF, units='ns')

    # SCLK low between bytes
    dut.uio_in.value = dut.uio_in.value & ~0x01
    await Timer(HALF, units='ns')

    # Send/receive data byte MSB first
    for i in range(7, -1, -1):
        bit = 0 if read else ((data >> i) & 1)
        uio = (dut.uio_in.value & ~0x03) | (bit << 1)
        dut.uio_in.value = uio
        await Timer(HALF, units='ns')
        dut.uio_in.value = uio | 0x01
        miso_bits.append(int((dut.uio_out.value >> 3) & 1))
        await Timer(HALF, units='ns')

    # SCLK low, CS deassert
    dut.uio_in.value = (dut.uio_in.value & ~0x01) | (1 << 2)
    await Timer(HALF * 2, units='ns')

    if read:
        rx = 0
        for b in miso_bits[8:]:   # last 8 bits = data phase
            rx = (rx << 1) | b
        return rx
    return None


# ── Test 1: reset ─────────────────────────────────────────────────────────────
@cocotb.test()
async def test_01_reset(dut):
    cocotb.start_soon(Clock(dut.clk, 20, units='ns').start())
    dut.ui_in.value  = 0
    dut.uio_in.value = 0b00000100   # CS high, SCLK low, MOSI low
    dut.ena.value    = 1
    dut.rst_n.value  = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value  = 1
    await ClockCycles(dut.clk, 2)

    assert dut.uo_out.value == 0, f"Expected 0 after reset, got {int(dut.uo_out.value):#x}"
    dut._log.info("PASS: reset")


# ── Test 2: SPI write reg[0] ──────────────────────────────────────────────────
@cocotb.test()
async def test_02_write_reg0(dut):
    cocotb.start_soon(Clock(dut.clk, 20, units='ns').start())
    dut.ui_in.value  = 0
    dut.uio_in.value = 0b00000100
    dut.ena.value    = 1
    dut.rst_n.value  = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value  = 1
    await ClockCycles(dut.clk, 2)

    await spi_txn(dut, addr=0, data=0xAB)
    await ClockCycles(dut.clk, 4)

    assert int(dut.uo_out.value) == 0xAB, \
        f"reg[0] expected 0xAB, got {int(dut.uo_out.value):#x}"
    dut._log.info("PASS: write reg[0] = 0xAB")


# ── Test 3: SPI write reg[3] ──────────────────────────────────────────────────
@cocotb.test()
async def test_03_write_reg3(dut):
    cocotb.start_soon(Clock(dut.clk, 20, units='ns').start())
    dut.ui_in.value  = 0
    dut.uio_in.value = 0b00000100
    dut.ena.value    = 1
    dut.rst_n.value  = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value  = 1
    await ClockCycles(dut.clk, 2)

    await spi_txn(dut, addr=3, data=0x5A)
    await ClockCycles(dut.clk, 4)

    # reg[0] still 0, reg[3] holds 0x5A — read it back to verify
    rx = await spi_txn(dut, addr=3, read=True)
    assert rx == 0x5A, f"reg[3] expected 0x5A, got {rx:#x}"
    dut._log.info("PASS: write reg[3] = 0x5A")


# ── Test 4: SPI read reg[0] ───────────────────────────────────────────────────
@cocotb.test()
async def test_04_read_reg0(dut):
    cocotb.start_soon(Clock(dut.clk, 20, units='ns').start())
    dut.ui_in.value  = 0
    dut.uio_in.value = 0b00000100
    dut.ena.value    = 1
    dut.rst_n.value  = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value  = 1
    await ClockCycles(dut.clk, 2)

    await spi_txn(dut, addr=0, data=0xC3)
    await ClockCycles(dut.clk, 4)

    rx = await spi_txn(dut, addr=0, read=True)
    assert rx == 0xC3, f"MISO read expected 0xC3, got {rx:#x}"
    dut._log.info("PASS: read reg[0] via MISO = 0xC3")


# ── Test 5: multiple registers hold values independently ──────────────────────
@cocotb.test()
async def test_05_multi_reg(dut):
    cocotb.start_soon(Clock(dut.clk, 20, units='ns').start())
    dut.ui_in.value  = 0
    dut.uio_in.value = 0b00000100
    dut.ena.value    = 1
    dut.rst_n.value  = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value  = 1
    await ClockCycles(dut.clk, 2)

    # Write different values to 4 registers
    writes = {0: 0x11, 1: 0x22, 2: 0x33, 3: 0x44}
    for addr, val in writes.items():
        await spi_txn(dut, addr=addr, data=val)
        await ClockCycles(dut.clk, 4)

    # Read back and verify each
    for addr, expected in writes.items():
        rx = await spi_txn(dut, addr=addr, read=True)
        await ClockCycles(dut.clk, 4)
        assert rx == expected, \
            f"reg[{addr}] expected {expected:#x}, got {rx:#x}"

    dut._log.info("PASS: all 4 registers hold independent values")
