//==============================================================================
// adxl_env.sv : environment
//  (`include'd inside package adxl_pkg - do not compile on its own)
//==============================================================================
  class adxl_env extends uvm_env;
    `uvm_component_utils(adxl_env)

    ctrl_agent      ctrl_agt;
    spi_slave_agent spi_agt;
    adxl_scoreboard sb;
    adxl_vseqr      vseqr;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      ctrl_agt = ctrl_agent::type_id::create("ctrl_agt", this);
      spi_agt  = spi_slave_agent::type_id::create("spi_agt", this);
      sb       = adxl_scoreboard::type_id::create("sb", this);
      vseqr    = adxl_vseqr::type_id::create("vseqr", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      // monitors -> scoreboard
      ctrl_agt.mon.ap.connect(sb.result_export);
      spi_agt.mon.ap.connect(sb.frame_export);
      // virtual sequencer -> real sequencers
      vseqr.ctrl_sqr = ctrl_agt.sqr;
      vseqr.spi_sqr  = spi_agt.sqr;
    endfunction
  endclass : adxl_env
