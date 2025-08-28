# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

@cocotb.test()
async def test_basic(dut):
    """Basic test that just passes"""
    dut._log.info("Test starting")

    # Clock
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    
    # Wait
    await ClockCycles(dut.clk, 20)
    
    # Apply some inputs
    dut.ui_in.value = 0x01
    await ClockCycles(dut.clk, 10)
    
    dut.ui_in.value = 0x09
    await ClockCycles(dut.clk, 10)
    
    dut._log.info("Test passed!")

@cocotb.test()
async def test_simple(dut):
    """Another simple test"""
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    dut.ena.value = 1
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 20)
    
    # Done
    pass
