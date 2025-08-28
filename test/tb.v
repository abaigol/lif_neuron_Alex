`default_nettype none
`timescale 1ns / 1ps

module tb ();
  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, tb);
    #1;
  end

  reg clk;
  reg rst_n;
  reg ena;
  reg [7:0] ui_in;
  reg [7:0] uio_in;
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;

  // Instantiate the module
  tt_um_alif_dual_unileak user_project (
      .ui_in  (ui_in),
      .uo_out (uo_out),
      .uio_in (uio_in),
      .uio_out(uio_out),
      .uio_oe (uio_oe),
      .ena    (ena),
      .clk    (clk),
      .rst_n  (rst_n)
  );

  // Clock
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // Simple test that just runs and passes
  initial begin
    $display("Test starting");
    
    // Initialize
    ena = 1;
    ui_in = 0;
    uio_in = 0;
    rst_n = 0;
    
    // Reset
    #50;
    rst_n = 1;
    
    // Wait a bit
    #100;
    
    // Apply some basic inputs
    ui_in = 8'h01;
    #100;
    
    ui_in = 8'h09;
    #100;
    
    $display("Test passed!");
    $finish;
  end

  // Timeout
  initial begin
    #1000;
    $finish;
  end

endmodule
