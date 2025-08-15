module lif_data_loader (
    // System signals
    input wire clk,
    input wire reset,
    input wire enable,
    
    // Serial data input
    input wire serial_data_in,
    input wire load_enable,
    
    // EXPANDED OUTPUTS - More parameters
    output reg [2:0] weight_a,      
    output reg [2:0] weight_b,      
    output reg [1:0] leak_config,   
    output reg [7:0] threshold_min, 
    output reg [7:0] threshold_max, 
    output reg params_ready         
);

// EXPANDED STATE MACHINE - More parameters to load
parameter IDLE = 4'b0000;
parameter LOAD_WA = 4'b0001;
parameter LOAD_WB = 4'b0010;
parameter LOAD_LEAK = 4'b0011;
parameter LOAD_THR_MIN = 4'b0100;
parameter LOAD_THR_MAX = 4'b0101;
parameter LOAD_EXTRA1 = 4'b0110;  // Additional parameter slots
parameter LOAD_EXTRA2 = 4'b0111;  // for future expansion
parameter READY = 4'b1000;

// EXPANDED INTERNAL REGISTERS
reg [7:0] shift_reg;
reg [2:0] bit_count;
reg [3:0] current_state;  // Expanded to 4 bits for more states
reg [7:0] checksum;       // Parameter validation
reg [4:0] load_counter;   // Load cycle counter

// Edge detection
reg load_enable_prev;
wire load_enable_rising = load_enable & ~load_enable_prev;

// ENHANCED DEFAULT PARAMETERS with validation
parameter DEFAULT_WA = 3'd3;        // Slightly higher default
parameter DEFAULT_WB = 3'd3;        
parameter DEFAULT_LEAK = 2'd1;      
parameter DEFAULT_THR_MIN = 8'd25;  // Tighter range
parameter DEFAULT_THR_MAX = 8'd85;  
parameter CHECKSUM_SEED = 8'hA5;    // Validation seed

always @(posedge clk) begin
    if (reset) begin
        load_enable_prev <= 1'b0;
    end else begin
        load_enable_prev <= load_enable;
    end
end

// ENHANCED STATE MACHINE with validation and more complexity
always @(posedge clk) begin
    if (reset) begin
        current_state <= IDLE;
        shift_reg <= 8'd0;
        bit_count <= 3'd0;
        checksum <= CHECKSUM_SEED;
        load_counter <= 5'd0;
        weight_a <= DEFAULT_WA;
        weight_b <= DEFAULT_WB;
        leak_config <= DEFAULT_LEAK;
        threshold_min <= DEFAULT_THR_MIN;
        threshold_max <= DEFAULT_THR_MAX;
        params_ready <= 1'b1;
        
    end else if (enable) begin
        case (current_state)
            IDLE: begin
                if (load_enable_rising) begin
                    current_state <= LOAD_WA;
                    bit_count <= 3'd0;
                    shift_reg <= 8'd0;
                    checksum <= CHECKSUM_SEED;
                    load_counter <= load_counter + 1;
                    params_ready <= 1'b0;
                end
            end
            
            LOAD_WA: begin
                if (load_enable) begin
                    shift_reg <= {shift_reg[6:0], serial_data_in};
                    bit_count <= bit_count + 1;
                    checksum <= checksum ^ {7'd0, serial_data_in}; // Running checksum
                    
                    if (bit_count == 3'd7) begin
                        // Enhanced validation
                        if (shift_reg[2:0] != 3'd0) // Ensure non-zero weight
                            weight_a <= shift_reg[2:0];
                        else
                            weight_a <= 3'd1; // Minimum weight
                        current_state <= LOAD_WB;
                        bit_count <= 3'd0;
                        shift_reg <= 8'd0;
                    end
                end
            end
            
            LOAD_WB: begin
                if (load_enable) begin
                    shift_reg <= {shift_reg[6:0], serial_data_in};
                    bit_count <= bit_count + 1;
                    checksum <= checksum ^ {7'd0, serial_data_in};
                    
                    if (bit_count == 3'd7) begin
                        if (shift_reg[2:0] != 3'd0)
                            weight_b <= shift_reg[2:0];
                        else
                            weight_b <= 3'd1;
                        current_state <= LOAD_LEAK;
                        bit_count <= 3'd0;
                        shift_reg <= 8'd0;
                    end
                end
            end
            
            LOAD_LEAK: begin
                if (load_enable) begin
                    shift_reg <= {shift_reg[6:0], serial_data_in};
                    bit_count <= bit_count + 1;
                    checksum <= checksum ^ {7'd0, serial_data_in};
                    
                    if (bit_count == 3'd7) begin
                        leak_config <= shift_reg[1:0];
                        current_state <= LOAD_THR_MIN;
                        bit_count <= 3'd0;
                        shift_reg <= 8'd0;
                    end
                end
            end
            
            LOAD_THR_MIN: begin
                if (load_enable) begin
                    shift_reg <= {shift_reg[6:0], serial_data_in};
                    bit_count <= bit_count + 1;
                    checksum <= checksum ^ {7'd0, serial_data_in};
                    
                    if (bit_count == 3'd7) begin
                        // Enhanced validation - ensure reasonable range
                        if (shift_reg >= 8'd10 && shift_reg <= 8'd100)
                            threshold_min <= shift_reg;
                        else
                            threshold_min <= DEFAULT_THR_MIN;
                        current_state <= LOAD_THR_MAX;
                        bit_count <= 3'd0;
                        shift_reg <= 8'd0;
                    end
                end
            end
            
            LOAD_THR_MAX: begin
                if (load_enable) begin
                    shift_reg <= {shift_reg[6:0], serial_data_in};
                    bit_count <= bit_count + 1;
                    checksum <= checksum ^ {7'd0, serial_data_in};
                    
                    if (bit_count == 3'd7) begin
                        // Ensure max > min with margin
                        if (shift_reg > threshold_min + 8'd10 && shift_reg <= 8'd200)
                            threshold_max <= shift_reg;
                        else
                            threshold_max <= threshold_min + 8'd30;
                        current_state <= LOAD_EXTRA1;
                        bit_count <= 3'd0;
                        shift_reg <= 8'd0;
                    end
                end
            end
            
            // Additional parameter loading states for future expansion
            LOAD_EXTRA1: begin
                if (load_enable) begin
                    shift_reg <= {shift_reg[6:0], serial_data_in};
                    bit_count <= bit_count + 1;
                    checksum <= checksum ^ {7'd0, serial_data_in};
                    
                    if (bit_count == 3'd7) begin
                        // Reserved for future parameters
                        current_state <= LOAD_EXTRA2;
                        bit_count <= 3'd0;
                        shift_reg <= 8'd0;
                    end
                end
            end
            
            LOAD_EXTRA2: begin
                if (load_enable) begin
                    shift_reg <= {shift_reg[6:0], serial_data_in};
                    bit_count <= bit_count + 1;
                    checksum <= checksum ^ {7'd0, serial_data_in};
                    
                    if (bit_count == 3'd7) begin
                        // Checksum validation (simple)
                        current_state <= READY;
                        params_ready <= (checksum[3:0] != 4'd0) ? 1'b1 : 1'b0; // Simple validation
                    end
                end
            end
            
            READY: begin
                if (load_enable_rising) begin
                    current_state <= LOAD_WA;
                    bit_count <= 3'd0;
                    shift_reg <= 8'd0;
                    checksum <= CHECKSUM_SEED;
                    params_ready <= 1'b0;
                end else if (!load_enable) begin
                    current_state <= IDLE;
                end
            end
            
            default: begin
                current_state <= IDLE;
            end
        endcase
    end
end

endmodule
