module lif_neuron_system (
    // System signals
    input wire clk,
    input wire reset,
    input wire enable,
    
    // ENHANCED Input channels
    input wire [2:0] chan_a,  
    input wire [2:0] chan_b,  
    
    // Configuration interface
    input wire load_mode,
    input wire serial_data,
    
    // ENHANCED Outputs
    output wire spike_out,
    output wire [6:0] v_mem_out,
    output wire params_ready
);

// Internal parameter wires
wire [2:0] weight_a, weight_b;
wire [1:0] leak_config;
wire [7:0] threshold_min, threshold_max;
wire loader_params_ready;

// ENHANCED: Additional monitoring and control signals
reg [7:0] system_cycles;
reg [4:0] spike_count;

// Enhanced data loader instance
lif_data_loader loader (
    .clk(clk),
    .reset(reset),
    .enable(enable),
    .serial_data_in(serial_data),
    .load_enable(load_mode),
    .weight_a(weight_a),
    .weight_b(weight_b),
    .leak_config(leak_config),
    .threshold_min(threshold_min),
    .threshold_max(threshold_max),
    .params_ready(loader_params_ready)
);

// Enhanced LIF neuron instance
lif_neuron neuron (
    .clk(clk),
    .reset(reset),
    .enable(enable),
    .chan_a(chan_a),
    .chan_b(chan_b),
    .weight_a(weight_a),
    .weight_b(weight_b),
    .leak_config(leak_config),
    .threshold_min(threshold_min),
    .threshold_max(threshold_max),
    .params_ready(loader_params_ready),
    .spike_out(spike_out),
    .v_mem_out(v_mem_out)
);

// ENHANCED: System monitoring and statistics
always @(posedge clk) begin
    if (reset) begin
        system_cycles <= 8'd0;
        spike_count <= 5'd0;
    end else if (enable) begin
        system_cycles <= system_cycles + 1;
        if (spike_out) begin
            if (spike_count < 5'd31)
                spike_count <= spike_count + 1;
        end
    end
end

assign params_ready = loader_params_ready;

endmodule
