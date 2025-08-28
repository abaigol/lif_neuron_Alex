module alif_dual_unileak_data_loader (
    // System signals
    input wire clk,
    input wire reset,
    input wire enable,
    
    // Serial data input
    input wire serial_data_in,
    input wire load_enable,
    
    // Outputs to LIF neuron
    output reg [2:0] weight_a,      
    output reg [2:0] weight_b,      
    output reg [7:0] leak_rate,     
    output reg [7:0] threshold_min, 
    output reg [3:0] leak_cycles,   
    output reg params_ready         
);

// State machine parameters
parameter IDLE = 3'b000;
parameter LOAD_WA = 3'b001;
parameter LOAD_WB = 3'b010;
parameter LOAD_LEAK_RATE = 3'b011;
parameter LOAD_THR_MIN = 3'b100;
parameter LOAD_LEAK_CYCLES = 3'b101;
parameter READY = 3'b110;

// Internal registers
reg [7:0] shift_reg;
reg [2:0] bit_count;
reg [2:0] current_state;

// Default parameter values
parameter DEFAULT_WA = 3'd2;           
parameter DEFAULT_WB = 3'd2;           
parameter DEFAULT_LEAK_RATE = 8'd2;    
parameter DEFAULT_THR_MIN = 8'd30;     
parameter DEFAULT_LEAK_CYCLES = 4'd1;  

// State machine and serial loading logic
always @(posedge clk) begin
    if (reset) begin
        current_state <= IDLE;
        shift_reg <= 8'd0;
        bit_count <= 3'd0;
        weight_a <= DEFAULT_WA;
        weight_b <= DEFAULT_WB;
        leak_rate <= DEFAULT_LEAK_RATE;
        threshold_min <= DEFAULT_THR_MIN;
        leak_cycles <= DEFAULT_LEAK_CYCLES;
        params_ready <= 1'b1;
    end else if (enable) begin
        case (current_state)
            IDLE: begin
                if (load_enable) begin
                    current_state <= LOAD_WA;
                    bit_count <= 3'd0;
                    shift_reg <= 8'd0;
                    params_ready <= 1'b0;
                end
            end
            
            LOAD_WA: begin
                if (load_enable) begin
                    shift_reg <= {shift_reg[6:0], serial_data_in};
                    bit_count <= bit_count + 1;
                    if (bit_count == 3'd7) begin
                        weight_a <= {shift_reg[1:0], serial_data_in}; // Capture final 3 bits correctly
                        current_state <= LOAD_WB;
                        bit_count <= 3'd0;
                        shift_reg <= 8'd0;
                    end
                end else begin
                    current_state <= IDLE;
                    params_ready <= 1'b1;
                end
            end
            
            LOAD_WB: begin
                if (load_enable) begin
                    shift_reg <= {shift_reg[6:0], serial_data_in};
                    bit_count <= bit_count + 1;
                    if (bit_count == 3'd7) begin
                        weight_b <= {shift_reg[1:0], serial_data_in}; // Capture final 3 bits correctly
                        current_state <= LOAD_LEAK_RATE;
                        bit_count <= 3'd0;
                        shift_reg <= 8'd0;
                    end
                end else begin
                    current_state <= IDLE;
                    params_ready <= 1'b1;
                end
            end
            
            LOAD_LEAK_RATE: begin
                if (load_enable) begin
                    shift_reg <= {shift_reg[6:0], serial_data_in};
                    bit_count <= bit_count + 1;
                    if (bit_count == 3'd7) begin
                        leak_rate <= {shift_reg[6:0], serial_data_in}; // Capture all 8 bits correctly
                        current_state <= LOAD_THR_MIN;
                        bit_count <= 3'd0;
                        shift_reg <= 8'd0;
                    end
                end else begin
                    current_state <= IDLE;
                    params_ready <= 1'b1;
                end
            end
            
            LOAD_THR_MIN: begin
                if (load_enable) begin
                    shift_reg <= {shift_reg[6:0], serial_data_in};
                    bit_count <= bit_count + 1;
                    if (bit_count == 3'd7) begin
                        threshold_min <= {shift_reg[6:0], serial_data_in}; // Capture all 8 bits correctly
                        current_state <= LOAD_LEAK_CYCLES;
                        bit_count <= 3'd0;
                        shift_reg <= 8'd0;
                    end
                end else begin
                    current_state <= IDLE;
                    params_ready <= 1'b1;
                end
            end
            
            LOAD_LEAK_CYCLES: begin
                if (load_enable) begin
                    shift_reg <= {shift_reg[6:0], serial_data_in};
                    bit_count <= bit_count + 1;
                    if (bit_count == 3'd7) begin
                        leak_cycles <= {shift_reg[2:0], serial_data_in}; // Capture final 4 bits correctly
                        current_state <= READY;
                        params_ready <= 1'b1;
                    end
                end else begin
                    current_state <= IDLE;
                    params_ready <= 1'b1;
                end
            end
            
            READY: begin
                if (!load_enable) begin
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
