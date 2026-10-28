//==============================================================================
// adxl_sequences.sv : sub-sequences, virtual sequencer, virtual sequences
//  (`include'd inside package adxl_pkg - do not compile on its own)
//==============================================================================
  class sensor_seq extends uvm_sequence #(sensor_item);
    `uvm_object_utils(sensor_seq)

    bit        use_fixed;
    bit [15:0] fx, fy, fz;

    function new(string name = "sensor_seq");
      super.new(name);
    endfunction

    task body();
      req = sensor_item::type_id::create("req");
      start_item(req);
      if (use_fixed) begin
        req.x = fx;  req.y = fy;  req.z = fz;
      end else begin
        if (!req.randomize()) begin
          `uvm_fatal("RANDFAIL", "sensor_item randomization failed")
        end
      end
      finish_item(req);
    endtask
  endclass : sensor_seq

  // --- ctrl_seq : sends ONE ctrl_item (random gap / pulse width) -------------
  class ctrl_seq extends uvm_sequence #(ctrl_item);
    `uvm_object_utils(ctrl_seq)

    function new(string name = "ctrl_seq");
      super.new(name);
    endfunction

    task body();
      req = ctrl_item::type_id::create("req");
      start_item(req);
      if (!req.randomize()) begin
        `uvm_fatal("RANDFAIL", "ctrl_item randomization failed")
      end
      finish_item(req);
    endtask
  endclass : ctrl_seq

  //----------------------------------------------------------------------------
  // 2.4  VIRTUAL SEQUENCER + VIRTUAL SEQUENCES (coordinate both agents)
  //----------------------------------------------------------------------------
  class adxl_vseqr extends uvm_sequencer;
    `uvm_component_utils(adxl_vseqr)

    spi_sequencer  spi_sqr;     // handles are filled in by the env (connect_phase)
    ctrl_sequencer ctrl_sqr;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
  endclass : adxl_vseqr

  class adxl_base_vseq extends uvm_sequence;
    `uvm_object_utils(adxl_base_vseq)
    `uvm_declare_p_sequencer(adxl_vseqr)

    function new(string name = "adxl_base_vseq");
      super.new(name);
    endfunction

    // ONE complete measurement:
    //   1) program the sensor registers   2) pulse 'start' and wait for data_valid
    task measure(bit use_fixed = 1'b0,
                 bit [15:0] x = 16'h0, bit [15:0] y = 16'h0, bit [15:0] z = 16'h0);
      sensor_seq s;
      ctrl_seq   c;
      s = sensor_seq::type_id::create("s");
      c = ctrl_seq::type_id::create("c");
      s.use_fixed = use_fixed;
      s.fx = x;  s.fy = y;  s.fz = z;
      s.start(p_sequencer.spi_sqr,  this);
      c.start(p_sequencer.ctrl_sqr, this);
    endtask
  endclass : adxl_base_vseq

  class adxl_directed_vseq extends adxl_base_vseq;
    `uvm_object_utils(adxl_directed_vseq)

    function new(string name = "adxl_directed_vseq");
      super.new(name);
    endfunction

    task body();
      `uvm_info("VSEQ", "Directed corner-case measurements", UVM_LOW)
      measure(1'b1, 16'h0000, 16'h0000, 16'h0000);
      measure(1'b1, 16'hFFFF, 16'hFFFF, 16'hFFFF);
      measure(1'b1, 16'h8000, 16'h7FFF, 16'h0001);
      measure(1'b1, 16'h1234, 16'h5678, 16'h9ABC);
      measure(1'b1, 16'hAAAA, 16'h5555, 16'hF00F);
    endtask
  endclass : adxl_directed_vseq

  class adxl_random_vseq extends adxl_base_vseq;
    `uvm_object_utils(adxl_random_vseq)

    int unsigned num_txn = 20;

    function new(string name = "adxl_random_vseq");
      super.new(name);
    endfunction

    task body();
      `uvm_info("VSEQ", $sformatf("%0d random measurements", num_txn), UVM_LOW)
      repeat (num_txn) measure();
    endtask
  endclass : adxl_random_vseq
