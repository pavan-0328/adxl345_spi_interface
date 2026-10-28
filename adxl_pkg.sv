//==============================================================================
// adxl_pkg.sv : package that gathers every UVM class (`include'd from testbench.sv)
// ORDER MATTERS: each file only uses classes defined in files above it.
//==============================================================================
package adxl_pkg;

  import uvm_pkg::*;

  // Lets ONE scoreboard own TWO analysis inputs: write_frame() / write_result()
  `uvm_analysis_imp_decl(_frame)
  `uvm_analysis_imp_decl(_result)

  `include "adxl_defs.sv"
  `include "adxl_items.sv"
  `include "adxl_sequences.sv"
  `include "adxl_drivers.sv"
  `include "adxl_monitors.sv"
  `include "adxl_agents.sv"
  `include "adxl_scoreboard.sv"
  `include "adxl_env.sv"
  `include "adxl_tests.sv"

endpackage : adxl_pkg
