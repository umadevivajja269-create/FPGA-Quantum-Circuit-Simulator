module quantum_calculator_top #(
    parameter MAX_QUBITS = 4,
    parameter MAX_GATES  = 16,
    parameter DATA_WIDTH = 16,
    parameter ADDR_WIDTH = 4
)(
    input wire clk,
    input wire reset,

    // User circuit configuration
    input wire [2:0] num_qubits,
    input wire [3:0] initial_state,
    input wire [4:0] gate_count,

    // Initial state generation control
    input wire initialize_start,
    output wire initialize_busy,
    output wire initialize_done,

    // Instruction loading interface
    input wire instruction_write_enable,
    input wire [3:0] instruction_write_address,
    input wire [2:0] instruction_write_gate,
    input wire [1:0] instruction_write_target,
    input wire [1:0] instruction_write_control,

    output wire instruction_valid,
    output wire input_error,

    // Circuit execution control
    input wire circuit_start,
    output wire circuit_busy,
    output wire circuit_done,
    output wire circuit_error,

    // Final state inspection interface
    input wire [3:0] result_read_address,
    output wire signed [DATA_WIDTH-1:0] result_real,
    output wire signed [DATA_WIDTH-1:0] result_imag
);

    // ------------------------------------------------
    // 1. CONFIGURATION VALIDATION
    // ------------------------------------------------

    wire [31:0] state_limit;

    assign state_limit = (32'd1 << num_qubits);

    wire initial_config_valid;
    wire instruction_address_valid;

    assign initial_config_valid =
        (num_qubits >= 1) &&
        (num_qubits <= MAX_QUBITS) &&
        (initial_state < state_limit);

    assign instruction_address_valid =
        (instruction_write_address < gate_count) &&
        (instruction_write_address < MAX_GATES);

    // ------------------------------------------------
    // 2. INTERNAL SIGNALS
    // ------------------------------------------------

    wire validation_valid;
    wire validation_error;

    wire [3:0] init_write_address;
    wire signed [DATA_WIDTH-1:0] init_real_data;
    wire signed [DATA_WIDTH-1:0] init_imag_data;
    wire init_write_enable;

    wire memory_write_enable;
    wire [3:0] memory_write_address;
    wire signed [DATA_WIDTH-1:0] memory_write_real;
    wire signed [DATA_WIDTH-1:0] memory_write_imag;

    wire [3:0] read_address_a;
    wire [3:0] read_address_b;

    wire signed [DATA_WIDTH-1:0] read_real_a;
    wire signed [DATA_WIDTH-1:0] read_imag_a;
    wire signed [DATA_WIDTH-1:0] read_real_b;
    wire signed [DATA_WIDTH-1:0] read_imag_b;

    wire gate_start;
    wire [2:0] gate_type;
    wire [1:0] target_qubit;
    wire [1:0] control_qubit;

    wire gate_busy;
    wire gate_done;
    wire gate_error;

    wire gate_memory_write_enable;
    wire [3:0] gate_memory_write_address;
    wire signed [DATA_WIDTH-1:0] gate_memory_write_real;
    wire signed [DATA_WIDTH-1:0] gate_memory_write_imag;

    wire [3:0] instruction_read_address;
    wire [2:0] instruction_read_gate;
    wire [1:0] instruction_read_target;
    wire [1:0] instruction_read_control;

    wire controller_circuit_error;

    // Initialization completion tracking
    reg initialized;

    always @(posedge clk) begin
        if (reset) begin
            initialized <= 1'b0;
        end
        else begin
            if (initialize_start && initial_config_valid)
                initialized <= 1'b0;

            if (initialize_done)
                initialized <= 1'b1;
        end
    end

    // ------------------------------------------------
    // 3. INPUT INTERFACE
    // ------------------------------------------------

    input_interface #(
        .MAX_QUBITS(MAX_QUBITS),
        .MAX_GATES(MAX_GATES)
    ) U_INPUT_INTERFACE (
        .start(instruction_write_enable),
        .num_qubits(num_qubits),
        .initial_state(initial_state),
        .gate_count(gate_count),
        .gate_type(instruction_write_gate),
        .target_qubit(instruction_write_target),
        .control_qubit(instruction_write_control),
        .valid(validation_valid),
        .error(validation_error)
    );

    assign instruction_valid =
        validation_valid &&
        initial_config_valid &&
        instruction_address_valid;

    assign input_error =
        validation_error ||
        (instruction_write_enable &&
         (!initial_config_valid || !instruction_address_valid)) ||
        (initialize_start && !initial_config_valid);

    // ------------------------------------------------
    // 4. INITIAL STATE GENERATOR
    // ------------------------------------------------

    initial_state_generator #(
        .MAX_QUBITS(MAX_QUBITS),
        .DATA_WIDTH(DATA_WIDTH)
    ) U_INITIAL_STATE (
        .clk(clk),
        .reset(reset),
        .start(initialize_start && initial_config_valid),
        .num_qubits(num_qubits),
        .initial_basis_state(initial_state),
        .write_address(init_write_address),
        .real_data(init_real_data),
        .imag_data(init_imag_data),
        .write_enable(init_write_enable),
        .busy(initialize_busy),
        .done(initialize_done)
    );

    // ------------------------------------------------
    // 5. INSTRUCTION MEMORY
    // ------------------------------------------------

    instruction_memory #(
        .MAX_GATES(MAX_GATES),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) U_INSTRUCTION_MEMORY (
        .clk(clk),

        .write_enable(
            instruction_write_enable &&
            validation_valid &&
            initial_config_valid &&
            instruction_address_valid
        ),

        .write_address(instruction_write_address),
        .write_gate_type(instruction_write_gate),
        .write_target_qubit(instruction_write_target),
        .write_control_qubit(instruction_write_control),

        .read_address(instruction_read_address),
        .read_gate_type(instruction_read_gate),
        .read_target_qubit(instruction_read_target),
        .read_control_qubit(instruction_read_control)
    );

    // ------------------------------------------------
    // 6. CIRCUIT CONTROLLER
    // ------------------------------------------------

    circuit_controller #(
        .MAX_GATES(MAX_GATES),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) U_CIRCUIT_CONTROLLER (
        .clk(clk),
        .reset(reset),

        // Execution starts only after initialization
        .start(circuit_start && initialized && !initialize_busy),

        .gate_count(gate_count),
        .num_qubits(num_qubits),

        .instruction_address(instruction_read_address),
        .instruction_gate_type(instruction_read_gate),
        .instruction_target_qubit(instruction_read_target),
        .instruction_control_qubit(instruction_read_control),

        .gate_start(gate_start),
        .gate_type(gate_type),
        .gate_num_qubits(),
        .target_qubit(target_qubit),
        .control_qubit(control_qubit),

        .gate_busy(gate_busy),
        .gate_done(gate_done),
        .gate_error(gate_error),

        .busy(circuit_busy),
        .circuit_done(circuit_done),
        .circuit_error(controller_circuit_error)
    );

    assign circuit_error =
        controller_circuit_error ||
        (circuit_start && !initialized);

    // ------------------------------------------------
    // 7. GATE PROCESSING UNIT
    // ------------------------------------------------

    gate_processing_unit #(
        .MAX_QUBITS(MAX_QUBITS),
        .DATA_WIDTH(DATA_WIDTH)
    ) U_GATE_PROCESSING_UNIT (
        .clk(clk),
        .reset(reset),
        .start(gate_start),

        .num_qubits(num_qubits),
        .gate_type(gate_type),
        .target_qubit(target_qubit),
        .control_qubit(control_qubit),

        .read_address_a(read_address_a),
        .read_real_data_a(read_real_a),
        .read_imag_data_a(read_imag_a),

        .read_address_b(read_address_b),
        .read_real_data_b(read_real_b),
        .read_imag_data_b(read_imag_b),

        .write_enable(gate_memory_write_enable),
        .write_address(gate_memory_write_address),
        .write_real_data(gate_memory_write_real),
        .write_imag_data(gate_memory_write_imag),

        .busy(gate_busy),
        .done(gate_done),
        .error(gate_error)
    );

    // ------------------------------------------------
    // 8. STATE MEMORY WRITE SELECTION
    // ------------------------------------------------

    // Initialization writes have priority.
    // Gate processing writes after initialization.

    assign memory_write_enable =
        init_write_enable ? 1'b1 : gate_memory_write_enable;

    assign memory_write_address =
        init_write_enable ? init_write_address :
                            gate_memory_write_address;

    assign memory_write_real =
        init_write_enable ? init_real_data :
                            gate_memory_write_real;

    assign memory_write_imag =
        init_write_enable ? init_imag_data :
                            gate_memory_write_imag;

    // ------------------------------------------------
    // 9. STATE MEMORY
    // ------------------------------------------------

    state_memory #(
        .MAX_QUBITS(MAX_QUBITS),
        .DATA_WIDTH(DATA_WIDTH)
    ) U_STATE_MEMORY (
        .clk(clk),

        .write_enable(memory_write_enable),
        .write_address(memory_write_address),
        .write_real_data(memory_write_real),
        .write_imag_data(memory_write_imag),

        .read_address_a(read_address_a),
        .read_real_data_a(read_real_a),
        .read_imag_data_a(read_imag_a),

        .read_address_b(read_address_b),
        .read_real_data_b(read_real_b),
        .read_imag_data_b(read_imag_b),

        // Third read port for result inspection
        .result_read_address(result_read_address),
        .result_real(result_real),
        .result_imag(result_imag)
    );

endmodule
