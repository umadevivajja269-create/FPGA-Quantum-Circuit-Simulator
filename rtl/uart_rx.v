
module uart_rx #(
    parameter CLKS_PER_BIT = 868
)(
    input wire clk,
    input wire reset,
    input wire rx_serial,

    output reg [7:0] rx_data,
    output reg rx_valid
);

    localparam IDLE  = 2'd0;
    localparam START = 2'd1;
    localparam DATA  = 2'd2;
    localparam STOP  = 2'd3;

    reg [1:0] state;
    reg [15:0] clock_count;
    reg [2:0] bit_index;

    always @(posedge clk) begin
        if (reset) begin
            state       <= IDLE;
            clock_count <= 0;
            bit_index   <= 0;
            rx_data     <= 0;
            rx_valid    <= 0;
        end
        else begin
            rx_valid <= 1'b0;

            case (state)

                IDLE: begin
                    clock_count <= 0;
                    bit_index <= 0;

                    if (rx_serial == 1'b0) begin
                        clock_count <= CLKS_PER_BIT / 2;
                        state <= START;
                    end
                end

                START: begin
                    if (clock_count == 0) begin
                        if (rx_serial == 1'b0) begin
                            clock_count <= CLKS_PER_BIT - 1;
                            state <= DATA;
                        end
                        else begin
                            state <= IDLE;
                        end
                    end
                    else begin
                        clock_count <= clock_count - 1'b1;
                    end
                end

                DATA: begin
                    if (clock_count == 0) begin
                        rx_data[bit_index] <= rx_serial;
                        clock_count <= CLKS_PER_BIT - 1;

                        if (bit_index == 7)
                            state <= STOP;
                        else
                            bit_index <= bit_index + 1'b1;
                    end
                    else begin
                        clock_count <= clock_count - 1'b1;
                    end
                end

                STOP: begin
                    if (clock_count == 0) begin
                        if (rx_serial == 1'b1)
                            rx_valid <= 1'b1;

                        state <= IDLE;
                        clock_count <= 0;
                    end
                    else begin
                        clock_count <= clock_count - 1'b1;
                    end
                end

                default: state <= IDLE;

            endcase
        end
    end

endmodule
