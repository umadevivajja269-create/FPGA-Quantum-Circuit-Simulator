
module state_memory #(
    parameter MAX_QUBITS = 4,
    parameter DATA_WIDTH = 16
)(
    input wire clk,

    // Write port
    input wire write_enable,
    input wire [MAX_QUBITS-1:0] write_address,
    input wire signed [DATA_WIDTH-1:0] write_real_data,
    input wire signed [DATA_WIDTH-1:0] write_imag_data,

    // Read port A: Gate processing
    input wire [MAX_QUBITS-1:0] read_address_a,
    output wire signed [DATA_WIDTH-1:0] read_real_data_a,
    output wire signed [DATA_WIDTH-1:0] read_imag_data_a,

    // Read port B: Gate processing
    input wire [MAX_QUBITS-1:0] read_address_b,
    output wire signed [DATA_WIDTH-1:0] read_real_data_b,
    output wire signed [DATA_WIDTH-1:0] read_imag_data_b,

    // Read port C: Final result inspection
    input wire [MAX_QUBITS-1:0] result_read_address,
    output wire signed [DATA_WIDTH-1:0] result_real,
    output wire signed [DATA_WIDTH-1:0] result_imag
);

    localparam DEPTH = (1 << MAX_QUBITS);

    // Separate memories for real and imaginary amplitudes
    reg signed [DATA_WIDTH-1:0] real_memory [0:DEPTH-1];
    reg signed [DATA_WIDTH-1:0] imag_memory [0:DEPTH-1];

    // Synchronous memory write
    always @(posedge clk) begin
        if (write_enable) begin
            real_memory[write_address] <= write_real_data;
            imag_memory[write_address] <= write_imag_data;
        end
    end

    // Combinational read ports
    assign read_real_data_a = real_memory[read_address_a];
    assign read_imag_data_a = imag_memory[read_address_a];

    assign read_real_data_b = real_memory[read_address_b];
    assign read_imag_data_b = imag_memory[read_address_b];

    // Result read port
    assign result_real = real_memory[result_read_address];
    assign result_imag = imag_memory[result_read_address];

endmodule
