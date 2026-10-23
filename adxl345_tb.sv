`timescale 1ns/1ps

module adxl345_vector_tb;
    // Original 100 MHz System Clock (10ns period)
    reg clk = 0;
    always #5 clk = ~clk; 

    reg reset_n = 0;
    reg start = 0;
    
    wire mosi, sclk, cs_n;
    wire [15:0] accel_x, accel_y, accel_z;
    wire data_valid;
    reg miso = 0;

    // Instantiate Parent Controller using its default CLK_DIV
    adxl345_controller uut (
        .clk(clk), .reset_n(reset_n), .start(start),
        .miso(miso), .mosi(mosi), .sclk(sclk), .cs_n(cs_n),
        .accel_x(accel_x), .accel_y(accel_y), .accel_z(accel_z),
        .data_valid(data_valid)
    );

    reg [7:0] mock_ram [0:7];
    integer bit_cnt = 8;
    integer byte_cnt = 0;

    // Slave emulation: Mode 3 data shifting
    always @(negedge cs_n) begin
        bit_cnt = 8;
        byte_cnt = 0;
    end
    
    always @(negedge sclk) begin
        if (bit_cnt == 0) begin
            bit_cnt = 7;
            byte_cnt = byte_cnt + 1;
        end else begin
            bit_cnt = bit_cnt - 1;
        end
        miso = mock_ram[byte_cnt][bit_cnt];
    end

    // Test Vector Variables
    integer i, errors;
    reg [15:0] expected_x, expected_y, expected_z;
    
    // G-Force Calculation Variables (Real numbers for testbench console output)
    real g_x, g_y, g_z;
    real scale_factor = 0.004; // ADXL345 standard resolution is 4 mg/LSB

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, adxl345_vector_tb);
        
        errors = 0;
        mock_ram[0] = 8'h00; 
        mock_ram[7] = 8'h00;

        #100 reset_n = 1;
        #100;

        $display("==================================================");
        $display("   STARTING 50-VECTOR ADXL345 TELEMETRY TEST");
        $display("==================================================");

        for (i = 1; i <= 50; i = i + 1) begin
            // 1. Generate random 16-bit 2's complement kinematic values
            expected_x = $random;
            expected_y = $random;
            expected_z = $random;

            // 2. Load into simulated slave memory (Little Endian: Low Byte first)
            mock_ram[1] = expected_x[7:0];   mock_ram[2] = expected_x[15:8];
            mock_ram[3] = expected_y[7:0];   mock_ram[4] = expected_y[15:8];
            mock_ram[5] = expected_z[7:0];   mock_ram[6] = expected_z[15:8];

            // 3. Trigger the SPI Master FSM
            @(posedge clk);
            start = 1;
            @(posedge clk);
            start = 0;

            // 4. Wait for the multi-byte burst read to finish
            wait(data_valid == 1);
            
            // 5. Calculate physical G-forces (Handle 2's complement signed conversion)
            g_x = $signed(accel_x) * scale_factor;
            g_y = $signed(accel_y) * scale_factor;
            g_z = $signed(accel_z) * scale_factor;

            // 6. Verify hardware structural logic
            if (accel_x !== expected_x || accel_y !== expected_y || accel_z !== expected_z) begin
                $display("[FAIL] Vector %0d: Expected X:%h Y:%h Z:%h | Got X:%h Y:%h Z:%h", 
                         i, expected_x, expected_y, expected_z, accel_x, accel_y, accel_z);
                errors = errors + 1;
            end else if (i % 10 == 0) begin
                // Log a sample trace every 10 vectors
                $display("[PASS] Vector %0d | X: %7.2f g | Y: %7.2f g | Z: %7.2f g", i, g_x, g_y, g_z);
            end

            #500; // Delay before initiating the next burst read
        end

        $display("==================================================");
        if (errors == 0)
            $display("TEST COMPLETE: 50/50 Vectors Passed successfully.");
        else
            $display("TEST FAILED: %0d Errors Detected.", errors);
        $display("==================================================");
        
        $finish;
    end
endmodule