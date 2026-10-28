module sclk_gen #(parameter CLK_DIV = 10)(   // CLK_DIV must be >= 2
    input      clk,
    input      reset_n,
    input      enable,        // high while bits are being clocked
    output reg sclk,
    output     rise_tick,     // 1-cycle pulse: sclk is rising now
    output     fall_tick      // 1-cycle pulse: sclk is falling now
);
    reg [$clog2(CLK_DIV)-1:0] div_cnt;
    wire tick = (div_cnt == CLK_DIV-1);

    assign rise_tick = enable & tick & ~sclk;
    assign fall_tick = enable & tick &  sclk;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            sclk    <= 1'b1;      // Mode 3: idle high
            div_cnt <= 0;
        end else if (!enable) begin
            sclk    <= 1'b1;
            div_cnt <= 0;
        end else if (tick) begin
            div_cnt <= 0;
            sclk    <= ~sclk;
        end else begin
            div_cnt <= div_cnt + 1'b1;
        end
    end
endmodule


module spi_master #(parameter CLK_DIV = 4)(
    input            clk,
    input            reset_n,
    input            start,        // pulse 1 cycle to begin (only when busy = 0)
    input            cs_hold,      // 1 = keep CS low after this byte
    input      [7:0] tx_data,
    input            MISO,
    output           MOSI,
    output           sclk,
    output reg       cs_n,
    output reg [7:0] rx_data,
    output reg       busy,
    output reg       done          // 1-cycle pulse, rx_data valid
);

    reg [7:0] tx_buffer;
    reg [7:0] rx_buffer;
    reg [3:0] bit_cnt;             // bits sampled so far (0..7)
    reg       hold_r;              // latched cs_hold
    reg       fin;                 // finishing phase: sclk stopped, waiting to release CS
    reg [$clog2(CLK_DIV)-1:0] fin_cnt;

    wire rise_tick, fall_tick;

    sclk_gen #(.CLK_DIV(CLK_DIV)) u_sclk_gen (
        .clk       (clk),
        .reset_n   (reset_n),
        .enable    (busy & ~fin),
        .sclk      (sclk),
        .rise_tick (rise_tick),
        .fall_tick (fall_tick)
    );

    assign MOSI = tx_buffer[7];

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            cs_n      <= 1'b1;
            busy      <= 1'b0;
            done      <= 1'b0;
            fin       <= 1'b0;
            fin_cnt   <= 0;
            hold_r    <= 1'b0;
            tx_buffer <= 8'h00;
            rx_buffer <= 8'h00;
            rx_data   <= 8'h00;
            bit_cnt   <= 4'd0;
        end else begin
            done <= 1'b0;                       // default

            if (!busy) begin
                if (start) begin
                    tx_buffer <= tx_data;       // MSB already on MOSI
                    hold_r    <= cs_hold;
                    cs_n      <= 1'b0;          // CS low before first sclk edge
                    busy      <= 1'b1;
                    bit_cnt   <= 4'd0;
                    fin       <= 1'b0;
                    fin_cnt   <= 0;
                end
            end else if (fin) begin
                // sclk already stopped high; wait half a period, then release CS
                if (fin_cnt == CLK_DIV-1) begin
                    fin  <= 1'b0;
                    busy <= 1'b0;
                    cs_n <= ~hold_r;            // stay low if more bytes follow
                    done <= 1'b1;
                end else begin
                    fin_cnt <= fin_cnt + 1'b1;
                end
            end else begin
                // falling edge: change MOSI (skip the first one, MSB already presented)
                if (fall_tick && bit_cnt != 4'd0)
                    tx_buffer <= {tx_buffer[6:0], 1'b0};

                // rising edge: sample MISO
                if (rise_tick) begin
                    rx_buffer <= {rx_buffer[6:0], MISO};
                    bit_cnt   <= bit_cnt + 1'b1;
                    if (bit_cnt == 4'd7) begin  // 8th sample
                        rx_data <= {rx_buffer[6:0], MISO};
                        fin     <= 1'b1;
                        fin_cnt <= 0;
                    end
                end
            end
        end
    end
endmodule
