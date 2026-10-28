//==============================================================================
// adxl_monitors.sv : ctrl_monitor, spi_monitor
//  (`include'd inside package adxl_pkg - do not compile on its own)
//==============================================================================
  class ctrl_monitor extends uvm_monitor;
    `uvm_component_utils(ctrl_monitor)

    virtual adxl_if                 vif;
    uvm_analysis_port #(result_item) ap;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      ap = new("ap", this);
      if (!uvm_config_db#(virtual adxl_if)::get(this, "", "vif", vif)) begin
        `uvm_fatal("NOVIF", {"Virtual interface not set for ", get_full_name()})
      end
    endfunction

    task run_phase(uvm_phase phase);
      result_item r;
      wait (vif.reset_n === 1'b1);
      forever begin
        @(vif.mon_cb);
        if (vif.mon_cb.data_valid === 1'b1) begin
          r = result_item::type_id::create("r");
          r.x = vif.mon_cb.accel_x;
          r.y = vif.mon_cb.accel_y;
          r.z = vif.mon_cb.accel_z;
          `uvm_info("CTRL_MON", {"DUT result: ", r.convert2string()}, UVM_MEDIUM)
          ap.write(r);
        end
      end
    endtask
  endclass : ctrl_monitor

  // --- spi_monitor : rebuilds SPI frames from the raw sclk/mosi/miso/cs_n -----
  class spi_monitor extends uvm_monitor;
    `uvm_component_utils(spi_monitor)

    virtual adxl_if                     vif;
    uvm_analysis_port #(spi_frame_item) ap;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      ap = new("ap", this);
      if (!uvm_config_db#(virtual adxl_if)::get(this, "", "vif", vif)) begin
        `uvm_fatal("NOVIF", {"Virtual interface not set for ", get_full_name()})
      end
    endfunction

    task run_phase(uvm_phase phase);
      wait (vif.reset_n === 1'b1);
      forever begin
        @(negedge vif.cs_n);
        collect_frame();
      end
    endtask

    task collect_frame();
      spi_frame_item f;
      logic [7:0]    mosi_sh, miso_sh;
      int unsigned   bit_cnt;

      f       = spi_frame_item::type_id::create("f");
      mosi_sh = 8'h00;
      miso_sh = 8'h00;
      bit_cnt = 0;

      forever begin
        @(posedge vif.sclk or posedge vif.cs_n);
        if (vif.cs_n === 1'b1) break;          // frame finished

        mosi_sh = {mosi_sh[6:0], vif.mosi};    // sample on rising edge (mode 3)
        miso_sh = {miso_sh[6:0], vif.miso};
        bit_cnt++;

        if (bit_cnt == 8) begin
          f.mosi_bytes.push_back(mosi_sh);
          f.miso_bytes.push_back(miso_sh);
          bit_cnt = 0;
        end
      end

      if (bit_cnt != 0) begin
        `uvm_error("SPI_MON", $sformatf("cs_n rose in the middle of a byte (%0d bits seen)", bit_cnt))
      end

      `uvm_info("SPI_MON", {"Frame: ", f.convert2string()}, UVM_MEDIUM)
      ap.write(f);
    endtask
  endclass : spi_monitor
