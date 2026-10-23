`timescale 1ns/1ps

module adxl345_tb;
    reg clk = 0;
    always #5 clk = ~clk;

    reg reset_n = 0;
    reg start = 0;
    
    wire mosi, sclk, cs_n;
    wire [15:0] accel_x, accel_y, accel_z;
    wire data_valid;
    reg miso = 0;

    // Instantiate Parent Controller
    adxl345_controller uut (
        .clk(clk), .reset_n(reset_n), .start(start),
        .miso(miso), .mosi(mosi), .sclk(sclk), .cs_n(cs_n),
        .accel_x(accel_x), .accel_y(accel_y), .accel_z(accel_z),
        .data_valid(data_valid)
    );

    // Mock ADXL345 Memory Array
    // Mock ADXL345 Memory Array
    reg [7:0] mock_ram [0:7];
    integer bit_cnt = 8; // Start at 8 so the first decrement targets bit 7
    integer byte_cnt = 0;

    initial begin
        mock_ram[0] = 8'h00; 
        mock_ram[1] = 8'h12; // X0
        mock_ram[2] = 8'h34; // X1 
        mock_ram[3] = 8'h56; // Y0
        mock_ram[4] = 8'h78; // Y1 
        mock_ram[5] = 8'h9A; // Z0
        mock_ram[6] = 8'hBC; // Z1 
        mock_ram[7] = 8'h00;
    end

    // Reset counters when Chip Select drops
    always @(negedge cs_n) begin
        bit_cnt = 8;
        byte_cnt = 0;
    end
    
    // Drive data exactly on the falling edge
    always @(negedge sclk) begin
        if (bit_cnt == 0) begin
            bit_cnt = 7;
            byte_cnt = byte_cnt + 1;
        end else begin
            bit_cnt = bit_cnt - 1;
        end
        miso = mock_ram[byte_cnt][bit_cnt];
    end

    // Main Test Stimulus
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, adxl345_tb);
        
        #20 reset_n = 1;
        
        #20 start = 1;
        #10 start = 0;

        // Wait for the FSM to finish all 9 bytes
        wait(data_valid == 1);
        #20;
        
        $display("--- ADXL345 READ COMPLETE ---");
        $display("X-Axis: %h (Expected: 3412)", accel_x);
        $display("Y-Axis: %h (Expected: 7856)", accel_y);
        $display("Z-Axis: %h (Expected: bc9a)", accel_z);
        
        if (accel_x == 16'h3412 && accel_y == 16'h7856 && accel_z == 16'hBC9A)
            $display("[PASS] Parent Controller Successfully Read Burst Data!");
        else
            $display("[FAIL] Data mismatch.");
            
        $finish;
    end
endmodule
