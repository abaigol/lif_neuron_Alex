

module alif_dual_unileak_system (
    // System signals
    input wire clk,
    input wire reset,
    input wire enable,
    input wire input_enable,  // New pin for neuron operation control
    
    // Input channels
    input wire [2:0] chan_a,  // 3-bit precision
    input wire [2:0] chan_b,  // 3-bit precision
    
    // Configuration interface
    input wire load_mode,
    input wire serial_data,
    
    // Outputs
    output wire spike_out,
    output wire [6:0] v_mem_out,
    output wire params_ready
);

// Internal parameter wires
wire [2:0] weight_a, weight_b;
wire [7:0] leak_rate;
wire [7:0] threshold_min;
wire [3:0] leak_cycles;
wire loader_params_ready;

// Data loader instance
alif_dual_unileak_data_loader loader (
    .clk(clk),
    .reset(reset),
    .enable(enable),
    .serial_data_in(serial_data),
    .load_enable(load_mode),
    .weight_a(weight_a),
    .weight_b(weight_b),
    .leak_rate(leak_rate),
    .threshold_min(threshold_min),
    .leak_cycles(leak_cycles),
    .params_ready(loader_params_ready)
);

// LIF neuron instance
alif_dual_unileak_neuron neuron (
    .clk(clk),
    .reset(reset),
    .enable(enable),
    .input_enable(input_enable),
    .chan_a(chan_a),
    .chan_b(chan_b),
    .weight_a(weight_a),
    .weight_b(weight_b),
    .leak_rate(leak_rate),
    .threshold_min(threshold_min),
    .leak_cycles(leak_cycles),
    .params_ready(loader_params_ready),
    .spike_out(spike_out),
    .v_mem_out(v_mem_out)
);

assign params_ready = loader_params_ready;

endmodule
