module adxl345_controller (
    input wire clk,
    input wire reset_n,
    input wire start,           // Pulse high to trigger the sequence
    input wire miso,
    output wire mosi,
    output wire sclk,
    output wire cs_n,
    output reg [15:0] accel_x,
    output reg [15:0] accel_y,
    output reg [15:0] accel_z,
    output reg data_valid       // Pulses high when X, Y, Z are fully updated
);

    // Signals to command your spi_master
    reg spi_start, spi_cs_hold;
    reg [7:0] spi_tx_data;
    wire [7:0] spi_rx_data;
    wire spi_busy, spi_done;

    // Instantiate your SPI Master
    spi_master #(.CLK_DIV(4)) u_spi (
        .clk(clk),
        .reset_n(reset_n),
        .start(spi_start),
        .cs_hold(spi_cs_hold),
        .tx_data(spi_tx_data),
        .MISO(miso),
        .MOSI(mosi),
        .sclk(sclk),
        .cs_n(cs_n),
        .rx_data(spi_rx_data),
        .busy(spi_busy),
        .done(spi_done)
    );

    // Simple Linear FSM
    reg [3:0] state;
    reg [7:0] buf_x0, buf_x1, buf_y0, buf_y1, buf_z0;

    localparam S_IDLE     = 0;
    localparam S_WAKE_CMD = 1;
    localparam S_WAKE_DAT = 2;
    localparam S_READ_CMD = 3;
    localparam S_READ_X0  = 4;
    localparam S_READ_X1  = 5;
    localparam S_READ_Y0  = 6;
    localparam S_READ_Y1  = 7;
    localparam S_READ_Z0  = 8;
    localparam S_READ_Z1  = 9;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= S_IDLE;
            spi_start <= 0;
            spi_cs_hold <= 0;
            spi_tx_data <= 0;
            data_valid <= 0;
            accel_x <= 0; accel_y <= 0; accel_z <= 0;
        end else begin
            spi_start <= 0; // Default to pulsing start
            data_valid <= 0;

            case (state)
                S_IDLE: begin
                    if (start && !spi_busy) begin
                        spi_tx_data <= 8'h2D; // ADXL345 POWER_CTL Register
                        spi_cs_hold <= 1'b1;  // Keep CS_N low for the data byte
                        spi_start   <= 1'b1;
                        state       <= S_WAKE_CMD;
                    end
                end
                
                S_WAKE_CMD: begin
                    if (spi_done) begin
                        spi_tx_data <= 8'h08; // Set the 'Measure' bit to wake sensor
                        spi_cs_hold <= 1'b0;  // Release CS_N after this byte
                        spi_start   <= 1'b1;
                        state       <= S_WAKE_DAT;
                    end
                end
                
                S_WAKE_DAT: begin
                    if (spi_done) begin
                        // 0x80 (Read) | 0x40 (Multi-Byte) | 0x32 (DATAX0 Address) = 0xF2
                        spi_tx_data <= 8'hF2; 
                        spi_cs_hold <= 1'b1;  // Hold CS_N low to chain 6 data bytes
                        spi_start   <= 1'b1;
                        state       <= S_READ_CMD;
                    end
                end
                
                S_READ_CMD: begin
                    if (spi_done) begin
                        spi_tx_data <= 8'h00; // Dummy byte to clock out X0
                        spi_cs_hold <= 1'b1;
                        spi_start   <= 1'b1;
                        state       <= S_READ_X0;
                    end
                end
                
                S_READ_X0: begin
                    if (spi_done) begin
                        buf_x0      <= spi_rx_data; // Store X0
                        spi_tx_data <= 8'h00;       // Dummy byte to clock out X1
                        spi_cs_hold <= 1'b1;
                        spi_start   <= 1'b1;
                        state       <= S_READ_X1;
                    end
                end
                
                S_READ_X1: begin
                    if (spi_done) begin
                        buf_x1      <= spi_rx_data;
                        spi_tx_data <= 8'h00;
                        spi_cs_hold <= 1'b1;
                        spi_start   <= 1'b1;
                        state       <= S_READ_Y0;
                    end
                end
                
                S_READ_Y0: begin
                    if (spi_done) begin
                        buf_y0      <= spi_rx_data;
                        spi_tx_data <= 8'h00;
                        spi_cs_hold <= 1'b1;
                        spi_start   <= 1'b1;
                        state       <= S_READ_Y1;
                    end
                end
                
                S_READ_Y1: begin
                    if (spi_done) begin
                        buf_y1      <= spi_rx_data;
                        spi_tx_data <= 8'h00;
                        spi_cs_hold <= 1'b1;
                        spi_start   <= 1'b1;
                        state       <= S_READ_Z0;
                    end
                end
                
                S_READ_Z0: begin
                    if (spi_done) begin
                        buf_z0      <= spi_rx_data;
                        spi_tx_data <= 8'h00;
                        spi_cs_hold <= 1'b0;  // RELEASE CS_N AFTER Z1 IS DONE!
                        spi_start   <= 1'b1;
                        state       <= S_READ_Z1;
                    end
                end
                
                S_READ_Z1: begin
                    if (spi_done) begin
                        // Assemble the 16-bit registers (High Byte + Low Byte)
                        accel_z <= {spi_rx_data, buf_z0};
                        accel_y <= {buf_y1, buf_y0};
                        accel_x <= {buf_x1, buf_x0};
                        data_valid <= 1'b1;
                        state <= S_IDLE; // Process complete
                    end
                end
            endcase
        end
    end
endmodule
