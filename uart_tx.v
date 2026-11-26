
module uart_tx #(
    parameter CLKS_PER_BIT = 868
)(
    input wire clk,
    input wire reset,

    input wire tx_start,
    input wire [7:0] tx_data,

    output reg tx_serial,
    output reg tx_busy
);

    localparam IDLE  = 2'd0;
    localparam START = 2'd1;
    localparam DATA  = 2'd2;
    localparam STOP  = 2'd3;

    reg [1:0] state;
    reg [15:0] clock_count;
    reg [2:0] bit_index;
    reg [7:0] data_buffer;

    always @(posedge clk) begin

        if (reset) begin
            state       <= IDLE;
            clock_count <= 0;
            bit_index   <= 0;
            data_buffer <= 0;
            tx_serial   <= 1'b1;
            tx_busy     <= 1'b0;
        end
        else begin

            case (state)

                IDLE: begin
                    tx_serial   <= 1'b1;
                    tx_busy     <= 1'b0;
                    clock_count <= 0;
                    bit_index   <= 0;

                    if (tx_start) begin
                        data_buffer <= tx_data;
                        tx_busy     <= 1'b1;
                        tx_serial   <= 1'b0;
                        clock_count <= CLKS_PER_BIT - 1;
                        state       <= START;
                    end
                end

                START: begin
                    tx_busy <= 1'b1;

                    if (clock_count == 0) begin
                        tx_serial   <= data_buffer[0];
                        clock_count <= CLKS_PER_BIT - 1;
                        bit_index   <= 0;
                        state       <= DATA;
                    end
                    else begin
                        clock_count <= clock_count - 1'b1;
                    end
                end

                DATA: begin
                    tx_busy <= 1'b1;

                    if (clock_count == 0) begin

                        if (bit_index == 7) begin
                            tx_serial   <= 1'b1;
                            clock_count <= CLKS_PER_BIT - 1;
                            state       <= STOP;
                        end
                        else begin
                            bit_index   <= bit_index + 1'b1;
                            tx_serial   <= data_buffer[bit_index + 1'b1];
                            clock_count <= CLKS_PER_BIT - 1;
                        end

                    end
                    else begin
                        clock_count <= clock_count - 1'b1;
                    end
                end

                STOP: begin
                    tx_busy <= 1'b1;

                    if (clock_count == 0) begin
                        tx_serial   <= 1'b1;
                        tx_busy     <= 1'b0;
                        state       <= IDLE;
                    end
                    else begin
                        clock_count <= clock_count - 1'b1;
                    end
                end

                default: begin
                    state     <= IDLE;
                    tx_serial <= 1'b1;
                    tx_busy   <= 1'b0;
                end

            endcase
        end
    end

endmodule
