import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer

async def spi_txn(dut, addr, data, is_read=False):
    # 1. Read current value of the input bus as an integer safely
    current_val = int(dut.uio_in.value) if dut.uio_in.value.is_resolvable else 0
    
    # 2. Force CS low by clearing bit 2 (uio_in[2] = CS_N)
    current_val = current_val & ~(1 << 2)
    dut.uio_in.value = current_val
    await Timer(20, unit="ns")

    # Command Byte: Bit 7 is R/W (1 for read, 0 for write), bits 2:0 are the address
    cmd_byte = (1 << 7 if is_read else 0) | (addr & 0x07)
    
    # Send Command Byte
    for i in range(8):
        bit = (cmd_byte >> (7 - i)) & 0x01
        # Set MOSI data bit (bit 1)
        current_val = (current_val & ~(1 << 1)) | (bit << 1)
        # Pull SCLK Low (bit 0)
        dut.uio_in.value = current_val & ~(1 << 0)
        await Timer(20, unit="ns")
        # Pull SCLK High
        dut.uio_in.value = current_val | (1 << 0)
        await Timer(20, unit="ns")

    # Send or Receive Data Byte Phase
    read_data = 0
    for i in range(8):
        if is_read:
            # Pull SCLK Low: Read data from MISO (uio_out[3])
            dut.uio_in.value = current_val & ~(1 << 0)
            await Timer(20, unit="ns")
            # Pull SCLK High
            dut.uio_in.value = current_val | (1 << 0)
            await Timer(20, unit="ns")
            # Sample the bit from the output path array
            bit = (int(dut.uio_out.value) >> 3) & 0x01
            read_data = (read_data << 1) | bit
        else:
            bit = (data >> (7 - i)) & 0x01
            current_val = (current_val & ~(1 << 1)) | (bit << 1)
            # Pull SCLK Low
            dut.uio_in.value = current_val & ~(1 << 0)
            await Timer(20, unit="ns")
            # Pull SCLK High
            dut.uio_in.value = current_val | (1 << 0)
            await Timer(20, unit="ns")

    # 3. Pull CS_N back high (uio_in[2] = 1) and clear clock/data lines
    current_val = int(dut.uio_in.value)
    current_val = (current_val | (1 << 2)) & ~(1 << 0) & ~(1 << 1)
    dut.uio_in.value = current_val
    await Timer(20, unit="ns")
    
    return read_data

@cocotb.test()
async def test_01_reset(dut):
    dut._log.info("Running Test 01: Reset System...")
    clock = Clock(dut.clk, 20, unit="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0x04 # CS_N starts high
    await Timer(100, unit="ns")
    dut.rst_n.value = 1
    await Timer(20, unit="ns")
    dut._log.info("PASS: Reset complete")

@cocotb.test()
async def test_02_write_reg0(dut):
    dut._log.info("Running Test 02: Write to Register 0...")
    clock = Clock(dut.clk, 20, unit="ns")
    cocotb.start_soon(clock.start())
    
    # Initialize values
    dut.rst_n.value = 0
    dut.ena.value = 1
    dut.uio_in.value = 0x04
    await Timer(40, unit="ns")
    dut.rst_n.value = 1
    await Timer(20, unit="ns")

    # Write 0xAB to Register address 0
    await spi_txn(dut, addr=0, data=0xAB)
    await Timer(40, unit="ns")
    
    assert dut.uo_out.value == 0xAB, f"Expected 0xAB on uo_out, got {hex(int(dut.uo_out.value))}"
    dut._log.info("PASS: Successfully wrote 0xAB to Register 0")

@cocotb.test()
async def test_03_write_reg3(dut):
    dut._log.info("Running Test 03: Write to Register 3...")
    clock = Clock(dut.clk, 20, unit="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.ena.value = 1
    dut.uio_in.value = 0x04
    await Timer(40, unit="ns")
    dut.rst_n.value = 1
    await Timer(20, unit="ns")

    # Write 0x5A to Register 3
    await spi_txn(dut, addr=3, data=0x5A)
    await Timer(40, unit="ns")
    dut._log.info("PASS: Successfully finished Register 3 transaction")

@cocotb.test()
async def test_04_read_reg0(dut):
    dut._log.info("Running Test 04: Write and Read back Register 0...")
    clock = Clock(dut.clk, 20, unit="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.ena.value = 1
    dut.uio_in.value = 0x04
    await Timer(40, unit="ns")
    dut.rst_n.value = 1
    await Timer(20, unit="ns")

    # Write 0xC3 to Register 0
    await spi_txn(dut, addr=0, data=0xC3)
    await Timer(40, unit="ns")
    
    # Read it back
    read_val = await spi_txn(dut, addr=0, data=0x00, is_read=True)
    assert read_val == 0xC3, f"Expected to read back 0xC3, but got {hex(read_val)}"
    dut._log.info("PASS: Successfully read back 0xC3 from Register 0")

@cocotb.test()
async def test_05_multi_reg(dut):
    dut._log.info("Running Test 05: Multi-Register Sequence...")
    clock = Clock(dut.clk, 20, unit="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.ena.value = 1
    dut.uio_in.value = 0x04
    await Timer(40, unit="ns")
    dut.rst_n.value = 1
    await Timer(20, unit="ns")

    # Sequential write checks
    test_data = {1: 0x11, 2: 0x22, 5: 0x55, 7: 0x77}
    for addr, val in test_data.items():
        await spi_txn(dut, addr=addr, data=val)
        await Timer(20, unit="ns")
        
    for addr, val in test_data.items():
        read_val = await spi_txn(dut, addr=addr, data=0x00, is_read=True)
        assert read_val == val, f"Addr {addr}: Expected {hex(val)}, got {hex(read_val)}"
        
    dut._log.info("PASS: Multi-register tracking test fully verified!")
