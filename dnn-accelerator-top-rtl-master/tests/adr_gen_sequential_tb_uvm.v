// Write a UVM test for the sequential address generator (adr_gen_sequential).
// Especially make sure that the address generator works correctly with random
// stalls (meaning if adr_en goes low intermittently), that it resets properly, 
// and that it goes back to zero after reaching the maximum configured value.

// Your code starts here
`define BANK_ADDR_WIDTH 8
`define TEST_LENGTH 100

interface adrgen_if (input bit clk);
    logic rst_n;
    logic adr_en;
    logic config_en;
    logic [`BANK_ADDR_WIDTH - 1 : 0] config_data;
    logic [`BANK_ADDR_WIDTH - 1 : 0] adr;
endinterface

class adrgen_item;
    bit config_en;
    rand bit adr_en;
    rand bit [`BANK_ADDR_WIDTH - 1 : 0]  config_data;
    bit [`BANK_ADDR_WIDTH - 1 : 0]  adr;
endclass;

class driver;
    mailbox drv_mbx;

    virtual adrgen_if vif;
    
    task run();
        $display ("T=%0t [Write driver] Starting ...", $time);
        forever begin
            adrgen_item transaction;
            drv_mbx.get(transaction);
            vif.adr_en = transaction.adr_en;
            vif.config_en = transaction.config_en;
            vif.config_data = transaction.config_data;
            @ (negedge vif.clk);
        end       
    endtask
endclass


class monitor; 
    virtual adrgen_if vif;
    mailbox scb_mbx; 

    task run();
        $display("T=%0t [Read monitor] Starting ...", $time);
        forever begin
            adrgen_item transaction = new;
            @ (posedge vif.clk);
            transaction.adr = vif.adr;
            transaction.adr_en = vif.adr_en;
            transaction.config_en = vif.config_en;
            transaction.config_data = vif.config_data;
            scb_mbx.put(transaction);
        end
    endtask
endclass


class scoreboard;
    mailbox scb_mbx;
    int resp_id;
    reg [`BANK_ADDR_WIDTH - 1 : 0] expected_data;
    reg [`BANK_ADDR_WIDTH - 1 : 0] config_data;

    task run();
        forever begin
            adrgen_item transacation;
            resp_id = 0;
            scb_mbx.get(transacation);
            config_data = transacation.config_data;
            expected_data = 0;

            while (resp_id < `TEST_LENGTH) begin
                scb_mbx.get(transacation);

                if (transacation.adr == expected_data) begin
                    $display("T=%0t [Scoreboard] Pass! Received = %d, Expected = %d", $time, transacation.adr, expected_data);
                end else begin
                    $display("T=%0t [Scoreboard] Error! Received = %d, Expected = %d", $time, transacation.adr, expected_data);
                end

                if (transacation.adr_en) begin
                    if (transacation.adr == config_data) begin
                        expected_data = 0;
                    end
                    else begin
                        expected_data = expected_data + 1;
                    end
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
    virtual adrgen_if vif;

    function new();
        d0 = new; 
        m0 = new;
        s0 = new;
        scb_mbx = new();
    endfunction

    virtual task run();
        d0.vif = vif;
        m0.vif = vif;
        s0.scb_mbx = scb_mbx;
        m0.scb_mbx = scb_mbx;

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
        adrgen_item item;
        $display ("T=%0t [Test] Starting write stimulus ...", $time);

        stim_id = 0;

        while(stim_id < `TEST_LENGTH) begin
            if (stim_id != 0) begin
                item = new;
                item.randomize();
                item.adr_en = 1;
                item.config_en = 0;
                drv_mbx.put(item);
            end
            else begin
                item = new;
                item.randomize();
                item.adr_en = 0;
                item.config_en = 1;
                drv_mbx.put(item);
            end
            
            stim_id = stim_id + 1;
        end
    endtask
endclass

module adr_gen_sequential_tb;
  
    reg clk;
    reg rst_n;

    always #10 clk = ~clk;

    adrgen_if _if (clk);

    adr_gen_sequential #( 
        .BANK_ADDR_WIDTH(`BANK_ADDR_WIDTH)
    ) dut (
        .clk(_if.clk),
        .rst_n(_if.rst_n),
        .adr_en(_if.adr_en),
        .config_en(_if.config_en),
        .config_data(_if.config_data),
        .adr(_if.adr)
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
        $vcdpluson(0, adr_gen_sequential_tb);
        `ifdef FSDB
        $fsdbDumpfile("dump.fsdb");
    	$fsdbDumpvars(0, adr_gen_sequential_tb);
    	$fsdbDumpMDA();
        `endif
        #20000000;
        $finish(2);
    end
endmodule

// Your code ends here
