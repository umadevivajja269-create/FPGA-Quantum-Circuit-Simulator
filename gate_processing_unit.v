`timescale 1ns / 1ps

module gate_processing_unit #(
    parameter MAX_QUBITS = 4,
    parameter DATA_WIDTH = 16
)(
    input wire clk,
    input wire reset,
    input wire start,

    input wire [$clog2(MAX_QUBITS+1)-1:0] num_qubits,
    input wire [2:0] gate_type,
    input wire [$clog2(MAX_QUBITS)-1:0] target_qubit,
    input wire [$clog2(MAX_QUBITS)-1:0] control_qubit,

    // State memory read interface
    output wire [MAX_QUBITS-1:0] read_address_a,
    output wire [MAX_QUBITS-1:0] read_address_b,

    input wire signed [DATA_WIDTH-1:0] read_real_data_a,
    input wire signed [DATA_WIDTH-1:0] read_imag_data_a,
    input wire signed [DATA_WIDTH-1:0] read_real_data_b,
    input wire signed [DATA_WIDTH-1:0] read_imag_data_b,

    // State memory write interface
    output reg write_enable,
    output reg [MAX_QUBITS-1:0] write_address,
    output reg signed [DATA_WIDTH-1:0] write_real_data,
    output reg signed [DATA_WIDTH-1:0] write_imag_data,

    output reg busy,
    output reg done,
    output reg error
);

    // Gate encoding
    localparam H    = 3'b000;
    localparam X    = 3'b001;
    localparam S    = 3'b010;
    localparam SDG  = 3'b011;
    localparam CNOT = 3'b100;

    // Controller states
    localparam IDLE    = 3'b000;
    localparam SCAN    = 3'b001;
    localparam READ    = 3'b010;
    localparam CALC    = 3'b011;
    localparam WRITE_A = 3'b100;
    localparam WRITE_B = 3'b101;
    localparam FINISH  = 3'b110;

    // Q2.14 representation of 1/sqrt(2)
    localparam signed [15:0] SQRT_HALF = 16'sd11585;

    reg [2:0] state;

    reg [2:0] selected_gate;
    reg [MAX_QUBITS-1:0] target_mask;
    reg [MAX_QUBITS-1:0] control_mask;

    reg [MAX_QUBITS:0] total_states;
    reg [MAX_QUBITS:0] scan_counter;

    reg signed [DATA_WIDTH-1:0] real_a, imag_a;
    reg signed [DATA_WIDTH-1:0] real_b, imag_b;

    reg signed [DATA_WIDTH-1:0] result_a_real;
    reg signed [DATA_WIDTH-1:0] result_a_imag;
    reg signed [DATA_WIDTH-1:0] result_b_real;
    reg signed [DATA_WIDTH-1:0] result_b_imag;

    // H-gate intermediate calculations
    wire signed [DATA_WIDTH:0] sum_real;
    wire signed [DATA_WIDTH:0] sum_imag;
    wire signed [DATA_WIDTH:0] diff_real;
    wire signed [DATA_WIDTH:0] diff_imag;

    wire signed [33:0] product_a_real;
    wire signed [33:0] product_a_imag;
    wire signed [33:0] product_b_real;
    wire signed [33:0] product_b_imag;

    assign sum_real =
        $signed({real_a[DATA_WIDTH-1], real_a}) +
        $signed({real_b[DATA_WIDTH-1], real_b});

    assign sum_imag =
        $signed({imag_a[DATA_WIDTH-1], imag_a}) +
        $signed({imag_b[DATA_WIDTH-1], imag_b});

    assign diff_real =
        $signed({real_a[DATA_WIDTH-1], real_a}) -
        $signed({real_b[DATA_WIDTH-1], real_b});

    assign diff_imag =
        $signed({imag_a[DATA_WIDTH-1], imag_a}) -
        $signed({imag_b[DATA_WIDTH-1], imag_b});

    assign product_a_real =
        $signed(sum_real) * $signed(SQRT_HALF);

    assign product_a_imag =
        $signed(sum_imag) * $signed(SQRT_HALF);

    assign product_b_real =
        $signed(diff_real) * $signed(SQRT_HALF);

    assign product_b_imag =
        $signed(diff_imag) * $signed(SQRT_HALF);

    // Read addresses for the selected amplitude pair
    assign read_address_a = scan_counter[MAX_QUBITS-1:0];

    assign read_address_b =
        scan_counter[MAX_QUBITS-1:0] | target_mask;

    // Memory write control
    always @(*) begin

        write_enable = 1'b0;
        write_address = 0;
        write_real_data = 0;
        write_imag_data = 0;

        if (state == WRITE_A) begin

            write_enable = 1'b1;
            write_address = scan_counter[MAX_QUBITS-1:0];

            write_real_data = result_a_real;
            write_imag_data = result_a_imag;

        end

        else if (state == WRITE_B) begin

            write_enable = 1'b1;

            write_address =
                scan_counter[MAX_QUBITS-1:0] | target_mask;

            write_real_data = result_b_real;
            write_imag_data = result_b_imag;

        end
    end

    // Main controller
    always @(posedge clk) begin

        if (reset) begin

            state <= IDLE;
            selected_gate <= 0;

            target_mask <= 0;
            control_mask <= 0;

            total_states <= 0;
            scan_counter <= 0;

            real_a <= 0;
            imag_a <= 0;
            real_b <= 0;
            imag_b <= 0;

            result_a_real <= 0;
            result_a_imag <= 0;
            result_b_real <= 0;
            result_b_imag <= 0;

            busy <= 0;
            done <= 0;
            error <= 0;

        end

        else begin

            done <= 0;
            error <= 0;

            case (state)

                IDLE: begin

                    busy <= 0;

                    if (start) begin

                        if ((num_qubits == 0) ||
                            (num_qubits > MAX_QUBITS) ||
                            (target_qubit >= num_qubits) ||
                            (gate_type > CNOT) ||
                            ((gate_type == CNOT) &&
                             ((control_qubit >= num_qubits) ||
                              (control_qubit == target_qubit)))) begin

                            error <= 1;

                        end

                        else begin

                            selected_gate <= gate_type;

                            total_states <=
                                (1 << num_qubits);

                            scan_counter <= 0;

                            target_mask <=
                                (1'b1 << (num_qubits - 1 - target_qubit));

                            if (gate_type == CNOT) begin
                                control_mask <=
                                    (1'b1 << (num_qubits - 1 - control_qubit));
                            end
                            else begin
                                control_mask <= 0;
                            end

                            busy <= 1;
                            state <= SCAN;

                        end
                    end
                end

                SCAN: begin

                    if (scan_counter >= total_states) begin

                        state <= FINISH;

                    end

                    else begin

                        case (selected_gate)

                            H, X: begin

                                if ((scan_counter & target_mask) == 0)
                                    state <= READ;
                                else
                                    scan_counter <= scan_counter + 1;

                            end

                            CNOT: begin

                                if (((scan_counter & target_mask) == 0) &&
                                    ((scan_counter & control_mask) != 0))
                                    state <= READ;
                                else
                                    scan_counter <= scan_counter + 1;

                            end

                            S, SDG: begin

                                if ((scan_counter & target_mask) != 0)
                                    state <= READ;
                                else
                                    scan_counter <= scan_counter + 1;

                            end

                            default: begin
                                error <= 1;
                                state <= FINISH;
                            end

                        endcase
                    end
                end

                READ: begin

                    real_a <= read_real_data_a;
                    imag_a <= read_imag_data_a;

                    real_b <= read_real_data_b;
                    imag_b <= read_imag_data_b;

                    state <= CALC;

                end

                CALC: begin

                    case (selected_gate)

                        H: begin

                            result_a_real <= product_a_real >>> 14;
                            result_a_imag <= product_a_imag >>> 14;

                            result_b_real <= product_b_real >>> 14;
                            result_b_imag <= product_b_imag >>> 14;

                        end

                        X, CNOT: begin

                            result_a_real <= real_b;
                            result_a_imag <= imag_b;

                            result_b_real <= real_a;
                            result_b_imag <= imag_a;

                        end

                        S: begin

                            // Multiply amplitude by +i
                            result_a_real <= -imag_a;
                            result_a_imag <= real_a;

                        end

                        SDG: begin

                            // Multiply amplitude by -i
                            result_a_real <= imag_a;
                            result_a_imag <= -real_a;

                        end

                        default: begin
                            error <= 1;
                        end

                    endcase

                    state <= WRITE_A;

                end

                WRITE_A: begin

                    if ((selected_gate == S) ||
                        (selected_gate == SDG)) begin

                        scan_counter <= scan_counter + 1;
                        state <= SCAN;

                    end

                    else begin

                        state <= WRITE_B;

                    end

                end

                WRITE_B: begin

                    scan_counter <= scan_counter + 1;
                    state <= SCAN;

                end

                FINISH: begin

                    busy <= 0;
                    done <= 1;
                    state <= IDLE;

                end

                default: begin

                    state <= IDLE;
                    busy <= 0;

                end

            endcase
        end
    end

endmodule