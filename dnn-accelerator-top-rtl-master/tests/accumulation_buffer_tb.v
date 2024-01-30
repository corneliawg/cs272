// Write a directed test for the accumulation buffer module. Make sure you test 
// all its ports and its behaviour when your switch banks.

// Your code starts here

`define BANK_ADDR_WIDTH 7
`define DATA_WIDTH 64
`define BANK_DEPTH 128

module accumulation_buffer_tb;

	reg clk;
	reg rst_n;
 	reg switch_banks;
	reg ren;
	reg [`BANK_ADDR_WIDTH-1:0] radr;
	reg [`DATA_WIDTH-1:0] rdata;
	reg wen;
	reg [`BANK_ADDR_WIDTH-1:0] wadr;
	reg [`DATA_WIDTH-1:0] wdata;
	reg ren_wb;
	reg [`BANK_ADDR_WIDTH-1:0] radr_wb;
	reg [`DATA_WIDTH-1:0] rdata_wb;


	always #10 clk = ~clk;

	accumulation_buffer #(
		.DATA_WIDTH(`DATA_WIDTH),
		.BANK_ADDR_WIDTH(`BANK_ADDR_WIDTH),
		.BANK_DEPTH(`BANK_DEPTH)
	) accumulation_buffer_inst (
		.clk(clk),
		.rst_n(rst_n),
		.switch_banks(switch_banks),
		.ren(ren),
		.radr(radr),
		.rdata(rdata),
		.wen(wen),
		.wadr(wadr),
		.wdata(wdata),
		.ren_wb(ren_wb),
		.radr_wb(radr_wb),
		.rdata_wb(rdata_wb)
	);	

	initial begin
		clk <= 0;
		rst_n <= 1;
		switch_banks <= 0;
		ren <= 0;
		radr <= 0;
		wen <= 0;
		wadr <= 0;
		wdata <= 0;
		ren_wb <= 0;
		radr_wb <= 0;
		
		// Reset block
		#20 rst_n <= 0;
		#20 rst_n <= 1;
		
		// Write to Bank 1
		// B0 is RO and B1 is RW 
		wen <= 1;
		wdata <= 64'hdeadbeef;
		wadr <= 0;
		#20;
		wdata <= 64'habcdabcd;
		wadr <= 1;
		#20;
		wen <= 0;
		#20;
		
		// Switch banks and read what I wrote
		// B0 is RW and B1 is RO
		switch_banks <= 1;
		#20; 
		switch_banks <= 0; 
		#20; 
		radr_wb <= 0;
		ren_wb <= 1;
		#20; 
		assert(rdata_wb == 64'hdeadbeef);
		radr_wb <= 1;
		ren_wb <= 1;
		#20; 
		assert(rdata_wb == 64'habcdabcd);
		
		// Write something to Bank 0 including last address
		wen <= 1;
		wdata <= 64'hfefefefe;
		wadr <= 5;
		#20;
		wdata <= 64'hbaddadda;
		wadr <= `BANK_ADDR_WIDTH-1;
		#20;
		wen <= 0;
		#20;

		// Read what I just wrote (using R/W without switching banks)
		radr <= 5;
		ren <= 1;
		#20; 
		assert(rdata == 64'hfefefefe);
		radr <= `BANK_ADDR_WIDTH-1;
		ren <= 1;
		#20; 
		assert(rdata == 64'hbaddadda);

		// Switch banks and read what I wrote on wb
		// B0 is RO and B1 is RW 
		switch_banks <= 1;
		#20; 
		switch_banks <= 0; 
		#20; 
		radr_wb <= 5;
		ren_wb <= 1;
		#20; 
		assert(rdata_wb == 64'hfefefefe);
		radr_wb <= `BANK_ADDR_WIDTH-1;
		ren_wb <= 1;
		#20; 
		assert(rdata_wb == 64'hbaddadda);

		//Switch banks read first value then reset to go back to bank 0
		// B0 is RW and B1 is RO
		switch_banks <= 1;
		#20; 
		switch_banks <= 0; 
		#20; 
		radr_wb <= 0;
		ren_wb <= 1;
		#20; 
		assert(rdata_wb == 64'hdeadbeef);
		#20; 

		// B0 is RO and B1 is RW 
		rst_n <= 0;
		#20 rst_n <= 1;
		#20; 

		radr_wb <= 5;
		ren_wb <= 1;
		#20; 
		assert(rdata_wb == 64'hfefefefe);


		// Finally read and write same cycle (and read the value
		// I wrote)
		radr_wb <= `BANK_ADDR_WIDTH-1;
		ren_wb <= 1;
		wen <= 1;
		wdata <= 64'h12345678;
		wadr <= 5;
		#20; 
		assert(rdata_wb == 64'hbaddadda);

		// B0 is RW and B1 is RO
		switch_banks <= 1;
		#20; 
		switch_banks <= 0; 
		#20; 	
		radr <= 5;
		ren <= 1;
		#20; 
		assert(rdata == 64'h12345678);

	end

   	initial begin
    		$vcdplusfile("dump.vcd");
    		$vcdplusmemon();
    		$vcdpluson(0, accumulation_buffer_tb);
			`ifdef FSDB
			$fsdbDumpfile("dump.fsdb");
    		$fsdbDumpvars(0, accumulation_buffer_tb);
    		$fsdbDumpMDA();
			`endif
    		#20000000;
    		$finish(2);
  	end

endmodule


// Your code ends here
