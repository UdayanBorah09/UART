module uart_rx #(
    parameter CLOCK_FREQ = 27000000,    // System clock in Hz
    parameter BAUD_RATE  = 1000000      // Desired baud rate
)(
    input clk, rst,
    input Rx,
    output reg [7:0] data_out,
    output reg done
);

    // Internal error flags (optional to output)
    reg start_err, parity_err, stop_err;

    // 9x oversampling
    parameter oversample_rate = 9;
    localparam integer DIVIDER = CLOCK_FREQ / (BAUD_RATE * oversample_rate);
    reg [$clog2(DIVIDER)-1:0] counter = 0;
    reg oversample_tick = 0;

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            counter <= 0;
            oversample_tick <= 0;
        end else begin
            if (counter == DIVIDER - 1) begin
                counter <= 0;
                oversample_tick <= 1;
            end else begin
                counter <= counter + 1;
                oversample_tick <= 0;
            end
        end
    end

    // FSM
    localparam IDLE = 0, RECEIVE = 1, PARITY_CHECK = 2, DONE = 3;
    reg [1:0] state = IDLE, next_state;

    reg [7:0] RSR = 0;
    reg [3:0] bit_count = 0;
    reg [3:0] clk_count = 0;  // Max 9
    reg int_parity = 0;
    reg parity = 0;
    reg parity_check_done = 0;

    always @(posedge clk) begin
        if (!rst)
            state <= IDLE;
        else
            state <= next_state;
    end

    always @(*) begin
        case (state)
            IDLE:
                next_state = (Rx == 0) ? RECEIVE : IDLE;

            RECEIVE:
                next_state = (bit_count > 10) ? PARITY_CHECK : RECEIVE;

            PARITY_CHECK:
                next_state = (parity_check_done) ? DONE : PARITY_CHECK;

            DONE:
                next_state = IDLE;

            default:
                next_state = IDLE;
        endcase
    end

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            RSR <= 8'h00;
            bit_count <= 0;
            clk_count <= 0;
            int_parity <= 0;
            parity <= 0;
            start_err <= 0;
            parity_err <= 0;
            stop_err <= 0;
            parity_check_done <= 0;
            done <= 0;
            data_out <= 0;
        end else begin
            if (state == IDLE) begin
                RSR <= 0;
                bit_count <= 0;
                clk_count <= 0;
                int_parity <= 0;
                parity <= 0;
                start_err <= 0;
                parity_err <= 0;
                stop_err <= 0;
                parity_check_done <= 0;
                done <= 0;
                //data_out <= 0;
            end

            else if (state == RECEIVE && oversample_tick) begin
                clk_count <= clk_count + 1;

                if (bit_count == 0 && clk_count == (oversample_rate >> 1)) begin
                    if (Rx != 0)
                        start_err <= 1;
                    bit_count <= bit_count + 1;
                    clk_count <= 0;
                end

                else if (bit_count >= 1 && bit_count <= 8 && clk_count == (oversample_rate - 1)) begin
                    RSR <= {Rx, RSR[7:1]};
                    int_parity <= int_parity ^ Rx;
                    bit_count <= bit_count + 1;
                    clk_count <= 0;
                end

                else if (bit_count == 9 && clk_count == (oversample_rate - 1)) begin
                    parity <= Rx;
                    bit_count <= bit_count + 1;
                    clk_count <= 0;
                end

                else if (bit_count == 10 && clk_count == (oversample_rate - 1)) begin
                    if (Rx != 1)
                        stop_err <= 1;
                    bit_count <= bit_count + 1;
                    clk_count <= 0;
                end
            end

            else if (state == PARITY_CHECK) begin
                if (int_parity != parity) begin
                    done <= 0;
                    parity_err <= 1;
                end else begin
                    parity_err <= 0;
                    done <= 1;
                    data_out <= RSR;
                end
                parity_check_done <= 1;
            end

            else if (state == DONE) begin
                // Hold data_out and done high for one cycle
            end
        end
    end
endmodule
