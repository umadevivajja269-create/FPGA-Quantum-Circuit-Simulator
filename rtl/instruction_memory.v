module instruction_memory #(
    parameter MAX_GATES = 16,
    parameter ADDR_WIDTH = 4
)
(
    input wire clk,

    // User instruction write interface
    input wire write_enable,
    input wire [ADDR_WIDTH-1:0] write_address,
    input wire [2:0] write_gate_type,
    input wire [1:0] write_target_qubit,
    input wire [1:0] write_control_qubit,

    // Controller instruction read interface
    input wire [ADDR_WIDTH-1:0] read_address,
    output reg [2:0] read_gate_type,
    output reg [1:0] read_target_qubit,
    output reg [1:0] read_control_qubit
);

    // Instruction storage
    reg [2:0] gate_memory [0:MAX_GATES-1];
    reg [1:0] target_memory [0:MAX_GATES-1];
    reg [1:0] control_memory [0:MAX_GATES-1];

    // Store user instructions
    always @(posedge clk)
    begin
        if (write_enable && write_address < MAX_GATES)
        begin
            gate_memory[write_address] <= write_gate_type;
            target_memory[write_address] <= write_target_qubit;
            control_memory[write_address] <= write_control_qubit;
        end
    end

    // Read stored instructions
    always @(*)
    begin
        if (read_address < MAX_GATES)
        begin
            read_gate_type = gate_memory[read_address];
            read_target_qubit = target_memory[read_address];
            read_control_qubit = control_memory[read_address];
        end
        else
        begin
            read_gate_type = 3'b000;
            read_target_qubit = 2'b00;
            read_control_qubit = 2'b00;
        end
    end

endmodule
