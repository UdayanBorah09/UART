module uart_tx #(
    parameter CLOCK_FREQ = 27000000,  // System clock in Hz
    parameter BAUD_RATE  = 1000000       // Desired baud rate
)
(
    input clk, rst,
    input [7:0] data_in,
    input data_ready,
    output reg Tx
); 

reg baud_tick;
localparam integer DIVIDER = CLOCK_FREQ / BAUD_RATE;
reg [$clog2(DIVIDER)-1:0] counter = 0;

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            counter   <= 0;
            baud_tick <= 0;
        end else begin
            if (counter == DIVIDER - 1) begin
                counter   <= 0;
                baud_tick <= 1;
            end else begin
                counter   <= counter + 1;
                baud_tick <= 0;
            end
        end
    end


parameter clk_cycles_perbit = 16;

parameter IDLE = 0, LOAD_SR = 1, START = 2, TRANSFER = 3, STOP = 4;

reg [7:0] clk_count;
reg [2:0] prev_state, next_state;
wire done;
reg parity;
reg [7:0] TSR;
reg [3:0] bit_count;


always @(posedge clk or negedge rst) begin
    if (!rst) begin
        prev_state <= IDLE;
    end
    else 
        prev_state <= next_state;
end


always @(*) begin
    next_state = IDLE;
    case(prev_state)
        IDLE: begin
            if (data_ready == 1) begin
                next_state = LOAD_SR;
            end
            else
                next_state = IDLE;
        end        
        LOAD_SR: begin
            if (baud_tick)
                next_state = START;
            else 
                next_state = LOAD_SR;
        end
        START: 
                    next_state = TRANSFER;

        TRANSFER: begin
            if (bit_count == 9)
                next_state = STOP;
            else
                next_state = TRANSFER;
        end
        // PARITY: begin 
            // if (bit_count == 0)
            //     next_state = STOP;
            // else
            //     next_state = PARITY;
            // end
        STOP: begin 
            if (bit_count == 0)
                next_state = IDLE;
            else
                next_state = STOP;
            end
        default: next_state = IDLE;
    endcase
end

always @(posedge clk or negedge rst) begin
    if (!rst) begin
        TSR <= 8'h00;
        Tx <= 1;
        clk_count <= 0;
        bit_count <= 0;
        parity <= 0;
    end
    else begin
        case (prev_state)
            IDLE: begin
                TSR <= 8'h00;
                Tx <= 1;
                clk_count <= 0;
                bit_count <= 0;
                parity <= 0;
            end
            LOAD_SR: begin
                TSR <= data_in;
            end

            START: begin 
                Tx <= 0;
            end
            TRANSFER: begin
                if (baud_tick) begin
                    bit_count <= bit_count + 1;
                    if (bit_count < 8) begin
                        $display("In data, time = %0t", $time);
                        Tx <= TSR[0];
                        if (bit_count == 0)
                            parity <= TSR[0];
                        else
                            parity <= parity ^ TSR[0];
                        TSR <= {1'b0,TSR[7:1]};
                    end
                    if (bit_count == 8) begin
                        $display("In parity, time = %0t", $time);
                        Tx <= parity;
                    end
                end
            end
            
            STOP: begin
                if (baud_tick) begin
                    Tx <= 1;
                    bit_count <= 0;
                end
            end
            default: begin
                TSR <= 8'h00;
                Tx <= 1;
                bit_count <= 0;
                parity <= 0;
            end 
        endcase
    end
end
endmodule
