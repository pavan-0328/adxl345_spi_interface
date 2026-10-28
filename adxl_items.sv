//==============================================================================
// adxl_items.sv : transaction items + sequencer typedefs
//  (`include'd inside package adxl_pkg - do not compile on its own)
//==============================================================================
  class ctrl_item extends uvm_sequence_item;
    rand int unsigned gap_cycles;     // idle clocks before the start pulse
    rand int unsigned pulse_cycles;   // clocks that 'start' stays high

    constraint c_gap   { gap_cycles   inside {[0:20]}; }
    constraint c_pulse { pulse_cycles inside {[1:3]};  }

    `uvm_object_utils(ctrl_item)

    function new(string name = "ctrl_item");
      super.new(name);
    endfunction

    virtual function string convert2string();
      return $sformatf("gap=%0d clk, start pulse=%0d clk", gap_cycles, pulse_cycles);
    endfunction
  endclass : ctrl_item

  // --- sensor_item : what the (virtual) ADXL345 will report -------------------
  class sensor_item extends uvm_sequence_item;
    rand bit [15:0] x, y, z;

    // ~25 % of the values are corner cases, the rest uniformly random
    constraint c_x { x dist { 16'h0000 := 2, 16'h7FFF := 2, 16'h8000 := 2, 16'hFFFF := 2,
                              [16'h0001:16'h7FFE] :/ 12, [16'h8001:16'hFFFE] :/ 12 }; }
    constraint c_y { y dist { 16'h0000 := 2, 16'h7FFF := 2, 16'h8000 := 2, 16'hFFFF := 2,
                              [16'h0001:16'h7FFE] :/ 12, [16'h8001:16'hFFFE] :/ 12 }; }
    constraint c_z { z dist { 16'h0000 := 2, 16'h7FFF := 2, 16'h8000 := 2, 16'hFFFF := 2,
                              [16'h0001:16'h7FFE] :/ 12, [16'h8001:16'hFFFE] :/ 12 }; }

    `uvm_object_utils(sensor_item)

    function new(string name = "sensor_item");
      super.new(name);
    endfunction

    virtual function string convert2string();
      return $sformatf("X=0x%04h Y=0x%04h Z=0x%04h", x, y, z);
    endfunction
  endclass : sensor_item

  // --- result_item : what the DUT presented on accel_x/y/z with data_valid ---
  class result_item extends uvm_sequence_item;
    logic [15:0] x, y, z;             // 4-state on purpose: X/Z must not be hidden

    `uvm_object_utils(result_item)

    function new(string name = "result_item");
      super.new(name);
    endfunction

    virtual function string convert2string();
      return $sformatf("X=0x%04h Y=0x%04h Z=0x%04h", x, y, z);
    endfunction
  endclass : result_item

  // --- spi_frame_item : one complete chip-select-low period on the SPI bus ----
  class spi_frame_item extends uvm_sequence_item;
    logic [7:0] mosi_bytes[$];        // bytes the DUT sent
    logic [7:0] miso_bytes[$];        // bytes the sensor sent

    `uvm_object_utils(spi_frame_item)

    function new(string name = "spi_frame_item");
      super.new(name);
    endfunction

    virtual function string convert2string();
      string s;
      s = "MOSI:";
      foreach (mosi_bytes[i]) s = {s, $sformatf(" %02h", mosi_bytes[i])};
      s = {s, "  |  MISO:"};
      foreach (miso_bytes[i]) s = {s, $sformatf(" %02h", miso_bytes[i])};
      return s;
    endfunction
  endclass : spi_frame_item

  typedef uvm_sequencer #(ctrl_item)   ctrl_sequencer;
  typedef uvm_sequencer #(sensor_item) spi_sequencer;
