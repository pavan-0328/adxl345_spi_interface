// Interface between testbench and DUT (`include'd from testbench.sv)
interface adxl_if (input logic clk, input logic reset_n);

  // ---- driven by the testbench -------------------------------------------
  logic        start = 1'b0;     // pulse: "perform one measurement"
  logic        miso  = 1'b0;     // sensor -> DUT   (driven by our sensor model)

  // ---- driven by the DUT (testbench only observes) -----------------------
  logic        mosi;
  logic        sclk;
  logic        cs_n;
  logic [15:0] accel_x;
  logic [15:0] accel_y;
  logic [15:0] accel_z;
  logic        data_valid;

  // Clocking block used to DRIVE 'start' : change 1 ns after the clock edge,
  // so the DUT never sees a race between clk and our stimulus.
  clocking drv_cb @(posedge clk);
    default input #1step output #1;
    output start;
  endclocking

  // Clocking block used to SAMPLE the DUT results : values are read as they
  // were just BEFORE the clock edge (what a flip-flop would see).
  clocking mon_cb @(posedge clk);
    default input #1step;
    input accel_x, accel_y, accel_z, data_valid;
  endclocking

endinterface : adxl_if
