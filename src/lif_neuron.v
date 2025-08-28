

module alif_dual_unileak_neuron (
    // System signals
    input wire clk,
    input wire reset,
    input wire enable,
    input wire input_enable,  // New input enable control
    
    // Input channels
    input wire [2:0] chan_a,  // 3-bit precision (0-7)
    input wire [2:0] chan_b,  // 3-bit precision (0-7)
    
    // Configuration from loader
    input wire [2:0] weight_a,
    input wire [2:0] weight_b,
    input wire [7:0] leak_rate,      // 8-bit leak rate precision
    input wire [7:0] threshold_min,
    input wire [3:0] leak_cycles,    // Cycles between leak operations
    input wire params_ready,
    
    // Outputs
    output reg spike_out,
    output wire [6:0] v_mem_out  // 7-bit membrane potential output
);

// LIF parameters
parameter V_BITS = 8;
parameter THR_UP = 8'd4;   // Threshold increase after spike
parameter THR_DN = 8'd1;   // Threshold decrease when silent
parameter REFRAC_PERIOD = 4'd4; // Fixed refractory period

// State registers
reg signed [V_BITS:0] v_mem = 0;     // Membrane potential (9-bit signed to handle negative values)
reg [V_BITS-1:0] threshold;          // Adaptive threshold
reg [3:0] refr_cnt = 0;              // Refractory counter
reg [3:0] leak_counter = 0;          // Counter for leak cycles

// Calculate threshold_max as 2 * threshold_min
wire [7:0] threshold_max = threshold_min << 1;  // threshold_max = 2 * threshold_min

// Input contributions with channel B subtraction: vmem = wa*inpa - wb*inpb
wire signed [5:0] contrib_a = chan_a * weight_a;  // Direct weight usage - no depression
wire signed [5:0] contrib_b = chan_b * weight_b;  // Direct weight usage - no depression
wire signed [6:0] weighted_sum = contrib_a - contrib_b; // Can be negative

// Membrane potential output (map to 7 bits, ensure positive)
assign v_mem_out = (v_mem > 0) ? v_mem[6:0] : 7'd0;

// Temporary variable for membrane potential calculation
reg signed [V_BITS:0] new_v; // 9-bit signed temporary

// Main LIF dynamics
always @(posedge clk) begin
    if (reset) begin
        v_mem <= 9'd0;
        threshold <= threshold_min;
        refr_cnt <= 4'd0;
        spike_out <= 1'b0;
        leak_counter <= 4'd0;
    end else if (enable && params_ready) begin
        // Increment leak counter
        leak_counter <= leak_counter + 1;
        
        // Refractory period handling - SIMPLIFIED
        if (refr_cnt != 0) begin
            refr_cnt <= refr_cnt - 1;
            spike_out <= 1'b0;
            // NO leakage, NO processing - pure silence
            
        end else if (input_enable) begin
            // Normal operation: integrate and leak
            
            // Integration with input - NEW EQUATION: vmem = vmem + wa*inpa - wb*inpb
            new_v = v_mem + weighted_sum;
            
            // Apply leak if leak cycle elapsed
            if (leak_counter >= leak_cycles) begin
                leak_counter <= 4'd0;
                new_v = new_v - leak_rate;
            end
            
            // Prevent underflow (negative membrane potential)
            if (new_v < 0)
                new_v = 9'd0;
            
            // Prevent overflow
            if (new_v > 255)
                new_v = 255;
            
            // Spike detection
            if (new_v >= threshold) begin
                spike_out <= 1'b1;
                v_mem <= 9'd0;  // Reset membrane potential
                refr_cnt <= REFRAC_PERIOD;
                
                // Adaptive threshold increase
                if (threshold + THR_UP <= threshold_max)
                    threshold <= threshold + THR_UP;
                else
                    threshold <= threshold_max;
                    
            end else begin
                spike_out <= 1'b0;
                v_mem <= new_v;
                
                // Adaptive threshold decrease (only during leak cycles)
                if (leak_counter >= leak_cycles) begin
                    if (threshold > threshold_min + THR_DN)
                        threshold <= threshold - THR_DN;
                    else
                        threshold <= threshold_min;
                end
            end
        end else begin
            // input_enable is low, hold current state
            spike_out <= 1'b0;
        end
    end else begin
        // Hold state when disabled or params not ready
        spike_out <= 1'b0;
    end
end

endmodule
