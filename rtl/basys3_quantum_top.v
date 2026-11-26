
module basys3_quantum_top (
    input  wire        CLK100MHZ,
    input  wire [15:0] SW,

    input  wire BTNC,
    input  wire BTNU,
    input  wire BTNR,
    input  wire BTNL,

    output wire [15:0] LED,

    // Basys 3 Seven Segment Display
    output wire CA,
    output wire CB,
    output wire CC,
    output wire CD,
    output wire CE,
    output wire CF,
    output wire CG,
    output wire DP,
    output wire [3:0] AN
);

    // 1. CLOCK AND RESET
    wire clk = CLK100MHZ;
    wire reset = BTNL;

    // 2. BUTTON SYNCHRONIZATION
    reg init_sync1, init_sync2, init_previous;
    reg load_sync1, load_sync2, load_previous;
    reg start_sync1, start_sync2, start_previous;

    always @(posedge clk) begin
        if (reset) begin
            init_sync1 <= 0;
            init_sync2 <= 0;
            init_previous <= 0;
            load_sync1 <= 0;
            load_sync2 <= 0;
            load_previous <= 0;
            start_sync1 <= 0;
            start_sync2 <= 0;
            start_previous <= 0;
        end
        else begin
            init_sync1 <= BTNC;
            init_sync2 <= init_sync1;
            init_previous <= init_sync2;

            load_sync1 <= BTNU;
            load_sync2 <= load_sync1;
            load_previous <= load_sync2;

            start_sync1 <= BTNR;
            start_sync2 <= start_sync1;
            start_previous <= start_sync2;
        end
    end

    wire initialize_button = init_sync2 & ~init_previous;
    wire load_button = load_sync2 & ~load_previous;
    wire start_button = start_sync2 & ~start_previous;

    // 3. USER CONFIGURATION
    reg [2:0] configured_qubits;
    reg [3:0] configured_initial_state;
    reg [4:0] configured_gate_count;

    reg initialized;
    reg initialize_pending;

    wire initialize_start = initialize_pending;

    wire [2:0] user_num_qubits =
        {1'b0, SW[1:0]} + 3'd1;

    wire [3:0] user_initial_state = SW[5:2];
    wire [4:0] user_gate_count = SW[10:6];

    wire configuration_valid =
        (user_num_qubits >= 1) &&
        (user_num_qubits <= 4) &&
        (user_gate_count >= 1) &&
        (user_gate_count <= 16) &&
        (user_initial_state < (32'd1 << user_num_qubits));

    // 4. INSTRUCTION ENTRY
    reg [4:0] loaded_count;

    wire [3:0] instruction_write_address =
        loaded_count[3:0];

    wire [2:0] instruction_write_gate = SW[2:0];
    wire [1:0] instruction_write_target = SW[4:3];
    wire [1:0] instruction_write_control = SW[6:5];

    // 5. CORE CONTROL
    wire instruction_write_enable;
    wire instruction_valid;
    wire input_error;

    wire circuit_start;

    wire initialize_busy;
    wire initialize_done;

    wire circuit_busy;
    wire circuit_done;
    wire circuit_error;

    assign instruction_write_enable =
        load_button &&
        initialized &&
        !initialize_busy &&
        !circuit_busy &&
        (loaded_count < configured_gate_count);

    assign circuit_start =
        start_button &&
        initialized &&
        !initialize_busy &&
        !circuit_busy &&
        (loaded_count == configured_gate_count);

    // 6. RESULT ADDRESS
    wire [3:0] result_read_address =
        {1'b0, SW[14:12]};

    // 7. QUANTUM CORE
    wire signed [15:0] result_real;
    wire signed [15:0] result_imag;

    quantum_calculator_top #(
        .MAX_QUBITS (4),
        .MAX_GATES  (16),
        .DATA_WIDTH (16),
        .ADDR_WIDTH (4)
    )
    U_QUANTUM_CORE (
        .clk(clk),
        .reset(reset),

        .num_qubits(configured_qubits),
        .initial_state(configured_initial_state),
        .gate_count(configured_gate_count),

        .initialize_start(initialize_start),
        .initialize_busy(initialize_busy),
        .initialize_done(initialize_done),

        .instruction_write_enable(instruction_write_enable),
        .instruction_write_address(instruction_write_address),
        .instruction_write_gate(instruction_write_gate),
        .instruction_write_target(instruction_write_target),
        .instruction_write_control(instruction_write_control),

        .instruction_valid(instruction_valid),
        .input_error(input_error),

        .circuit_start(circuit_start),
        .circuit_busy(circuit_busy),
        .circuit_done(circuit_done),
        .circuit_error(circuit_error),

        .result_read_address(result_read_address),
        .result_real(result_real),
        .result_imag(result_imag)
    );

    // 8. CONFIGURATION AND INSTRUCTION COUNTER
    always @(posedge clk) begin
        if (reset) begin
            configured_qubits <= 3'd1;
            configured_initial_state <= 4'd0;
            configured_gate_count <= 5'd1;

            initialized <= 1'b0;
            initialize_pending <= 1'b0;
            loaded_count <= 5'd0;
        end
        else begin
            if (initialize_pending)
                initialize_pending <= 1'b0;

            if (initialize_button &&
                configuration_valid &&
                !initialize_busy &&
                !circuit_busy) begin

                configured_qubits <= user_num_qubits;
                configured_initial_state <= user_initial_state;
                configured_gate_count <= user_gate_count;

                initialized <= 1'b0;
                loaded_count <= 5'd0;
                initialize_pending <= 1'b1;
            end

            if (initialize_done) begin
                initialized <= 1'b1;
                loaded_count <= 5'd0;
            end

            if (instruction_write_enable && instruction_valid)
                loaded_count <= loaded_count + 1'b1;
        end
    end

    // 9. EXECUTION CYCLE MEASUREMENT
    reg [31:0] execution_counter;
    reg [31:0] execution_cycles;

    reg execution_active;
    reg execution_valid;

    always @(posedge clk) begin
        if (reset) begin
            execution_counter <= 32'd0;
            execution_cycles <= 32'd0;
            execution_active <= 1'b0;
            execution_valid <= 1'b0;
        end
        else begin
            if (circuit_start) begin
                execution_counter <= 32'd0;
                execution_active <= 1'b1;
                execution_valid <= 1'b0;
            end
            else if (execution_active && circuit_done) begin
                execution_cycles <= execution_counter + 1'b1;
                execution_active <= 1'b0;
                execution_valid <= 1'b1;
            end
            else if (execution_active) begin
                execution_counter <= execution_counter + 1'b1;
            end
        end
    end

    // 10. COMMON DISPLAY DATA
    wire signed [15:0] selected_amplitude;

    assign selected_amplitude =
        SW[11] ? result_imag : result_real;

    wire [15:0] display_value;

    assign display_value =
        SW[15] ?
            (SW[14] ? execution_cycles[31:16]
                    : execution_cycles[15:0])
            : selected_amplitude;

    // 11. LED OUTPUT
    assign LED = display_value;

    // 12. SEVEN SEGMENT DISPLAY
    seven_segment_display U_DISPLAY (
        .clk(clk),
        .reset(reset),
        .value(display_value),
        .CA(CA),
        .CB(CB),
        .CC(CC),
        .CD(CD),
        .CE(CE),
        .CF(CF),
        .CG(CG),
        .DP(DP),
        .AN(AN)
    );

endmodule


// ====================================================
// SEVEN SEGMENT DISPLAY DRIVER
// Basys 3: Common Anode, Active LOW
// ====================================================

module seven_segment_display (
    input wire clk,
    input wire reset,
    input wire [15:0] value,

    output reg CA,
    output reg CB,
    output reg CC,
    output reg CD,
    output reg CE,
    output reg CF,
    output reg CG,
    output wire DP,
    output reg [3:0] AN
);

    reg [17:0] refresh_counter;
    reg [3:0] digit_value;
    reg [6:0] segments;

    assign DP = 1'b1;

    // Digit refresh counter
    always @(posedge clk) begin
        if (reset)
            refresh_counter <= 18'd0;
        else
            refresh_counter <= refresh_counter + 1'b1;
    end

    // Select one of four hexadecimal digits
    always @(*) begin
        case (refresh_counter[17:16])
            2'b00: begin
                AN = 4'b1110;
                digit_value = value[3:0];
            end

            2'b01: begin
                AN = 4'b1101;
                digit_value = value[7:4];
            end

            2'b10: begin
                AN = 4'b1011;
                digit_value = value[11:8];
            end

            2'b11: begin
                AN = 4'b0111;
                digit_value = value[15:12];
            end

            default: begin
                AN = 4'b1111;
                digit_value = 4'd0;
            end
        endcase
    end

    // Hexadecimal to seven-segment decoder
    always @(*) begin
        case (digit_value)
            4'h0: segments = 7'b1000000;
            4'h1: segments = 7'b1111001;
            4'h2: segments = 7'b0100100;
            4'h3: segments = 7'b0110000;
            4'h4: segments = 7'b0011001;
            4'h5: segments = 7'b0010010;
            4'h6: segments = 7'b0000010;
            4'h7: segments = 7'b1111000;
            4'h8: segments = 7'b0000000;
            4'h9: segments = 7'b0010000;
            4'hA: segments = 7'b0001000;
            4'hB: segments = 7'b0000011;
            4'hC: segments = 7'b1000110;
            4'hD: segments = 7'b0100001;
            4'hE: segments = 7'b0000110;
            4'hF: segments = 7'b0001110;
            default: segments = 7'b1111111;
        endcase
    end

    // Segment outputs: active LOW
    always @(*) begin
        CA = segments[6];
        CB = segments[5];
        CC = segments[4];
        CD = segments[3];
        CE = segments[2];
        CF = segments[1];
        CG = segments[0];
    end

endmodule
