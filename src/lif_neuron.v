module lif_neuron (
    // System signals
    input wire clk,
    input wire reset,
    input wire enable,
    
    // Input channels - ENHANCED PRECISION
    input wire [2:0] chan_a,  // 3-bit precision (0-7)
    input wire [2:0] chan_b,  // 3-bit precision (0-7)
    
    // Configuration from loader - EXPANDED
    input wire [2:0] weight_a,
    input wire [2:0] weight_b,
    input wire [1:0] leak_config,
    input wire [7:0] threshold_min,
    input wire [7:0] threshold_max,
    input wire params_ready,
    
    // Outputs
    output reg spike_out,
    output wire [6:0] v_mem_out
);

// ENHANCED LIF parameters for more complex dynamics
parameter V_BITS = 8;
parameter THR_UP = 8'd4;
parameter THR_DN = 8'd1;
parameter REFRAC_PERIOD = 4'd4;

// EXPANDED STATE - More complex internal dynamics
reg [V_BITS-1:0] v_mem = 0;           // Membrane potential
reg [V_BITS-1:0] threshold;           // Adaptive threshold
reg [3:0] refr_cnt = 0;               // Refractory counter
reg [2:0] depress_a = 0;              // Short-term depression A
reg [2:0] depress_b = 0;              // Short-term depression B

// NEW: Additional state variables for complex dynamics
reg [7:0] calcium_trace = 0;          // Calcium concentration simulation
reg [4:0] spike_history = 0;          // Last 5 spike history
reg [3:0] burst_counter = 0;          // Burst detection counter
reg [6:0] adaptation_level = 0;       // Long-term adaptation
reg [7:0] noise_lfsr = 8'hA3;         // Linear feedback shift register for noise
reg [5:0] pattern_memory = 0;         // Input pattern memory
reg [7:0] homeostatic_target = 8'd50; // Target activity level
reg [7:0] activity_tracker = 0;       // Recent activity tracker

// ENHANCED: Multiple leak rates with more complexity
reg [2:0] leak_rate;
reg [2:0] adaptive_leak;  // Activity-dependent leak
always @(*) begin
    case (leak_config)
        2'b00: leak_rate = 3'd1;
        2'b01: leak_rate = 3'd2;
        2'b10: leak_rate = 3'd3;
        default: leak_rate = 3'd4;
    endcase
    
    // Adaptive leak based on activity
    adaptive_leak = leak_rate + (activity_tracker > homeostatic_target ? 2'd2 : 2'd0);
end

// ENHANCED: Complex weight computation with multiple factors
wire [2:0] base_weight_a = (weight_a > depress_a) ? (weight_a - depress_a) : 3'd0;
wire [2:0] base_weight_b = (weight_b > depress_b) ? (weight_b - depress_b) : 3'd0;

// Calcium-dependent weight scaling
wire [3:0] calcium_scale = (calcium_trace > 8'd100) ? 4'd2 : 4'd4;
wire [2:0] eff_weight_a = (base_weight_a * calcium_scale) >> 2;
wire [2:0] eff_weight_b = (base_weight_b * calcium_scale) >> 2;

// ENHANCED: Complex input processing with pattern detection
wire [5:0] contrib_a = chan_a * eff_weight_a;
wire [5:0] contrib_b = chan_b * eff_weight_b;

// Pattern-based modulation
wire [2:0] current_pattern = chan_a[1:0] + chan_b[1:0]; 
wire pattern_match = (current_pattern == pattern_memory[2:0]);
wire [1:0] pattern_boost = pattern_match ? 2'd2 : 2'd0;

wire [7:0] weighted_sum = contrib_a + contrib_b + pattern_boost;

// ENHANCED: Noise generation using LFSR
wire noise_bit = noise_lfsr[7] ^ noise_lfsr[1] ^ noise_lfsr[2] ^ noise_lfsr[3];
wire [1:0] neural_noise = {noise_bit, noise_lfsr}; // 2-bit noise

// Membrane potential output with enhanced precision
assign v_mem_out = v_mem[7:1];

// ENHANCED: Multiple temporary registers for complex computations
reg [9:0] new_v;
reg [8:0] calcium_update;
reg [7:0] threshold_update;
reg [7:0] activity_update;

// MASSIVELY ENHANCED: Main LIF dynamics with complex behaviors
always @(posedge clk) begin
    if (reset) begin
        v_mem <= 8'd0;
        threshold <= threshold_min;
        refr_cnt <= 4'd0;
        spike_out <= 1'b0;
        depress_a <= 3'd0;
        depress_b <= 3'd0;
        
        // Reset enhanced state
        calcium_trace <= 8'd0;
        spike_history <= 5'd0;
        burst_counter <= 4'd0;
        adaptation_level <= 7'd0;
        noise_lfsr <= 8'hA3;
        pattern_memory <= 6'd0;
        activity_tracker <= 8'd0;
        
    end else if (enable && params_ready) begin
        
        // Update noise LFSR every cycle
        noise_lfsr <= {noise_lfsr[6:0], noise_bit};
        
        // Update pattern memory with recent inputs
        pattern_memory <= {pattern_memory[3:0], chan_a[1:0]};
        
        // Calcium dynamics (simulates intracellular calcium)
        if (spike_out) begin
            calcium_update = calcium_trace + 9'd20; // Spike-triggered calcium influx
        end else begin
            calcium_update = (calcium_trace > 9'd2) ? (calcium_trace - 9'd2) : 9'd0; // Decay
        end
        
        if (calcium_update > 255)
            calcium_trace <= 8'd255;
        else
            calcium_trace <= calcium_update[7:0];
        
        // Activity tracking for homeostasis
        activity_update = (activity_tracker >> 1) + (spike_out ? 8'd16 : 8'd0);
        activity_tracker <= activity_update;
        
        // Refractory period handling with enhanced dynamics
        if (refr_cnt != 0) begin
            refr_cnt <= refr_cnt - 1;
            spike_out <= 1'b0;
            
            // Enhanced leak during refractory with calcium influence
            if (v_mem > adaptive_leak + (calcium_trace >> 6))
                v_mem <= v_mem - adaptive_leak - (calcium_trace >> 6);
            else
                v_mem <= 8'd0;
                
            // Slow adaptation during refractory
            if (adaptation_level < 7'd100)
                adaptation_level <= adaptation_level + 1;
                
        end else begin
            // COMPLEX INTEGRATION with multiple factors
            
            // Base integration with noise
            new_v = v_mem + weighted_sum - adaptive_leak + neural_noise;
            
            // Calcium-dependent modulation
            if (calcium_trace > 8'd50)
                new_v = new_v + (calcium_trace >> 5); // Calcium facilitation
            
            // Adaptation-dependent suppression
            if (adaptation_level > 7'd50)
                new_v = new_v - (adaptation_level >> 4);
            
            // Homeostatic scaling
            if (activity_tracker < homeostatic_target)
                new_v = new_v + 2; // Boost if under-active
            else if (activity_tracker > homeostatic_target + 8'd20)
                new_v = new_v - 1; // Suppress if over-active
            
            // Bounds checking with enhanced precision
            if (new_v[9] || new_v < 0) // Underflow
                new_v = 10'd0;
            if (new_v > 255) // Overflow
                new_v = 255;
            
            // COMPLEX SPIKE DETECTION with burst analysis
            if (new_v >= threshold) begin
                spike_out <= 1'b1;
                v_mem <= 8'd0;
                refr_cnt <= REFRAC_PERIOD;
                
                // Update spike history
                spike_history <= {spike_history[3:0], 1'b1};
                
                // Burst detection and complex threshold adaptation
                if (spike_history[2:0] == 3'b111) begin // 3 spikes in last 4 cycles
                    burst_counter <= burst_counter + 1;
                    threshold_update = threshold + THR_UP + 4; // Extra adaptation for bursts
                end else begin
                    threshold_update = threshold + THR_UP;
                end
                
                // Threshold bounds with burst handling
                if (threshold_update <= threshold_max)
                    threshold <= threshold_update;
                else
                    threshold <= threshold_max;
                
                // Enhanced depression with calcium dependence
                depress_a <= (calcium_trace > 8'd80) ? 3'd5 : 3'd3;
                depress_b <= (calcium_trace > 8'd80) ? 3'd5 : 3'd3;
                
                // Reset adaptation on successful spike
                if (adaptation_level > 7'd10)
                    adaptation_level <= adaptation_level - 7'd10;
                    
            end else begin
                spike_out <= 1'b0;
                v_mem <= new_v[7:0];
                
                // Update spike history
                spike_history <= {spike_history[3:0], 1'b0};
                
                // Complex threshold decrease with multiple factors
                threshold_update = threshold;
                
                // Base threshold decay
                if (threshold > threshold_min + THR_DN)
                    threshold_update = threshold_update - THR_DN;
                
                // Calcium-dependent additional decay
                if (calcium_trace < 8'd30 && threshold_update > threshold_min)
                    threshold_update = threshold_update - 1;
                
                // Activity-dependent threshold adjustment
                if (activity_tracker < homeostatic_target && threshold_update > threshold_min + 2)
                    threshold_update = threshold_update - 2;
                
                threshold <= (threshold_update < threshold_min) ? threshold_min : threshold_update;
                
                // Enhanced depression recovery with calcium influence
                if (depress_a > 0) begin
                    if (calcium_trace < 8'd40)
                        depress_a <= depress_a - 1; // Faster recovery when calcium low
                end
                if (depress_b > 0) begin
                    if (calcium_trace < 8'd40)
                        depress_b <= depress_b - 1;
                end
                
                // Burst counter decay
                if (burst_counter > 0 && spike_history == 5'd0)
                    burst_counter <= burst_counter - 1;
            end
        end
    end else begin
        spike_out <= 1'b0;
    end
end

endmodule
