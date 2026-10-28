//==============================================================================
// adxl_scoreboard.sv : scoreboard
//  (`include'd inside package adxl_pkg - do not compile on its own)
//==============================================================================
  class adxl_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(adxl_scoreboard)

    uvm_analysis_imp_frame  #(spi_frame_item, adxl_scoreboard) frame_export;
    uvm_analysis_imp_result #(result_item,    adxl_scoreboard) result_export;

    result_item  exp_q[$];      // predicted results (built from the SPI bus)
    result_item  act_q[$];      // results the DUT actually produced
    bit          expect_read;   // a wake-up write was seen, read must follow

    int unsigned n_write_frames, n_read_frames, n_checked, n_mismatch;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      frame_export  = new("frame_export",  this);
      result_export = new("result_export", this);
    endfunction

    // ---- input 1 : SPI frames from spi_monitor ------------------------------
    function void write_frame(spi_frame_item f);
      logic [7:0] cmd;
      if (f.mosi_bytes.size() == 0) begin
        `uvm_error("SB_FRAME", "Chip select toggled without any clock pulses")
        return;
      end
      cmd = f.mosi_bytes[0];
      if (cmd[7] === 1'b0) check_write_frame(f);
      else                 check_read_frame(f);
    endfunction

    function void check_write_frame(spi_frame_item f);
      n_write_frames++;
      if (expect_read) begin
        `uvm_error("SB_ORDER", "Two wake-up write frames in a row (read frame missing)")
      end
      expect_read = 1'b1;

      if (f.mosi_bytes.size() != WRITE_FRAME_BYTES) begin
        `uvm_error("SB_WRITE", $sformatf("Write frame must have %0d bytes: %s",
                                         WRITE_FRAME_BYTES, f.convert2string()))
      end else begin
        if (f.mosi_bytes[0] !== CMD_WRITE_POWER_CTL) begin
          `uvm_error("SB_WRITE", $sformatf("Wrong write command 0x%02h (exp 0x%02h)",
                                           f.mosi_bytes[0], CMD_WRITE_POWER_CTL))
        end
        if (f.mosi_bytes[1] !== VAL_MEASURE) begin
          `uvm_error("SB_WRITE", $sformatf("Wrong POWER_CTL value 0x%02h (exp 0x%02h)",
                                           f.mosi_bytes[1], VAL_MEASURE))
        end
      end
    endfunction

    function void check_read_frame(spi_frame_item f);
      result_item exp;
      n_read_frames++;
      if (!expect_read) begin
        `uvm_error("SB_ORDER", "Read frame without a preceding wake-up write frame")
      end
      expect_read = 1'b0;

      if (f.mosi_bytes.size() != READ_FRAME_BYTES) begin
        `uvm_error("SB_READ", $sformatf("Read frame must have %0d bytes: %s",
                                        READ_FRAME_BYTES, f.convert2string()))
        return;
      end
      if (f.mosi_bytes[0] !== CMD_READ_BURST) begin
        `uvm_error("SB_READ", $sformatf("Wrong read command 0x%02h (exp 0x%02h)",
                                        f.mosi_bytes[0], CMD_READ_BURST))
      end
      for (int i = 1; i < READ_FRAME_BYTES; i++) begin
        if (f.mosi_bytes[i] !== 8'h00) begin
          `uvm_error("SB_READ", $sformatf("Dummy byte %0d should be 0x00, got 0x%02h", i, f.mosi_bytes[i]))
        end
      end

      // Reference model: ADXL345 data registers are little-endian pairs.
      //   byte1=X0 byte2=X1 byte3=Y0 byte4=Y1 byte5=Z0 byte6=Z1
      exp   = result_item::type_id::create("exp");
      exp.x = {f.miso_bytes[2], f.miso_bytes[1]};
      exp.y = {f.miso_bytes[4], f.miso_bytes[3]};
      exp.z = {f.miso_bytes[6], f.miso_bytes[5]};
      exp_q.push_back(exp);
      try_compare();
    endfunction

    // ---- input 2 : DUT results from ctrl_monitor ----------------------------
    function void write_result(result_item r);
      act_q.push_back(r);
      try_compare();
    endfunction

    // ---- compare whenever both an expected and an actual item are waiting ---
    function void try_compare();
      result_item e, a;
      while (exp_q.size() > 0 && act_q.size() > 0) begin
        e = exp_q.pop_front();
        a = act_q.pop_front();
        n_checked++;
        if (a.x === e.x && a.y === e.y && a.z === e.z) begin
          `uvm_info("SB", $sformatf("PASS  exp: %s | act: %s", e.convert2string(), a.convert2string()), UVM_LOW)
        end else begin
          n_mismatch++;
          `uvm_error("SB", $sformatf("MISMATCH  exp: %s | act: %s", e.convert2string(), a.convert2string()))
        end
      end
    endfunction

    // ---- end-of-test checks --------------------------------------------------
    function void check_phase(uvm_phase phase);
      super.check_phase(phase);
      if (expect_read) begin
        `uvm_error("SB_END", "Wake-up write frame was never followed by a read frame")
      end
      if (exp_q.size() != 0) begin
        `uvm_error("SB_END", $sformatf("%0d read frame(s) never produced a data_valid", exp_q.size()))
      end
      if (act_q.size() != 0) begin
        `uvm_error("SB_END", $sformatf("%0d data_valid pulse(s) without a matching read frame", act_q.size()))
      end
    endfunction

    function void report_phase(uvm_phase phase);
      super.report_phase(phase);
      `uvm_info("SB", $sformatf("Summary: write frames=%0d read frames=%0d results checked=%0d mismatches=%0d",
                                n_write_frames, n_read_frames, n_checked, n_mismatch), UVM_NONE)
    endfunction
  endclass : adxl_scoreboard
