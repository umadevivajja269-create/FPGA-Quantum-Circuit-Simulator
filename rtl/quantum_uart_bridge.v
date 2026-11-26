
module quantum_uart_bridge #(
    parameter CLKS_PER_BIT = 868,
    parameter MAX_GATES = 16
)(
    input wire clk,
    input wire reset,

    // USB UART
    input wire RsRx,
    output wire RsTx,

    // Quantum core configuration
    output reg [2:0] num_qubits,
    output reg [3:0] initial_state,
    output reg [4:0] gate_count,

    // Quantum core initialization
    output wire initialize_start,
    input wire initialize_done,
    input wire initialize_busy,

    // Instruction loading
    output wire instruction_write_enable,
    output wire [3:0] instruction_write_address,
    output wire [2:0] instruction_write_gate,
    output wire [1:0] instruction_write_target,
    output wire [1:0] instruction_write_control,
    input wire instruction_valid,
    input wire input_error,

    // Circuit execution
    output wire circuit_start,
    input wire circuit_done,
    input wire circuit_busy,
    input wire circuit_error,

    // Result reading
    output wire [3:0] result_read_address,
    input wire signed [15:0] result_real,
    input wire signed [15:0] result_imag
);

    // ------------------------------------------------
    // 1. UART RECEIVER AND TRANSMITTER
    // ------------------------------------------------

    wire [7:0] rx_data;
    wire rx_valid;

    reg tx_start;
    reg [7:0] tx_data;
    wire tx_busy;

    uart_rx #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) U_RX (
        .clk(clk),
        .reset(reset),
        .rx_serial(RsRx),
        .rx_data(rx_data),
        .rx_valid(rx_valid)
    );

    uart_tx #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) U_TX (
        .clk(clk),
        .reset(reset),
        .tx_start(tx_start),
        .tx_data(tx_data),
        .tx_serial(RsTx),
        .tx_busy(tx_busy)
    );

    // ------------------------------------------------
    // 2. GATE STORAGE
    // ------------------------------------------------

    reg [2:0] gate_mem [0:MAX_GATES-1];
    reg [1:0] target_mem [0:MAX_GATES-1];
    reg [1:0] control_mem [0:MAX_GATES-1];

    reg [4:0] gate_index;
    reg [2:0] received_gate;
    reg [1:0] received_target;

    // ------------------------------------------------
    // 3. FSM STATES
    // ------------------------------------------------

    localparam IDLE           = 5'd0;
    localparam RX_QUBITS      = 5'd1;
    localparam RX_INITIAL     = 5'd2;
    localparam RX_GATE_COUNT  = 5'd3;
    localparam RX_GATE_TYPE   = 5'd4;
    localparam RX_TARGET      = 5'd5;
    localparam RX_CONTROL     = 5'd6;

    localparam INIT_PULSE     = 5'd7;
    localparam WAIT_INIT      = 5'd8;
    localparam WRITE_GATE     = 5'd9;
    localparam START_CIRCUIT  = 5'd10;
    localparam WAIT_CIRCUIT   = 5'd11;

    localparam SEND_PREFIX    = 5'd12;
    localparam TX_LAUNCH      = 5'd13;
    localparam TX_WAIT_BUSY   = 5'd14;
    localparam TX_WAIT_DONE   = 5'd15;

    localparam CAPTURE_RESULT = 5'd16;
    localparam SEND_AMPLITUDE = 5'd17;
    localparam FINISHED       = 5'd18;

    reg [4:0] state;

    // ------------------------------------------------
    // 4. RESPONSE AND RESULT REGISTERS
    // ------------------------------------------------

    reg [3:0] status_code;
    reg [7:0] response_state_count;

    reg [4:0] scan_index;

    reg [31:0] cycle_counter;
    reg [31:0] execution_cycles;

    reg signed [15:0] amplitude_real;
    reg signed [15:0] amplitude_imag;

    reg [2:0] prefix_index;
    reg [1:0] amplitude_byte_index;

    reg sending_prefix;

    // ------------------------------------------------
    // 5. CORE CONTROL OUTPUTS
    // ------------------------------------------------

    assign initialize_start =
        (state == INIT_PULSE);

    assign instruction_write_enable =
        (state == WRITE_GATE);

    assign instruction_write_address =
        gate_index[3:0];

    assign instruction_write_gate =
        gate_mem[gate_index];

    assign instruction_write_target =
        target_mem[gate_index];

    assign instruction_write_control =
        control_mem[gate_index];

    assign circuit_start =
        (state == START_CIRCUIT);

    assign result_read_address =
        scan_index[3:0];

    // ------------------------------------------------
    // 6. UART TRANSMIT DATA SELECTION
    // ------------------------------------------------

    always @(*) begin

        tx_start = 1'b0;
        tx_data  = 8'h00;

        if (state == TX_LAUNCH) begin

            tx_start = 1'b1;

            if (sending_prefix) begin

                case (prefix_index)

                    0: tx_data = 8'h5A;
                    1: tx_data = {4'b0000, status_code};
                    2: tx_data = response_state_count;
                    3: tx_data = execution_cycles[7:0];
                    4: tx_data = execution_cycles[15:8];
                    5: tx_data = execution_cycles[23:16];
                    6: tx_data = execution_cycles[31:24];

                    default: tx_data = 8'h00;

                endcase

            end
            else begin

                case (amplitude_byte_index)

                    0: tx_data = amplitude_real[7:0];
                    1: tx_data = amplitude_real[15:8];
                    2: tx_data = amplitude_imag[7:0];
                    3: tx_data = amplitude_imag[15:8];

                    default: tx_data = 8'h00;

                endcase

            end

        end
    end

    // ------------------------------------------------
    // 7. MAIN CONTROL FSM
    // ------------------------------------------------

    always @(posedge clk) begin

        if (reset) begin

            state <= IDLE;

            num_qubits <= 0;
            initial_state <= 0;
            gate_count <= 0;

            gate_index <= 0;
            received_gate <= 0;
            received_target <= 0;

            status_code <= 0;
            response_state_count <= 0;

            scan_index <= 0;

            cycle_counter <= 0;
            execution_cycles <= 0;

            amplitude_real <= 0;
            amplitude_imag <= 0;

            prefix_index <= 0;
            amplitude_byte_index <= 0;

            sending_prefix <= 1'b1;

        end
        else begin

            case (state)

                // ------------------------------------
                // WAIT FOR HEADER 0xA5
                // ------------------------------------

                IDLE: begin

                    if (rx_valid && rx_data == 8'hA5) begin

                        status_code <= 0;
                        response_state_count <= 0;

                        execution_cycles <= 0;
                        cycle_counter <= 0;

                        gate_index <= 0;
                        prefix_index <= 0;

                        state <= RX_QUBITS;

                    end

                end

                // ------------------------------------
                // RECEIVE QUBIT COUNT
                // ------------------------------------

                RX_QUBITS: begin

                    if (rx_valid) begin

                        if (rx_data >= 1 && rx_data <= 4) begin

                            num_qubits <= rx_data[2:0];
                            state <= RX_INITIAL;

                        end
                        else begin

                            status_code <= 1;
                            response_state_count <= 0;
                            state <= SEND_PREFIX;

                        end

                    end

                end

                // ------------------------------------
                // RECEIVE INITIAL BASIS STATE
                // ------------------------------------

                RX_INITIAL: begin

                    if (rx_valid) begin

                        if (rx_data < (8'd1 << num_qubits)) begin

                            initial_state <= rx_data[3:0];
                            state <= RX_GATE_COUNT;

                        end
                        else begin

                            status_code <= 1;
                            response_state_count <= 0;
                            state <= SEND_PREFIX;

                        end

                    end

                end

                // ------------------------------------
                // RECEIVE GATE COUNT
                // ------------------------------------

                RX_GATE_COUNT: begin

                    if (rx_valid) begin

                        if (rx_data >= 1 &&
                            rx_data <= MAX_GATES) begin

                            gate_count <= rx_data[4:0];
                            gate_index <= 0;

                            state <= RX_GATE_TYPE;

                        end
                        else begin

                            status_code <= 1;
                            response_state_count <= 0;
                            state <= SEND_PREFIX;

                        end

                    end

                end

                // ------------------------------------
                // RECEIVE GATE TYPE
                // ------------------------------------

                RX_GATE_TYPE: begin

                    if (rx_valid) begin

                        if (rx_data <= 4) begin

                            received_gate <= rx_data[2:0];
                            state <= RX_TARGET;

                        end
                        else begin

                            status_code <= 2;
                            response_state_count <= 0;
                            state <= SEND_PREFIX;

                        end

                    end

                end

                // ------------------------------------
                // RECEIVE TARGET QUBIT
                // ------------------------------------

                RX_TARGET: begin

                    if (rx_valid) begin

                        if (rx_data < num_qubits) begin

                            received_target <= rx_data[1:0];
                            state <= RX_CONTROL;

                        end
                        else begin

                            status_code <= 2;
                            response_state_count <= 0;
                            state <= SEND_PREFIX;

                        end

                    end

                end

                // ------------------------------------
                // RECEIVE CONTROL QUBIT
                // ------------------------------------

                RX_CONTROL: begin

                    if (rx_valid) begin

                        if (received_gate == 4 &&
                            ((rx_data >= num_qubits) ||
                             (rx_data[1:0] == received_target))) begin

                            status_code <= 2;
                            response_state_count <= 0;
                            state <= SEND_PREFIX;

                        end
                        else begin

                            gate_mem[gate_index] <= received_gate;
                            target_mem[gate_index] <= received_target;
                            control_mem[gate_index] <= rx_data[1:0];

                            if (gate_index == gate_count - 1'b1) begin

                                response_state_count <=
                                    (8'd1 << num_qubits);

                                state <= INIT_PULSE;

                            end
                            else begin

                                gate_index <= gate_index + 1'b1;
                                state <= RX_GATE_TYPE;

                            end

                        end

                    end

                end

                // ------------------------------------
                // INITIALIZE QUANTUM CORE
                // ------------------------------------

                INIT_PULSE: begin

                    state <= WAIT_INIT;

                end

                WAIT_INIT: begin

                    if (initialize_done) begin

                        gate_index <= 0;
                        state <= WRITE_GATE;

                    end

                end

                // ------------------------------------
                // WRITE GATE INSTRUCTIONS
                // ------------------------------------

                WRITE_GATE: begin

                    if (input_error || !instruction_valid) begin

                        status_code <= 2;
                        response_state_count <= 0;

                        state <= SEND_PREFIX;

                    end
                    else begin

                        if (gate_index == gate_count - 1'b1) begin

                            gate_index <= 0;
                            state <= START_CIRCUIT;

                        end
                        else begin

                            gate_index <= gate_index + 1'b1;

                        end

                    end

                end

                // ------------------------------------
                // START QUANTUM CIRCUIT
                // ------------------------------------

                START_CIRCUIT: begin

                    cycle_counter <= 0;
                    state <= WAIT_CIRCUIT;

                end

                // ------------------------------------
                // WAIT FOR CIRCUIT COMPLETION
                // ------------------------------------

                WAIT_CIRCUIT: begin

                    if (circuit_done) begin

                        execution_cycles <= cycle_counter;

                        scan_index <= 0;
                        prefix_index <= 0;

                        if (circuit_error) begin

                            status_code <= 3;
                            response_state_count <= 0;

                        end
                        else begin

                            status_code <= 0;

                        end

                        state <= SEND_PREFIX;

                    end
                    else begin

                        cycle_counter <= cycle_counter + 1'b1;

                    end

                end

                // ------------------------------------
                // SEND RESPONSE HEADER
                // ------------------------------------

                SEND_PREFIX: begin

                    sending_prefix <= 1'b1;
                    prefix_index <= 0;

                    state <= TX_LAUNCH;

                end

                // ------------------------------------
                // START UART BYTE TRANSMISSION
                // ------------------------------------

                TX_LAUNCH: begin

                    state <= TX_WAIT_BUSY;

                end

                TX_WAIT_BUSY: begin

                    if (tx_busy)
                        state <= TX_WAIT_DONE;

                end

                // ------------------------------------
                // WAIT FOR UART BYTE COMPLETION
                // ------------------------------------

                TX_WAIT_DONE: begin

                    if (!tx_busy) begin

                        if (sending_prefix) begin

                            if (prefix_index < 6) begin

                                prefix_index <= prefix_index + 1'b1;
                                state <= TX_LAUNCH;

                            end
                            else begin

                                sending_prefix <= 1'b0;

                                if (status_code != 0 ||
                                    response_state_count == 0) begin

                                    state <= FINISHED;

                                end
                                else begin

                                    scan_index <= 0;
                                    state <= CAPTURE_RESULT;

                                end

                            end

                        end
                        else begin

                            if (amplitude_byte_index == 3) begin

                                if (scan_index ==
                                    response_state_count - 1'b1) begin

                                    state <= FINISHED;

                                end
                                else begin

                                    scan_index <= scan_index + 1'b1;
                                    state <= CAPTURE_RESULT;

                                end

                            end
                            else begin

                                amplitude_byte_index <=
                                    amplitude_byte_index + 1'b1;

                                state <= TX_LAUNCH;

                            end

                        end

                    end

                end

                // ------------------------------------
                // CAPTURE FINAL STATE AMPLITUDES
                // ------------------------------------

                CAPTURE_RESULT: begin

                    amplitude_real <= result_real;
                    amplitude_imag <= result_imag;

                    amplitude_byte_index <= 0;

                    state <= SEND_AMPLITUDE;

                end

                // ------------------------------------
                // SEND AMPLITUDE BYTES
                // ------------------------------------

                SEND_AMPLITUDE: begin

                    state <= TX_LAUNCH;

                end

                // ------------------------------------
                // FINISH TRANSACTION
                // ------------------------------------

                FINISHED: begin

                    state <= IDLE;

                end

                default: begin

                    state <= IDLE;

                end

            endcase

        end

    end

endmodule
