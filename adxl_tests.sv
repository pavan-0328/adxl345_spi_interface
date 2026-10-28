//==============================================================================
// adxl_tests.sv : base, directed, random and full tests
//  (`include'd inside package adxl_pkg - do not compile on its own)
//==============================================================================
  class adxl_base_test extends uvm_test;
    `uvm_component_utils(adxl_base_test)

    adxl_env env;

    function new(string name = "adxl_base_test", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      env = adxl_env::type_id::create("env", this);
    endfunction

    function void end_of_elaboration_phase(uvm_phase phase);
      super.end_of_elaboration_phase(phase);
      uvm_top.print_topology();
    endfunction

    task run_phase(uvm_phase phase);
      phase.raise_objection(this, "test running");
      execute();
      #200ns;                              // let the last items reach the scoreboard
      phase.drop_objection(this, "test finished");
    endtask

    // derived tests override this
    virtual task execute();
    endtask

    function void report_phase(uvm_phase phase);
      uvm_report_server svr;
      super.report_phase(phase);
      svr = uvm_report_server::get_server();
      if (svr.get_severity_count(UVM_ERROR) + svr.get_severity_count(UVM_FATAL) == 0) begin
        `uvm_info("RESULT", "*** TEST PASSED ***", UVM_NONE)
      end else begin
        `uvm_info("RESULT", "*** TEST FAILED ***", UVM_NONE)
      end
    endfunction
  endclass : adxl_base_test

  class adxl_directed_test extends adxl_base_test;
    `uvm_component_utils(adxl_directed_test)

    function new(string name = "adxl_directed_test", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    task execute();
      adxl_directed_vseq vseq;
      vseq = adxl_directed_vseq::type_id::create("vseq");
      vseq.start(env.vseqr);
    endtask
  endclass : adxl_directed_test

  class adxl_random_test extends adxl_base_test;
    `uvm_component_utils(adxl_random_test)

    int unsigned num_txn = 20;

    function new(string name = "adxl_random_test", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    task execute();
      adxl_random_vseq vseq;
      int              n;
      if ($value$plusargs("NUM_TXN=%d", n)) num_txn = n;   // +NUM_TXN=50
      vseq = adxl_random_vseq::type_id::create("vseq");
      vseq.num_txn = num_txn;
      vseq.start(env.vseqr);
    endtask
  endclass : adxl_random_test

  class adxl_full_test extends adxl_base_test;
    `uvm_component_utils(adxl_full_test)

    function new(string name = "adxl_full_test", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    task execute();
      adxl_directed_vseq d;
      adxl_random_vseq   r;
      d = adxl_directed_vseq::type_id::create("d");
      r = adxl_random_vseq::type_id::create("r");
      r.num_txn = 20;
      d.start(env.vseqr);
      r.start(env.vseqr);
    endtask
  endclass : adxl_full_test
