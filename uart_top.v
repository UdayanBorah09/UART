module uart_top #(
    parameter CLOCK_FREQ = 27000000,    // System clock frequency in Hz
    parameter BAUD_RATE  = 3000000      // UART baud rate
)(
    input clk,                          // System clock
    input rst_n,                        // Active low reset
    input uart_rx_pin,                  // UART RX input pin
    output uart_tx_pin,                 // UART TX output pin
    
    // Optional status outputs
    output rx_data_valid,               // High when new data received
    output [7:0] rx_data_out,          // Last received data
    output tx_busy                     // High when transmitting
    
    // Optional error flags
    
);
    wire rx_parity_error;
    wire rx_frame_error;
    // Internal signals
    wire rst = ~rst_n;                  // Convert to active high reset
    
    // RX signals
    wire [7:0] rx_data;
    wire rx_done;
    
    // TX signals
    reg [7:0] tx_data;
    reg tx_data_ready;
    wire tx_out;
    
    // Echo buffer to store received data
    reg [7:0] echo_buffer;
    reg echo_pending;
    
    // Status outputs
    assign rx_data_valid = rx_done;
    assign rx_data_out = rx_data;
    assign uart_tx_pin = tx_out;
    
    // Simple TX busy detection (could be improved with actual TX busy signal)
    reg tx_busy_reg;
    assign tx_busy = tx_busy_reg;
    
    // Error flag assignments (you may want to expose these from uart_rx)
    assign rx_parity_error = 1'b0;     // Connect to uart_rx parity error if available
    assign rx_frame_error = 1'b0;      // Connect to uart_rx frame error if available


    //PLL Clock
    wire clk_fast;
    Gowin_rPLL pll(
        .clkout(clk_fast), //output clkout
        .clkin(clk) //input clkin
    );

    //Multiplier
    wire ce = 1;
    
//    Gowin_MULT mult8x8(
//        .dout(dout), //output [15:0] dout
//        .a(a), //input [7:0] a
//        .b(b), //input [7:0] b
//        .ce(ce), //input ce
//        .clk(clk_fast), //input clk
//        .reset(rst) //input reset
//    );
    // Instantiate UART RX
    uart_rx #(
        .CLOCK_FREQ(CLOCK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) uart_rx_inst (
        .clk(clk_fast),
        .rst(rst_n),                    // uart_rx uses active low reset
        .Rx(uart_rx_pin),
        .data_out(rx_data),
        .done(rx_done)
    );

    // Instantiate UART TX
    uart_tx #(
        .CLOCK_FREQ(CLOCK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) uart_tx_inst (
        .clk(clk_fast),
        .rst(rst_n),                      // uart_tx uses active high reset
        .data_in(tx_data),
        .data_ready(tx_data_ready),
        .Tx(tx_out)
    );
    
    always @(posedge clk_fast or negedge rst_n) begin
        if (!rst_n) begin
            echo_buffer <= 8'h00;
            echo_pending <= 1'b0;
            tx_data <= 8'h00;
            tx_data_ready <= 1'b0;
            tx_busy_reg <= 1'b0;
        end else begin
            // Default values
            tx_data_ready <= 1'b0;
            
            // When new data is received, store it for echo
            if (rx_done && !echo_pending) begin
                echo_buffer <= rx_data*2;
                echo_pending <= 1'b1;
            end
            
            // When we have data to echo and TX is not busy, send it
            if (echo_pending) begin
                tx_data <= echo_buffer;
                tx_data_ready <= 1'b1;
                echo_pending <= 1'b0;
                tx_busy_reg <= 1'b1;
            end
            
            // Clear busy flag after some time (simple timeout)
            // Note: This is a simple implementation. Better would be to have
            // a proper busy signal from uart_tx
//            if (tx_busy_reg && tx_data_ready) begin
//                tx_busy_reg <= 1'b0;
//            end
        end
    end
    // Echo logic - automatically echo back received data
//    always @(posedge clk or negedge rst_n) begin
//        if (!rst_n) begin
//            echo_buffer <= 8'h00;
//            echo_pending <= 1'b0;
//            tx_data <= 8'h00;
//            tx_data_ready <= 1'b0;
//            tx_busy_reg <= 1'b0;
//        end else begin
             //Default values
//            tx_data_ready <= 1'b0;
//            
            // When new data is received, store it for echo
//            if (rx_done && !echo_pending) begin
//                echo_buffer <= rx_data*2;
//                echo_pending <= 1'b1;
//            end
//            
             //When we have data to echo and TX is not busy, send it
//            if (echo_pending) begin
//                tx_data <= echo_buffer;
//                tx_data_ready <= 1'b1;
//                echo_pending <= 1'b0;
//                tx_busy_reg <= 1'b1;
//            end
//            
            
//            if (tx_busy_reg && tx_data_ready) begin
//                tx_busy_reg <= 1'b0;
//            end
//        end
//    end

endmodule