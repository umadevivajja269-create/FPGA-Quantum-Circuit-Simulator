`timescale 1ns / 1ps

module initial_state_generator #(
    parameter MAX_QUBITS = 4,
    parameter DATA_WIDTH = 16
)(
    input  wire clk,
    input  wire reset,
    input  wire start,

    input  wire [$clog2(MAX_QUBITS+1)-1:0] num_qubits,
    input  wire [MAX_QUBITS-1:0] initial_basis_state,

    output reg [MAX_QUBITS-1:0] write_address,
    output reg signed [DATA_WIDTH-1:0] real_data,
    output reg signed [DATA_WIDTH-1:0] imag_data,

    output reg write_enable,
    output reg busy,
    output reg done
);

    localparam IDLE = 2'b00;
    localparam INIT = 2'b01;
    localparam FINISH = 2'b10;

    reg [1:0] state;

    reg [MAX_QUBITS:0] total_states;
    reg [MAX_QUBITS:0] address_count;

    reg [MAX_QUBITS-1:0] selected_state;

    always @(posedge clk) begin

        if (reset) begin
            state          <= IDLE;
            total_states   <= 0;
            address_count  <= 0;
            selected_state <= 0;
            write_address  <= 0;
            real_data      <= 0;
            imag_data      <= 0;
            write_enable   <= 0;
            busy           <= 0;
            done           <= 0;
        end

        else begin

            write_enable <= 0;
            done <= 0;

            case (state)

                IDLE: begin
                    busy <= 0;

                    if (start && num_qubits >= 1 &&
                        num_qubits <= MAX_QUBITS) begin

                        total_states <=
                            (1 << num_qubits);

                        address_count <= 0;
                        selected_state <= initial_basis_state;

                        busy <= 1;
                        state <= INIT;
                    end
                end

                INIT: begin

                    write_address <= address_count;

                    if (address_count == selected_state) begin
                        real_data <=
                            (1 << (DATA_WIDTH-2));
                    end
                    else begin
                        real_data <= 0;
                    end

                    imag_data <= 0;
                    write_enable <= 1;

                    if (address_count == total_states - 1) begin
                        state <= FINISH;
                    end
                    else begin
                        address_count <= address_count + 1;
                    end

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