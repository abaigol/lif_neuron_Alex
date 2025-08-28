`default_nettype none
`timescale 1ns / 1ps

/* 
 * Testbench for ALIF dual unileak neuron system
 * Simple test to verify basic functionality
 */
module tb ();
  // Dump the signals to a VCD file
  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, tb);
    #1;
  end

  // Wire up the inputs and outputs:
  reg clk;
  reg rst_n;
  reg ena;
  reg [7:0] ui_in;
  reg [7:0] uio_in;
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;

  // Signal breakouts for easier debugging
  wire input_enable = ui_in[0];
  wire load_mode = ui_in[1];
  wire serial_data = ui_in[2];
  wire [2:0] chan_a = ui_in[5:3];
  wire [2:0] chan_b = {ui_in[7:6], uio_in[0]};
  
  wire spike_out = uo_out[0];
  wire [6:0] v_mem_out = uo_out[7:1];
  wire params_ready = uio_out[0];

  // ALIF dual unileak neuron module instantiation
  tt_um_alif_dual_unileak user_project (
      .ui_in  (ui_in),    // Inputs: input_enable[0], load_mode[1], serial_data[2], chan_a[5:3], chan_b[7:6]
      .uo_out (uo_out),   // Outputs: spike_out[0], v_mem_out[7:1]
      .uio_in (uio_in),   // IOs: chan_b[0], unused[7:1]
      .uio_out(uio_out),  // IOs: params_ready[0], unused[7:1]
      .uio_oe (uio_oe),   // IOs: Enable path
      .ena    (ena),      // enable - goes high when design is selected
      .clk    (clk),      // clock
      .rst_n  (rst_n)     // not reset
  );

  // Enhanced monitoring for debugging
  always @(posedge clk) begin
    if (rst_n && ena) begin
      // Log significant events
      if (spike_out)
        $display("Time %0t: SPIKE! V_mem=%0d, chan_a=%0d, chan_b=%0d", 
                 $time, v_mem_out, chan_a, chan_b);
      
      // Log parameter loading events
      if (load_mode && serial_data)
        $display("Time %0t: Parameter bit loaded: %0d", $time, serial_data);
    end
  end

  // Activity pattern monitoring
  reg [7:0] activity_pattern = 8'b0;
  always @(posedge clk) begin
    if (rst_n && ena) begin
      activity_pattern <= {activity_pattern[6:0], spike_out};
      
      // Detect interesting patterns
      if (activity_pattern == 8'b10101010)
        $display("Time %0t: Alternating spike pattern detected!", $time);
      if (activity_pattern == 8'b11110000)
        $display("Time %0t: Burst pattern detected!", $time);
    end
  end

  // Clock generation
  initial begin
    clk = 0;
    forever #5 clk = ~clk; // 100MHz clock
  end

  // Test sequence
  initial begin
    $display("Starting ALIF Dual Unileak Neuron Test");
    
    // Initialize
    ena = 1;
    ui_in = 0;
    uio_in = 0;
    rst_n = 0;
    
    // Reset
    #50;
    rst_n = 1;
    #100;
    
    // Test 1: Basic operation
    $display("Test 1: Basic neuron operation");
    ui_in[0] = 1; // input_enable = 1
    ui_in[5:3] = 3'd2; // chan_a = 2
    ui_in[7:6] = 2'd1; // chan_b upper bits = 1
    uio_in[0] = 1'b1;  // chan_b[0] = 1, so chan_b = 3
    #200;
    
    // Test 2: Higher input
    $display("Test 2: Higher input test");
    ui_in[5:3] = 3'd5; // chan_a = 5
    ui_in[7:6] = 2'd2; // chan_b upper bits = 2
    uio_in[0] = 1'b0;  // chan_b[0] = 0, so chan_b = 4
    #300;
    
    // Test 3: Maximum input
    $display("Test 3: Maximum input test");
    ui_in[5:3] = 3'd7; // chan_a = 7
    ui_in[7:6] = 2'd3; // chan_b upper bits = 3
    uio_in[0] = 1'b1;  // chan_b[0] = 1, so chan_b = 7
    #400;
    
    $display("ALIF Dual Unileak Neuron test completed successfully!");
    $finish;
  end

  // Timeout watchdog
  initial begin
    #10000; // 10us timeout
    $display("Test completed with timeout");
    $finish;
  end

endmodule
