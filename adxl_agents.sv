//==============================================================================
// adxl_agents.sv : ctrl_agent, spi_slave_agent
//  (`include'd inside package adxl_pkg - do not compile on its own)
//==============================================================================
  class ctrl_agent extends uvm_agent;
    `uvm_component_utils(ctrl_agent)

    ctrl_sequencer sqr;
    ctrl_driver    drv;
    ctrl_monitor   mon;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      mon = ctrl_monitor::type_id::create("mon", this);
      if (get_is_active() == UVM_ACTIVE) begin
        sqr = ctrl_sequencer::type_id::create("sqr", this);
        drv = ctrl_driver::type_id::create("drv", this);
      end
    endfunction

    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      if (get_is_active() == UVM_ACTIVE) begin
        drv.seq_item_port.connect(sqr.seq_item_export);
      end
    endfunction
  endclass : ctrl_agent

  class spi_slave_agent extends uvm_agent;
    `uvm_component_utils(spi_slave_agent)

    spi_sequencer    sqr;
    spi_slave_driver drv;
    spi_monitor      mon;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      mon = spi_monitor::type_id::create("mon", this);
      if (get_is_active() == UVM_ACTIVE) begin
        sqr = spi_sequencer::type_id::create("sqr", this);
        drv = spi_slave_driver::type_id::create("drv", this);
      end
    endfunction

    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      if (get_is_active() == UVM_ACTIVE) begin
        drv.seq_item_port.connect(sqr.seq_item_export);
      end
    endfunction
  endclass : spi_slave_agent
