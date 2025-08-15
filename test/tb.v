`default_nettype none
`timescale 1ns / 1ps

/* 
 * Enhanced testbench for LIF neuron with complex dynamics
 * Tests all enhanced features including control modes and monitoring
 */

module tb ();

  // Dump the signals to a VCD file with enhanced signal visibility
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

  // Enhanced signal breakouts for easier debugging
  wire [2:0] chan_a = ui_in[2:0];
  wire [2:0] chan_b = ui_in[5:3];
  wire [1:0] control_mode = ui_in[7:6];
  
  wire load_mode = uio_in[0];
  wire serial_data = uio_in[1];
  
  wire [6:0] v_mem = uo_out[6:0];
  wire spike = uo_out[2];
  
  wire params_ready = uio_out[3];
  wire spike_monitor = uio_out[4];
  wire membrane_activity = uio_out[5];
  wire membrane_saturation = uio_out[6];
  wire system_initialized = uio_out[7];
  wire heartbeat = uio_out[2];

  // Enhanced LIF neuron module instantiation
  tt_um_lif_neuron user_project (
      .ui_in  (ui_in),    // Enhanced inputs: Channel A[2:0], Channel B[5:3], Control Mode[7:6]
      .uo_out (uo_out),   // Enhanced outputs: V_mem[6:0], Spike[7]
      .uio_in (uio_in),   // Enhanced IOs: load_mode, serial_data[1], learning_enable[3], pattern_mode[4]
      .uio_out(uio_out),  // Enhanced outputs: params_ready[3], spike_monitor[4], activity[5], saturation[6], init[7], heartbeat[2]
      .uio_oe (uio_oe),   // IOs: Enable path (0=input, 1=output)
      .ena    (ena),      // enable - goes high when design is selected
      .clk    (clk),      // clock
      .rst_n  (rst_n)     // not reset
  );

  // Enhanced monitoring for debugging
  always @(posedge clk) begin
    if (rst_n && ena) begin
      // Log significant events
      if (spike)
        $display("Time %0t: SPIKE! V_mem=%0d, chan_a=%0d, chan_b=%0d, mode=%0d", 
                 $time, v_mem, chan_a, chan_b, control_mode);
      
      // Log parameter loading events
      if (load_mode && serial_data)
        $display("Time %0t: Parameter bit loaded: %0d", $time, serial_data);
      
      // Log mode changes
      if (control_mode != 2'b00)
        $display("Time %0t: Enhanced mode active: %0d", $time, control_mode);
    end
  end

  // Enhanced system state monitoring
  reg [1:0] prev_control_mode = 2'b00;
  always @(posedge clk) begin
    if (rst_n && ena) begin
      if (control_mode != prev_control_mode) begin
        case (control_mode)
          2'b00: $display("Time %0t: Switched to NORMAL mode", $time);
          2'b01: $display("Time %0t: Switched to AMPLIFIED mode", $time);
          2'b10: $display("Time %0t: Switched to ATTENUATED mode", $time);
          2'b11: $display("Time %0t: Switched to BURST mode", $time);
        endcase
        prev_control_mode <= control_mode;
      end
    end
  end

  // Activity pattern monitoring
  reg [7:0] activity_pattern = 8'b0;
  always @(posedge clk) begin
    if (rst_n && ena) begin
      activity_pattern <= {activity_pattern[6:0], spike};
      
      // Detect interesting patterns
      if (activity_pattern == 8'b10101010)
        $display("Time %0t: Alternating spike pattern detected!", $time);
      if (activity_pattern == 8'b11110000)
        $display("Time %0t: Burst pattern detected!", $time);
    end
  end

endmodule
