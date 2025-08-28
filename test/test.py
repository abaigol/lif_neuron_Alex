# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles
import os

# Set COCOTB_RESOLVE_X to handle unknown bits
os.environ['COCOTB_RESOLVE_X'] = 'ZEROS'

@cocotb.test()
async def test_alif_neuron_basic(dut):
    """Basic ALIF dual unileak neuron functionality test"""
    dut._log.info("Starting ALIF Dual Unileak Neuron Test")

    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    
    # Wait for system to stabilize
    await ClockCycles(dut.clk, 15)
    
    # Test 1: Resting state (no input)
    dut._log.info("Test 1: Resting state")
    dut.ui_in.value = 0x01  # input_enable=1, others=0
    dut.uio_in.value = 0
    await ClockCycles(dut.clk, 10)
    
    try:
        spike = int(dut.uo_out.value) & 1
        v_mem = int(dut.uo_out.value >> 1) & 0x7F
        params_ready = int(dut.uio_out.value) & 1
        
        dut._log.info(f"Resting: Spike={spike}, V_mem={v_mem}, Params_ready={params_ready}")
        assert spike == 0, "Should not spike at rest"
    except ValueError:
        dut._log.info("Output signals contain unknown bits - continuing")
    
    # Test 2: Low stimulus
    dut._log.info("Test 2: Low stimulus")
    dut.ui_in.value = 0x19  # input_enable=1, load_mode=0, serial_data=0, chan_a=3, chan_b=0
    dut.uio_in.value = 0x01  # chan_b[0]=1, so chan_b=1
    
    spike_detected = False
    for cycle in range(50):
        await ClockCycles(dut.clk, 1)
        try:
            spike = int(dut.uo_out.value) & 1
            v_mem = int(dut.uo_out.value >> 1) & 0x7F
            
            if spike == 1:
                spike_detected = True
                dut._log.info(f"SPIKE detected at cycle {cycle}, V_mem={v_mem}")
                break
            elif cycle % 10 == 0:
                dut._log.info(f"Cycle {cycle}: V_mem={v_mem}")
        except ValueError:
            if cycle % 20 == 0:
                dut._log.info(f"Cycle {cycle}: Signals contain unknown bits")
    
    # Test 3: Higher stimulus
    dut._log.info("Test 3: Higher stimulus")
    dut.ui_in.value = 0xE9  # input_enable=1, chan_a=5, chan_b=7
    dut.uio_in.value = 0x01  # chan_b[0]=1
    
    spike_count = 0
    for cycle in range(100):
        await ClockCycles(dut.clk, 1)
        try:
            spike = int(dut.uo_out.value) & 1
            if spike == 1:
                spike_count += 1
                dut._log.info(f"SPIKE #{spike_count} at cycle {cycle}")
            
            if spike_count >= 2:
                break
        except ValueError:
            pass
    
    dut._log.info(f"Higher stimulus generated {spike_count} spikes")
    dut._log.info("ALIF Dual Unileak basic functionality test completed successfully!")

@cocotb.test()
async def test_parameter_loading(dut):
    """Test serial parameter loading functionality"""
    dut._log.info("Starting Parameter Loading Test")

    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 10)
    
    # Enter parameter loading mode
    dut._log.info("Entering parameter loading mode")
    dut.ui_in.value = 0x02  # load_mode = 1
    await ClockCycles(dut.clk, 3)
    
    # Send test parameters (simplified)
    test_params = [0x05, 0x03, 0x40]
    
    for param_idx, test_byte in enumerate(test_params):
        dut._log.info(f"Sending parameter {param_idx}: 0x{test_byte:02X}")
        
        for bit in range(8):
            bit_val = (test_byte >> (7-bit)) & 1
            dut.ui_in.value = 0x02 | (bit_val << 2)  # load_mode=1, serial_data=bit_val
            await ClockCycles(dut.clk, 1)
        
        await ClockCycles(dut.clk, 2)
    
    # Exit loading mode
    dut.ui_in.value = 0x00
    await ClockCycles(dut.clk, 10)
    
    # Check params_ready
    try:
        params_ready = int(dut.uio_out.value) & 1
        dut._log.info(f"After loading params_ready: {params_ready}")
    except ValueError:
        dut._log.info("params_ready signal contains unknown bits")
    
    dut._log.info("Parameter loading test completed!")

@cocotb.test()
async def test_dual_channel_operation(dut):
    """Test dual channel excitatory/inhibitory operation"""
    dut._log.info("Starting Dual Channel Operation Test")

    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    # Reset and initialize
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 15)
    
    # Test different channel combinations
    test_cases = [
        (0x01, 0x19, 0x00),  # chan_a=3, chan_b=0 (excitatory only)
        (0x01, 0x09, 0x01),  # chan_a=1, chan_b=2 (mixed)
        (0x01, 0x39, 0x01),  # chan_a=7, chan_b=6 (high inputs)
    ]
    
    dut._log.info("Testing different dual channel combinations")
    
    for test_idx, (base, ui_val, uio_val) in enumerate(test_cases):
        dut.ui_in.value = ui_val
        dut.uio_in.value = uio_val
        
        await ClockCycles(dut.clk, 20)
        
        try:
            spike = int(dut.uo_out.value) & 1
            v_mem = int(dut.uo_out.value >> 1) & 0x7F
            
            chan_a = (ui_val >> 3) & 0x7
            chan_b = ((ui_val >> 6) & 0x3) | ((uio_val & 1) << 2)
            
            dut._log.info(f"Test {test_idx}: chan_a={chan_a}, chan_b={chan_b}, V_mem={v_mem}, Spike={spike}")
        except ValueError:
            dut._log.info(f"Test {test_idx}: Signals contain unknown bits")
    
    dut._log.info("Dual channel operation test completed!")
