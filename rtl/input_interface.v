module input_interface #(
    parameter MAX_QUBITS = 4,
    parameter MAX_GATES  = 15
)(
    input  wire start,

    input  wire [$clog2(MAX_QUBITS+1)-1:0] num_qubits,
    input  wire [MAX_QUBITS-1:0] initial_state,

    input  wire [$clog2(MAX_GATES+1)-1:0] gate_count,

    input  wire [2:0] gate_type,
    input  wire [$clog2(MAX_QUBITS)-1:0] target_qubit,
    input  wire [$clog2(MAX_QUBITS)-1:0] control_qubit,

    output reg valid,
    output reg error
);

always @(*) begin

    valid = 1'b0;
    error = 1'b0;

    if (start) begin

        if ((num_qubits == 0) ||
            (num_qubits > MAX_QUBITS) ||
            (gate_count > MAX_GATES)) begin

            error = 1'b1;

        end
        else if (target_qubit >= num_qubits) begin

            error = 1'b1;

        end
        else if ((gate_type == 3'b100) &&
                 ((control_qubit >= num_qubits) ||
                  (control_qubit == target_qubit))) begin

            error = 1'b1;

        end
        else if (gate_type > 3'b100) begin

            error = 1'b1;

        end
        else begin

            valid = 1'b1;

        end

    end

end

endmodule
