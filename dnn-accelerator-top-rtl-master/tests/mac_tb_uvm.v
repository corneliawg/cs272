// Write a UVM test for the MAC unit. Especially make sure that the MAC unit
// works correctly with random stalls (meaning if en goes low intermittently)
// and that it resets properly.

// Your code starts here

import "DPI-C" function int mac_gold(int a, int b, int c);

`define IFMAP_WIDTH 16
`define WEIGHT_WIDTH 16
`define OFMAP_WIDTH 32
`define TEST_LENGTH 100

interface mac_if(input bit clk);
    logic en;
    logic rst_n;
    logic weight_wen;
    logic signed [`OFMAP_WIDTH-1:0] ofmap_in;
    logic signed [`IFMAP_WIDTH-1:0] ifmap_in;
    logic signed [`WEIGHT_WIDTH-1:0] weight_in;
    logic signed [`IFMAP_WIDTH-1:0] ifmap_out;
    logic signed [`OFMAP_WIDTH-1:0] ofmap_out;
endinterface

class mac_item;
    rand bit weight_wen;
    rand bit en;
    rand bit signed [`OFMAP_WIDTH - 1 : 0]  ofmap_in;
    rand bit signed [`WEIGHT_WIDTH - 1 : 0] weight_in;
    rand bit signed [`IFMAP_WIDTH - 1 : 0]  ifmap_in;
    bit signed [`OFMAP_WIDTH - 1 : 0]  ofmap_out;
    bit signed [`IFMAP_WIDTH - 1 : 0]  ifmap_out;
endclass;


class driver;
    virtual mac_if vif;
    mailbox drv_mbx;
    
    task run();
        $display ("T=%0t [Write driver] Starting ...", $time);
        forever begin
            mac_item item;
            drv_mbx.get(item);
            vif.en = item.en;
            vif.weight_wen = item.weight_wen;
            vif.weight_in = item.weight_in;
            vif.ofmap_in = item.ofmap_in;
            vif.ifmap_in = item.ifmap_in;
        @ (negedge vif.clk);  
        end       
    endtask
endclass


class monitor; 
    virtual mac_if vif;
    mailbox scb_mbx; 

    task run();
        $display("T=%0t [Read monitor] Starting ...", $time);
        forever begin
            mac_item item = new;

            @ (posedge vif.clk); 
            item.en = vif.en;
            item.ifmap_in = vif.ifmap_in;
            item.ifmap_out = vif.ifmap_out;
            item.ofmap_in = vif.ofmap_in;
            item.ofmap_out = vif.ofmap_out;
            item.weight_in = vif.weight_in;
            item.weight_wen = vif.weight_wen;
            scb_mbx.put(item);
        end
    endtask
endclass

class scoreboard;
  mailbox scb_mbx;
  int resp_id;
  reg signed [`WEIGHT_WIDTH - 1 : 0] weight_save;
  reg signed [`OFMAP_WIDTH - 1 : 0] ofmap_save;

  task run();
    forever begin
      mac_item item;
      resp_id = 0;
      scb_mbx.get(item);
      weight_save = item.weight_in;

      ofmap_save = 0;
      while (resp_id < `TEST_LENGTH) begin
        scb_mbx.get(item);

        if (item.ofmap_out == ofmap_save) begin
            $display("T=%0t [Scoreboard] Pass! Received = %d, Expected = %d", $time, item.ofmap_out, ofmap_save);
        end else begin
            $display("T=%0t [Scoreboard] Error! Received = %d, Expected = %d", $time, item.ofmap_out, ofmap_save);
        end

        if (item.en) begin
          // ofmap_save = item.ifmap_in * weight_save + item.ofmap_in;
          ofmap_save = mac_gold(item.ifmap_in, weight_save, item.ofmap_in);
        end

        if (item.weight_wen) begin
          weight_save = item.weight_in;     
        end

        resp_id = resp_id + 1;
      end
      $finish;
    end
  endtask
endclass

class env;
    driver d0;
    monitor m0;
    scoreboard s0;

    mailbox scb_mbx;

    virtual mac_if vif;

    function new();
        d0 = new; 
        m0 = new;
        s0 = new;
        scb_mbx = new();
    endfunction

    virtual task run();
        d0.vif = vif;
        m0.vif = vif;
        m0.scb_mbx = scb_mbx;
        s0.scb_mbx = scb_mbx;

        fork
            s0.run();
            d0.run();
            m0.run();    
        join_any 
    endtask
endclass    

class test;
    env e0;
    mailbox drv_mbx;
    int stim_id;

    function new();
        drv_mbx = new();
        e0 = new();
    endfunction

    virtual task run();
        e0.d0.drv_mbx = drv_mbx;
        fork 
            e0.run();
        join_none

        apply_stim();
    endtask

    virtual task apply_stim();
        mac_item item;
        $display ("T=%0t [Test] Starting write stimulus ...", $time);

        item = new;
        item.en = 0;

        item.weight_in = 0;
        item.weight_wen = 1;
        
        drv_mbx.put(item);

        stim_id = 0;
        
        while(stim_id < `TEST_LENGTH) begin      
            item = new;
            item.randomize();
            drv_mbx.put(item);
            stim_id = stim_id + 1;
        end
    endtask
endclass

module mac_tb;
  
    reg clk;
    reg rst_n;

    always #10 clk = ~clk;

    mac_if _if (clk);

    mac #( 
        .IFMAP_WIDTH(`IFMAP_WIDTH),
        .WEIGHT_WIDTH(`WEIGHT_WIDTH),
        .OFMAP_WIDTH(`OFMAP_WIDTH)
    ) dut (
        .clk(_if.clk),
        .rst_n(_if.rst_n),
        .en(_if.en),
        .weight_wen(_if.weight_wen),
        .ifmap_in(_if.ifmap_in),
        .weight_in(_if.weight_in),
        .ofmap_in(_if.ofmap_in),
        .ifmap_out(_if.ifmap_out),
        .ofmap_out(_if.ofmap_out)
    );

    assign _if.rst_n = rst_n;

    initial begin
        test t0;
        clk <= 0;
        rst_n <= 0;
        #20 rst_n <= 1;
        t0 = new(); 
        t0.e0.vif = _if;
        t0.run();
    end

   initial begin
        $vcdplusfile("dump.vcd");
        $vcdplusmemon();
        $vcdpluson(0, mac_tb);
        `ifdef FSDB
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, mac_tb);
        $fsdbDumpMDA();
        `endif
        #20000000;
        $finish(2);
    end
endmodule

// Your code ends here
