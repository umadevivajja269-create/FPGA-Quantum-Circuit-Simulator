module circuit_controller #(
    parameter MAX_GATES = 16,
    parameter ADDR_WIDTH = 4
)
(
    input wire clk,
    input wire reset,
    input wire start,

    input wire [4:0] gate_count,
    input wire [2:0] num_qubits,

    // Instruction Memory read interface
    output reg [ADDR_WIDTH-1:0] instruction_address,
    input wire [2:0] instruction_gate_type,
    input wire [1:0] instruction_target_qubit,
    input wire [1:0] instruction_control_qubit,

    // Gate Processing Unit interface
    output reg gate_start,
    output reg [2:0] gate_type,
    output reg [2:0] gate_num_qubits,
    output reg [1:0] target_qubit,
    output reg [1:0] control_qubit,

    input wire gate_busy,
    input wire gate_done,
    input wire gate_error,

    output reg busy,
    output reg circuit_done,
    output reg circuit_error
);

    localparam IDLE       = 3'd0;
    localparam LOAD       = 3'd1;
    localparam EXECUTE    = 3'd2;
    localparam WAIT_GATE  = 3'd3;
    localparam NEXT_GATE  = 3'd4;
    localparam FINISH     = 3'd5;
    localparam ERROR      = 3'd6;

    reg [2:0] state;
    reg [4:0] gate_counter;
    reg [4:0] total_gates;

    always @(posedge clk or posedge reset)
    begin
        if (reset)
        begin
            state <= IDLE;
            gate_counter <= 0;
            total_gates <= 0;
            instruction_address <= 0;

            gate_start <= 0;
            gate_type <= 0;
            gate_num_qubits <= 0;
            target_qubit <= 0;
            control_qubit <= 0;

            busy <= 0;
            circuit_done <= 0;
            circuit_error <= 0;
        end
        else
        begin
            gate_start <= 0;
            circuit_done <= 0;

            case (state)

                IDLE:
                begin
                    busy <= 0;
                    circuit_error <= 0;

                    if (start)
                    begin
                        if ((num_qubits >= 1) &&
                            (num_qubits <= 4) &&
                            (gate_count <= MAX_GATES))
                        begin
                            total_gates <= gate_count;
                            gate_counter <= 0;
                            instruction_address <= 0;
                            gate_num_qubits <= num_qubits;
                            busy <= 1;

                            if (gate_count == 0)
                                state <= FINISH;
                            else
                                state <= LOAD;
                        end
                        else
                            state <= ERROR;
                    end
                end

                LOAD:
                begin
                    instruction_address <= gate_counter;
                    state <= EXECUTE;
                end

                EXECUTE:
                begin
                    gate_type <= instruction_gate_type;
                    target_qubit <= instruction_target_qubit;
                    control_qubit <= instruction_control_qubit;

                    gate_start <= 1;
                    state <= WAIT_GATE;
                end

                WAIT_GATE:
                begin
                    if (gate_error)
                        state <= ERROR;
                    else if (gate_done)
                        state <= NEXT_GATE;
                end

                NEXT_GATE:
                begin
                    if (gate_counter + 1 >= total_gates)
                        state <= FINISH;
                    else
                    begin
                        gate_counter <= gate_counter + 1'b1;
                        instruction_address <= gate_counter + 1'b1;
                        state <= LOAD;
                    end
                end

                FINISH:
                begin
                    busy <= 0;
                    circuit_done <= 1;
                    state <= IDLE;
                end

                ERROR:
                begin
                    busy <= 0;
                    circuit_error <= 1;
                    state <= IDLE;
                end

                default:
                    state <= IDLE;

            endcase
        end
    end

endmodule