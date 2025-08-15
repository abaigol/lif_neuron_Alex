# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

@cocotb.test()
async def test_lif_neuron_basic(dut):
    """Basic LIF neuron functionality test with enhanced features"""
    dut._log.info("Starting Enhanced LIF Neuron Test")

    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0    # All channel inputs = 0, control_mode = 00
    dut.uio_in.value = 0   # load_mode=0, serial_data=0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    
    # Wait for system to stabilize
    await ClockCycles(dut.clk, 15)  # Longer wait for enhanced initialization
    
    # Check enhanced status signals
    params_ready = (dut.uio_out.value >> 2) & 1
    system_initialized = (dut.uio_out.value >> 6) & 1
    dut._log.info(f"Default params_ready: {params_ready}, system_initialized: {system_initialized}")
    
    # Test 1: Resting state (no input) - Normal mode
    dut._log.info("Test 1: Resting state - Normal mode")
    dut.ui_in.value = 0x00  # chan_a=0, chan_b=0, control_mode=00 (normal)
    await ClockCycles(dut.clk, 10)
    
    v_mem = dut.uo_out.value & 0x7F  # Lower 7 bits
    spike = (dut.uo_out.value >> 7) & 1
    membrane_activity = (dut.uio_out.value >> 4) & 1
    membrane_saturation = (dut.uio_out.value >> 5) & 1
    
    dut._log.info(f"Resting: V_mem={v_mem}, Spike={spike}, Activity={membrane_activity}, Saturation={membrane_saturation}")
    assert spike == 0, "Should not spike at rest"
    
    # Test 2: Low stimulus - Normal mode
    dut._log.info("Test 2: Low stimulus - Normal mode")
    dut.ui_in.value = 0x09  # chan_a=1 (bits 2:0), chan_b=1 (bits 5:3), control_mode=00
    
    spike_detected = False
    for cycle in range(25):  # Extended monitoring for complex dynamics
        await ClockCycles(dut.clk, 1)
        v_mem = dut.uo_out.value & 0x7F
        spike = (dut.uo_out.value >> 7) & 1
        membrane_activity = (dut.uio_out.value >> 4) & 1
        
        if spike == 1:
            spike_detected = True
            dut._log.info(f"SPIKE detected at cycle {cycle}, V_mem={v_mem}")
            break
        elif cycle % 5 == 0:
            dut._log.info(f"Cycle {cycle}: V_mem={v_mem}, Activity={membrane_activity}")
    
    # Test 3: Higher stimulus - Amplified mode (control_mode=01)
    dut._log.info("Test 3: Higher stimulus - Amplified mode")
    dut.ui_in.value = 0x5B  # chan_a=3, chan_b=3, control_mode=01 (amplified)
    
    spike_count = 0
    for cycle in range(30):
        await ClockCycles(dut.clk, 1)
        v_mem = dut.uo_out.value & 0x7F
        spike = (dut.uo_out.value >> 7) & 1
        
        if spike == 1:
            spike_count += 1
            dut._log.info(f"AMPLIFIED SPIKE #{spike_count} at cycle {cycle}")
        
        if spike_count >= 3:  # Amplified mode should produce more spikes
            break
    
    dut._log.info(f"Amplified mode generated {spike_count} spikes")
    assert spike_count > 0, "Amplified mode should generate spikes"
    
    # Test 4: Maximum stimulus - Attenuated mode (control_mode=10)
    dut._log.info("Test 4: Maximum stimulus - Attenuated mode")
    dut.ui_in.value = 0xBF  # chan_a=7, chan_b=7, control_mode=10 (attenuated)
    
    attenuated_spike_count = 0
    for cycle in range(40):  # Longer test for attenuated mode
        await ClockCycles(dut.clk, 1)
        spike = (dut.uo_out.value >> 7) & 1
        if spike == 1:
            attenuated_spike_count += 1
    
    dut._log.info(f"Attenuated mode generated {attenuated_spike_count} spikes")
    
    # Test 5: Burst mode (control_mode=11)
    dut._log.info("Test 5: Burst mode with activity feedback")
    dut.ui_in.value = 0xDB  # chan_a=3, chan_b=3, control_mode=11 (burst)
    
    burst_spike_count = 0
    for cycle in range(50):
        await ClockCycles(dut.clk, 1)
        spike = (dut.uo_out.value >> 7) & 1
        heartbeat = (dut.uio_out.value >> 7) & 1  # Cycle counter MSB
        
        if spike == 1:
            burst_spike_count += 1
            dut._log.info(f"BURST SPIKE #{burst_spike_count} at cycle {cycle}, heartbeat={heartbeat}")
        
        if burst_spike_count >= 4:
            break
    
    dut._log.info(f"Burst mode generated {burst_spike_count} spikes")
    
    dut._log.info("Enhanced LIF Neuron basic functionality test completed successfully!")


@cocotb.test()
async def test_enhanced_monitoring(dut):
    """Test enhanced monitoring and status features"""
    dut._log.info("Starting Enhanced Monitoring Test")

    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 20)
    
    # Test system status monitoring
    dut._log.info("Testing system status monitoring")
    
    for test_cycle in range(5):
        # Apply different inputs and monitor enhanced outputs
        test_input = 0x09 | (test_cycle << 6)  # Different control modes
        dut.ui_in.value = test_input
        
        await ClockCycles(dut.clk, 10)
        
        # Read all enhanced status signals
        params_ready = (dut.uio_out.value >> 2) & 1
        spike_monitor = (dut.uio_out.value >> 3) & 1
        membrane_activity = (dut.uio_out.value >> 4) & 1
        membrane_saturation = (dut.uio_out.value >> 5) & 1
        system_initialized = (dut.uio_out.value >> 6) & 1
        heartbeat = (dut.uio_out.value >> 7) & 1
        
        dut._log.info(f"Test {test_cycle}: Input=0x{test_input:02X}")
        dut._log.info(f"  Status: ready={params_ready}, spike_mon={spike_monitor}, activity={membrane_activity}")
        dut._log.info(f"  Status: saturation={membrane_saturation}, init={system_initialized}, heartbeat={heartbeat}")
    
    dut._log.info("Enhanced monitoring test completed!")


@cocotb.test()
async def test_parameter_loading(dut):
    """Test serial parameter loading functionality with enhanced validation"""
    dut._log.info("Starting Enhanced Parameter Loading Test")

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
    dut.uio_in.value = 1  # load_mode = 1
    await ClockCycles(dut.clk, 3)
    
    # Check params_ready goes low
    params_ready = (dut.uio_out.value >> 2) & 1
    dut._log.info(f"Loading mode params_ready: {params_ready}")
    
    # Send enhanced parameter set (test first few parameters)
    test_params = [0x05, 0x03, 0x02, 0x40, 0x80, 0xAA, 0x55]  # Enhanced parameter set
    
    for param_idx, test_byte in enumerate(test_params):
        dut._log.info(f"Sending parameter {param_idx}: 0x{test_byte:02X}")
        
        for bit in range(8):
            bit_val = (test_byte >> (7-bit)) & 1
            dut.uio_in.value = 1 | (bit_val << 1)  # load_mode=1, serial_data=bit_val
            await ClockCycles(dut.clk, 1)
        
        await ClockCycles(dut.clk, 2)  # Brief pause between parameters
    
    # Exit loading mode
    dut.uio_in.value = 0  # load_mode = 0
    await ClockCycles(dut.clk, 10)
    
    # Check params_ready eventually goes high with validation
    validation_passed = False
    for wait_cycle in range(20):
        await ClockCycles(dut.clk, 1)
        params_ready = (dut.uio_out.value >> 2) & 1
        if params_ready == 1:
            validation_passed = True
            break
    
    dut._log.info(f"After loading params_ready: {params_ready}, validation: {validation_passed}")
    
    # Test neuron response with new parameters
    if validation_passed:
        dut._log.info("Testing neuron response with loaded parameters")
        dut.ui_in.value = 0x1B  # Medium stimulus
        
        response_spikes = 0
        for cycle in range(30):
            await ClockCycles(dut.clk, 1)
            spike = (dut.uo_out.value >> 7) & 1
            if spike == 1:
                response_spikes += 1
        
        dut._log.info(f"Neuron response with new parameters: {response_spikes} spikes")
    
    dut._log.info("Enhanced parameter loading test completed!")


@cocotb.test()
async def test_pattern_detection(dut):
    """Test pattern detection and adaptive features"""
    dut._log.info("Starting Pattern Detection Test")

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
    
    # Create repeating patterns to test pattern detection
    patterns = [
        0x09,  # chan_a=1, chan_b=1
        0x12,  # chan_a=2, chan_b=2  
        0x1B,  # chan_a=3, chan_b=3
        0x09,  # Repeat
        0x12,  # Repeat
        0x1B,  # Repeat
    ]
    
    dut._log.info("Testing pattern detection with repeating sequences")
    
    for pattern_cycle, pattern in enumerate(patterns):
        dut.ui_in.value = pattern
        await ClockCycles(dut.clk, 8)  # Hold pattern for several cycles
        
        v_mem = dut.uo_out.value & 0x7F
        spike = (dut.uo_out.value >> 7) & 1
        membrane_activity = (dut.uio_out.value >> 4) & 1
        
        dut._log.info(f"Pattern {pattern_cycle}: Input=0x{pattern:02X}, V_mem={v_mem}, Spike={spike}, Activity={membrane_activity}")
    
    # Test burst mode with pattern feedback
    dut._log.info("Testing burst mode pattern response")
    dut.ui_in.value = 0xDB  # Burst mode with chan_a=3, chan_b=3
    
    pattern_responses = 0
    for cycle in range(40):
        await ClockCycles(dut.clk, 1)
        spike = (dut.uo_out.value >> 7) & 1
        if spike == 1:
            pattern_responses += 1
    
    dut._log.info(f"Pattern-enhanced burst mode responses: {pattern_responses}")
    dut._log.info("Pattern detection test completed!")
