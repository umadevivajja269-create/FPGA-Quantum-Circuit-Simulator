module basys3_quantum_top (
    input  wire        CLK100MHZ,
    input  wire [15:0] SW,

    input  wire BTNC,
    input  wire BTNU,
    input  wire BTNR,
    input  wire BTNL,
    input  wire BTND,

    output wire [15:0] LED,

    input  wire RsRx,
    output wire RsTx
);

    // =================================================
    // 1. CLOCK, RESET AND METHOD SELECTION
    // =================================================

    wire clk = CLK100MHZ;
    wire reset = BTNL;

    reg mode_b;
    reg mode_sync1, mode_sync2, mode_previous;

    always @(posedge clk) begin
        if (reset) begin
            mode_sync1 <= 0;
            mode_sync2 <= 0;
            mode_previous <= 0;
            mode_b <= 0;
        end
        else begin
            mode_sync1 <= BTND;
            mode_sync2 <= mode_sync1;
            mode_previous <= mode_sync2;

            if (mode_sync2 && !mode_previous)
                mode_b <= ~mode_b;
        end
    end

    // =================================================
    // 2. COMMON CORE STATUS SIGNALS
    // =================================================

    wire instruction_valid;
    wire input_error;

    wire initialize_busy;
    wire initialize_done;

    wire circuit_busy;
    wire circuit_done;
    wire circuit_error;

    wire signed [15:0] result_real;
    wire signed [15:0] result_imag;

    // =================================================
    // 3. METHOD A BUTTON SYNCHRONIZATION
    // =================================================

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

    // =================================================
    // 4. METHOD A CONFIGURATION
    // =================================================

    reg [2:0] configured_qubits;
    reg [3:0] configured_initial_state;
    reg [4:0] configured_gate_count;

    reg initialized;
    reg initialize_pending;

    wire manual_initialize_start = initialize_pending;

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

    // =================================================
    // 5. METHOD A GATE INPUT
    // =================================================

    reg [4:0] loaded_count;

    wire [3:0] manual_instruction_address =
        loaded_count[3:0];

    wire [2:0] manual_instruction_gate = SW[2:0];
    wire [1:0] manual_instruction_target = SW[4:3];
    wire [1:0] manual_instruction_control = SW[6:5];

    wire manual_instruction_write_enable =
        !mode_b &&
        load_button &&
        initialized &&
        !initialize_busy &&
        !circuit_busy &&
        (loaded_count < configured_gate_count);

    wire manual_circuit_start =
        !mode_b &&
        start_button &&
        initialized &&
        !initialize_busy &&
        !circuit_busy &&
        (loaded_count == configured_gate_count);

    // =================================================
    // 6. METHOD B UART SIGNALS
    // =================================================

    wire [2:0] uart_num_qubits;
    wire [3:0] uart_initial_state;
    wire [4:0] uart_gate_count;

    wire uart_initialize_start;
    wire uart_instruction_write_enable;

    wire [3:0] uart_instruction_address;
    wire [2:0] uart_instruction_gate;
    wire [1:0] uart_instruction_target;
    wire [1:0] uart_instruction_control;

    wire uart_circuit_start;
    wire [3:0] uart_result_address;

    // =================================================
    // 7. COMMON CORE INPUT MULTIPLEXER
    // =================================================

    wire [2:0] core_num_qubits =
        mode_b ? uart_num_qubits : configured_qubits;

    wire [3:0] core_initial_state =
        mode_b ? uart_initial_state : configured_initial_state;

    wire [4:0] core_gate_count =
        mode_b ? uart_gate_count : configured_gate_count;

    wire core_initialize_start =
        mode_b ? uart_initialize_start : manual_initialize_start;

    wire core_instruction_write_enable =
        mode_b ? uart_instruction_write_enable :
                 manual_instruction_write_enable;

    wire [3:0] core_instruction_address =
        mode_b ? uart_instruction_address :
                 manual_instruction_address;

    wire [2:0] core_instruction_gate =
        mode_b ? uart_instruction_gate :
                 manual_instruction_gate;

    wire [1:0] core_instruction_target =
        mode_b ? uart_instruction_target :
                 manual_instruction_target;

    wire [1:0] core_instruction_control =
        mode_b ? uart_instruction_control :
                 manual_instruction_control;

    wire core_circuit_start =
        mode_b ? uart_circuit_start : manual_circuit_start;

    wire [3:0] core_result_address =
        mode_b ? uart_result_address : {1'b0, SW[14:12]};

    // =================================================
    // 8. QUANTUM CALCULATOR CORE
    // =================================================

    quantum_calculator_top #(
        .MAX_QUBITS (4),
        .MAX_GATES  (16),
        .DATA_WIDTH (16),
        .ADDR_WIDTH (4)
    ) U_QUANTUM_CORE (

        .clk(clk),
        .reset(reset),

        .num_qubits(core_num_qubits),
        .initial_state(core_initial_state),
        .gate_count(core_gate_count),

        .initialize_start(core_initialize_start),
        .initialize_busy(initialize_busy),
        .initialize_done(initialize_done),

        .instruction_write_enable(core_instruction_write_enable),
        .instruction_write_address(core_instruction_address),
        .instruction_write_gate(core_instruction_gate),
        .instruction_write_target(core_instruction_target),
        .instruction_write_control(core_instruction_control),

        .instruction_valid(instruction_valid),
        .input_error(input_error),

        .circuit_start(core_circuit_start),
        .circuit_busy(circuit_busy),
        .circuit_done(circuit_done),
        .circuit_error(circuit_error),

        .result_read_address(core_result_address),
        .result_real(result_real),
        .result_imag(result_imag)
    );

    // =================================================
    // 9. METHOD B UART BRIDGE
    // =================================================

    quantum_uart_bridge #(
        .CLKS_PER_BIT(868),
        .MAX_GATES(16)
    ) U_UART_BRIDGE (

        .clk(clk),
        .reset(reset),

        .RsRx(RsRx),
        .RsTx(RsTx),

        .num_qubits(uart_num_qubits),
        .initial_state(uart_initial_state),
        .gate_count(uart_gate_count),

        .initialize_start(uart_initialize_start),
        .initialize_done(initialize_done),
        .initialize_busy(initialize_busy),

        .instruction_write_enable(uart_instruction_write_enable),
        .instruction_write_address(uart_instruction_address),
        .instruction_write_gate(uart_instruction_gate),
        .instruction_write_target(uart_instruction_target),
        .instruction_write_control(uart_instruction_control),

        .instruction_valid(instruction_valid),
        .input_error(input_error),

        .circuit_start(uart_circuit_start),
        .circuit_done(circuit_done),
        .circuit_busy(circuit_busy),
        .circuit_error(circuit_error),

        .result_read_address(uart_result_address),
        .result_real(result_real),
        .result_imag(result_imag)
    );

    // =================================================
    // 10. METHOD A INITIALIZATION AND GATE COUNTER
    // =================================================

    always @(posedge clk) begin
        if (reset) begin
            configured_qubits <= 3'd1;
            configured_initial_state <= 4'd0;
            configured_gate_count <= 5'd1;

            initialized <= 1'b0;
            initialize_pending <= 1'b0;
            loaded_count <= 5'd0;
        end
        else if (!mode_b) begin

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
                loaded_count <= 0;
                initialize_pending <= 1'b1;
            end

            if (initialize_done) begin
                initialized <= 1'b1;
                loaded_count <= 0;
            end

            if (manual_instruction_write_enable &&
                instruction_valid) begin
                loaded_count <= loaded_count + 1'b1;
            end
        end
    end

    // =================================================
    // 11. METHOD A EXECUTION CYCLE COUNTER
    // =================================================

    reg [31:0] execution_counter;
    reg [31:0] execution_cycles;

    reg execution_active;
    reg execution_valid;

    always @(posedge clk) begin
        if (reset) begin
            execution_counter <= 0;
            execution_cycles <= 0;
            execution_active <= 0;
            execution_valid <= 0;
        end
        else if (!mode_b) begin

            if (manual_circuit_start) begin
                execution_counter <= 0;
                execution_active <= 1;
                execution_valid <= 0;
            end

            else if (execution_active && circuit_done) begin
                execution_cycles <= execution_counter;
                execution_active <= 0;
                execution_valid <= 1;
            end

            else if (execution_active) begin
                execution_counter <= execution_counter + 1'b1;
            end
        end
    end

    // =================================================
    // 12. COMMON OUTPUT VALUE
    // =================================================

    wire signed [15:0] selected_amplitude =
        SW[11] ? result_imag : result_real;

    wire [15:0] display_value =
        SW[15] ?
            (SW[14] ? execution_cycles[31:16]
                    : execution_cycles[15:0])
            : selected_amplitude;

    // Method A LEDs show selected output.
    // Method B LED indicator remains 0002.
    assign LED = mode_b ? 16'h0002 : display_value;

endmodule
