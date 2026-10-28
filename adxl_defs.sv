//==============================================================================
// adxl_defs.sv : ADXL345 protocol constants
//  (`include'd inside package adxl_pkg - do not compile on its own)
//==============================================================================
  localparam bit [5:0] REG_DEVID     = 6'h00;
  localparam bit [5:0] REG_POWER_CTL = 6'h2D;
  localparam bit [5:0] REG_DATAX0    = 6'h32;
  localparam bit [5:0] REG_DATAX1    = 6'h33;
  localparam bit [5:0] REG_DATAY0    = 6'h34;
  localparam bit [5:0] REG_DATAY1    = 6'h35;
  localparam bit [5:0] REG_DATAZ0    = 6'h36;
  localparam bit [5:0] REG_DATAZ1    = 6'h37;

  localparam bit [7:0] CMD_WRITE_POWER_CTL = 8'h2D; // R/W=0 MB=0 addr=0x2D
  localparam bit [7:0] VAL_MEASURE         = 8'h08; // POWER_CTL.Measure = 1
  localparam bit [7:0] CMD_READ_BURST      = 8'hF2; // R/W=1 MB=1 addr=0x32

  localparam int unsigned WRITE_FRAME_BYTES = 2;    // cmd + data
  localparam int unsigned READ_FRAME_BYTES  = 7;    // cmd + X0 X1 Y0 Y1 Z0 Z1
