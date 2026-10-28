//==============================================================================
// adxl_drivers.sv : ctrl_driver, spi_slave_driver
//  (`include'd inside package adxl_pkg - do not compile on its own)
//==============================================================================
  class ctrl_driver extends uvm_driver #(ctrl_item);
    `uvm_component_utils(ctrl_driver)

    virtual adxl_if vif;
    int unsigned    timeout_cycles = 5000;   // one measurement takes ~650 clocks

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual adxl_if)::get(this, "", "vif", vif)) begin
        `uvm_fatal("NOVIF", {"Virtual interface not set for ", get_full_name()})
      end
    endfunction

    task run_phase(uvm_phase phase);
      wait (vif.reset_n === 1'b1);
      repeat (2) @(vif.drv_cb);
      forever begin
        seq_item_port.get_next_item(req);
        drive_one(req);
        seq_item_port.item_done();
      end
    endtask

    task drive_one(ctrl_item t);
      int unsigned cycles;
      bit          got_valid;

      `uvm_info("CTRL_DRV", {"Driving: ", t.convert2string()}, UVM_MEDIUM)

      repeat (t.gap_cycles) @(vif.drv_cb);

      vif.drv_cb.start <= 1'b1;
      repeat (t.pulse_cycles) @(vif.drv_cb);
      vif.drv_cb.start <= 1'b0;

      // wait for the DUT to finish (data_valid) or time out
      cycles    = 0;
      got_valid = 1'b0;
      while (!got_valid && cycles < timeout_cycles) begin
        @(vif.mon_cb);
        cycles++;
        got_valid = (vif.mon_cb.data_valid === 1'b1);
      end

      if (!got_valid) begin
        `uvm_error("TIMEOUT", $sformatf("data_valid not seen within %0d clocks", timeout_cycles))
      end else begin
        `uvm_info("CTRL_DRV", $sformatf("data_valid seen %0d clocks after start", cycles), UVM_HIGH)
      end
    endtask
  endclass : ctrl_driver

  // --- spi_slave_driver : behavioural ADXL345 (SPI mode 3, MSB first) --------
  class spi_slave_driver extends uvm_driver #(sensor_item);
    `uvm_component_utils(spi_slave_driver)

    virtual adxl_if vif;
    bit [7:0]       regs [64];          // 6-bit register address space

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual adxl_if)::get(this, "", "vif", vif)) begin
        `uvm_fatal("NOVIF", {"Virtual interface not set for ", get_full_name()})
      end
    endfunction

    task run_phase(uvm_phase phase);
      foreach (regs[i]) regs[i] = 8'h00;
      regs[REG_DEVID] = 8'hE5;           // ADXL345 device ID
      wait (vif.reset_n === 1'b1);
      fork
        sensor_loader();                 // thread 1 : sequencer -> register file
        spi_responder();                 // thread 2 : answers the DUT on the bus
      join
    endtask

    // Thread 1 : copy each sensor_item into the DATAx registers
    task sensor_loader();
      forever begin
        seq_item_port.get_next_item(req);
        regs[REG_DATAX0] = req.x[7:0];
        regs[REG_DATAX1] = req.x[15:8];
        regs[REG_DATAY0] = req.y[7:0];
        regs[REG_DATAY1] = req.y[15:8];
        regs[REG_DATAZ0] = req.z[7:0];
        regs[REG_DATAZ1] = req.z[15:8];
        `uvm_info("SENSOR", {"Sensor now holds: ", req.convert2string()}, UVM_MEDIUM)
        seq_item_port.item_done();
      end
    endtask

    // Thread 2 : one iteration per chip-select frame
    task spi_responder();
      forever begin
        @(negedge vif.cs_n);
        serve_frame();
        vif.miso = 1'b0;                 // "release" the line after the frame
      end
    endtask

    // Mode 3: sclk idles high.
    //   - slave drives MISO on the FALLING edge of sclk
    //   - slave samples MOSI on the RISING  edge of sclk
    // Returns as soon as cs_n goes high.
    task serve_frame();
      int unsigned byte_idx;
      bit          is_read;
      bit          is_multi;
      bit [5:0]    addr;
      bit [7:0]    tx_byte;
      bit [7:0]    rx_byte;

      byte_idx = 0;
      is_read  = 1'b0;
      is_multi = 1'b0;
      addr     = 6'h00;

      forever begin
        // byte 0 is the command byte; afterwards, a read returns regs[addr]
        if (byte_idx > 0 && is_read) tx_byte = regs[addr];
        else                         tx_byte = 8'h00;

        for (int b = 7; b >= 0; b--) begin
          @(negedge vif.sclk or posedge vif.cs_n);
          if (vif.cs_n === 1'b1) return;
          vif.miso = tx_byte[b];

          @(posedge vif.sclk or posedge vif.cs_n);
          if (vif.cs_n === 1'b1) return;
          rx_byte[b] = vif.mosi;
        end

        if (byte_idx == 0) begin
          is_read  = rx_byte[7];
          is_multi = rx_byte[6];
          addr     = rx_byte[5:0];
        end else begin
          if (!is_read) begin
            regs[addr] = rx_byte;
            `uvm_info("SENSOR", $sformatf("Register write: reg[0x%02h] = 0x%02h", addr, rx_byte), UVM_HIGH)
          end
          if (is_multi) addr = addr + 6'd1;
        end
        byte_idx++;
      end
    endtask
  endclass : spi_slave_driver
