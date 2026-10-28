//==============================================================================
// testbench.sv : TOP FILE (clock, reset, DUT, interface, start UVM)
// Extra files (add with the "+" button in EDA Playground, same names):
//   adxl_if.sv adxl_pkg.sv adxl_defs.sv adxl_items.sv adxl_sequences.sv
//   adxl_drivers.sv adxl_monitors.sv adxl_agents.sv adxl_scoreboard.sv
//   adxl_env.sv adxl_tests.sv
// Simulator: Questa / VCS / Xcelium, UVM 1.2.
//==============================================================================
`timescale 1ns/1ps
`include "uvm_macros.svh"

`include "adxl_if.sv"
`include "adxl_pkg.sv"

module tb_top;

  import uvm_pkg::*;
  import adxl_pkg::*;

  logic clk;
  logic reset_n;

  // 100 MHz clock  (period 10 ns)
  initial clk = 1'b0;
  always #5 clk = ~clk;

  // Active-low reset, released between two clock edges
  initial begin
    reset_n = 1'b0;
    #52;
    reset_n = 1'b1;
  end

  adxl_if vif (.clk(clk), .reset_n(reset_n));

  adxl345_controller dut (
    .clk        (clk),
    .reset_n    (reset_n),
    .start      (vif.start),
    .miso       (vif.miso),
    .mosi       (vif.mosi),
    .sclk       (vif.sclk),
    .cs_n       (vif.cs_n),
    .accel_x    (vif.accel_x),
    .accel_y    (vif.accel_y),
    .accel_z    (vif.accel_z),
    .data_valid (vif.data_valid)
  );

  initial begin
    uvm_config_db#(virtual adxl_if)::set(null, "*", "vif", vif);
    run_test("adxl_full_test");     // +UVM_TESTNAME=... on the command line overrides this
  end

  // Waveforms for EPWave
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, tb_top);
  end

endmodule : tb_top
