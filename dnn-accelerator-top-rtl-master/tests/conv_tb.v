`define IFMAP_WIDTH 8
`define WEIGHT_WIDTH 8
`define OFMAP_WIDTH 32

`define ARRAY_WIDTH 16
`define ARRAY_HEIGHT 16

`define WEIGHT_BANK_ADDR_WIDTH 13
`define WEIGHT_BANK_DEPTH 8192

`define IFMAP_BANK_ADDR_WIDTH 12
`define IFMAP_BANK_DEPTH 3600

`define OFMAP_BANK_ADDR_WIDTH 8
`define OFMAP_BANK_DEPTH 256

`define CONFIG_ADDR_WIDTH 8
`define CONFIG_DATA_WIDTH 8

`define WEIGHT_FIFO_WORDS 4
`define IFMAP_FIFO_WORDS 4


`include "tests/layer_params.v"


`define COUNTER_WIDTH 32 //FIXME: Arbitrary


module conv_tb;

  reg clk;
  reg rst_n;
  
  reg [`COUNTER_WIDTH - 1 : 0] ifmap_adr_r;
  wire ifmap_rdy_w;
  
  reg [`COUNTER_WIDTH - 1 : 0] weight_adr_r;
  wire weight_rdy_w;

  wire [`COUNTER_WIDTH - 1 : 0] ofmap_data_w;
  reg ofmap_rdy_r;
  wire ofmap_vld_w;
  reg [`COUNTER_WIDTH - 1 : 0] ofmap_adr_r; 
   
  wire config_rdy_w;
  reg  config_vld_r;
  reg [`CONFIG_ADDR_WIDTH + `CONFIG_DATA_WIDTH - 1 : 0] config_data_r;
  reg [`CONFIG_ADDR_WIDTH - 1 : 0] config_adr_r;


  wire [`WEIGHT_BANK_ADDR_WIDTH- 1 : 0] weight_max_adr_c;
  wire [`IFMAP_BANK_ADDR_WIDTH - 1 : 0] ifmap_max_wadr_c;
  wire [`OFMAP_BANK_ADDR_WIDTH - 1 : 0] ofmap_max_adr_c;
  wire [`IFMAP_BANK_ADDR_WIDTH - 1 : 0] OX0_c;
  wire [`IFMAP_BANK_ADDR_WIDTH - 1 : 0] OY0_c;
  wire [`IFMAP_BANK_ADDR_WIDTH - 1 : 0] FX_c;
  wire [`IFMAP_BANK_ADDR_WIDTH - 1 : 0] FY_c;
  wire [`IFMAP_BANK_ADDR_WIDTH - 1 : 0] IX0_c;
  wire [`IFMAP_BANK_ADDR_WIDTH - 1 : 0] IY0_c;
  wire [`IFMAP_BANK_ADDR_WIDTH - 1 : 0] IC1_c;
  wire [`COUNTER_WIDTH         - 1 : 0] OC1_c;
  wire [`IFMAP_BANK_ADDR_WIDTH - 1 : 0] STRIDE_c;
  wire [`COUNTER_WIDTH         - 1 : 0] OY0_OX0_c;
  wire [`COUNTER_WIDTH         - 1 : 0] IC1_FY_FX_OY0_OX0_c;
 

  assign weight_max_adr_c = `FX*`FY*`IC0*`IC1 - 1;
  assign ifmap_max_wadr_c = `IC1*((`OY0-1)*`STRIDE+`FY)*((`OX0-1)*`STRIDE+`FX)-1;
  assign ofmap_max_adr_c = `OX0*`OY0 - 1;
  assign OX0_c = `OX0;
  assign OY0_c = `OY0;
  assign FX_c  = `FX;
  assign FY_c  = `FY; 
  assign IC1_c = `IC1;
  assign OC1_c = `OC1;
  assign IX0_c = (`OX0 - 1)*`STRIDE + `FX;
  assign IY0_c = (`OY0 - 1)*`STRIDE + `FY;
  assign STRIDE_c = `STRIDE;
  assign OY0_OX0_c = `OY0*`OX0; 
  assign IC1_FY_FX_OY0_OX0_c = `OX0*`OY0*`FX*`FY*`IC1; 


  reg [7:0] state_r;
  
  reg [`IFMAP_WIDTH - 1 : 0] ifmap_memory [((`OX0-1)*`STRIDE+`FX)*((`OY0-1)*`STRIDE+`FY)*`IC0*`IC1*`OX1*`OY1-1:0];
  reg [`WEIGHT_WIDTH - 1 : 0] weight_memory [`FX*`FY*`IC0*`IC1*`OC0*`OC1 - 1 : 0];
  reg [`OFMAP_WIDTH - 1 : 0] ofmap_memory [`OX0*`OY0*`OC0*`OC1*`OX1*`OY1 - 1 : 0];
  reg [`CONFIG_DATA_WIDTH - 1 : 0] config_r [34 : 0];

  always #10 clk =~clk;

  conv 
  #(
    .IFMAP_WIDTH(`IFMAP_WIDTH),
    .WEIGHT_WIDTH(`WEIGHT_WIDTH),
    .OFMAP_WIDTH(`OFMAP_WIDTH),
    .ARRAY_WIDTH(`ARRAY_WIDTH),
    .ARRAY_HEIGHT(`ARRAY_HEIGHT),
    .WEIGHT_BANK_ADDR_WIDTH(`WEIGHT_BANK_ADDR_WIDTH),
    .WEIGHT_BANK_DEPTH(`WEIGHT_BANK_DEPTH),
    .IFMAP_BANK_ADDR_WIDTH(`IFMAP_BANK_ADDR_WIDTH),
    .IFMAP_BANK_DEPTH(`IFMAP_BANK_DEPTH),
    .OFMAP_BANK_ADDR_WIDTH(`OFMAP_BANK_ADDR_WIDTH),
    .OFMAP_BANK_DEPTH(`OFMAP_BANK_DEPTH),
    .CONFIG_DATA_WIDTH(`CONFIG_DATA_WIDTH),
    .CONFIG_ADDR_WIDTH(`CONFIG_ADDR_WIDTH),
    .WEIGHT_FIFO_WORDS(`WEIGHT_FIFO_WORDS),
    .IFMAP_FIFO_WORDS(`IFMAP_FIFO_WORDS)
  ) conv_inst
  (
    .clk(clk),
    .rst_n(rst_n),
    .ifmap_data({
      ifmap_memory[ifmap_adr_r + 3], 
      ifmap_memory[ifmap_adr_r + 2], 
      ifmap_memory[ifmap_adr_r + 1], 
      ifmap_memory[ifmap_adr_r]}), // FIXME: Not written properly as a function of IFMAP_FIFO_WORDS 
    .ifmap_rdy(ifmap_rdy_w),
    .ifmap_vld(ifmap_rdy_w & (state_r == 2)),
    .weight_data({
      weight_memory[weight_adr_r + 3],
      weight_memory[weight_adr_r + 2],
      weight_memory[weight_adr_r + 1],
      weight_memory[weight_adr_r]}), // FIXME: Not written properly as a function of WEIGHT_FIFO_WORDS
    .weight_rdy(weight_rdy_w),
    .weight_vld(weight_rdy_w & (state_r == 2)),
    .ofmap_data(ofmap_data_w),
    .ofmap_rdy(ofmap_rdy_r),
    .ofmap_vld(ofmap_vld_w),
    .config_data(config_data_r),
    .config_rdy(config_rdy_w),
    .config_vld(config_vld_r)
  );

  initial begin
    $readmemh("./layers/ifmap_data.txt", ifmap_memory);
    $readmemh("./layers/weight_data.txt", weight_memory);
    $readmemh("./layers/ofmap_data.txt", ofmap_memory);
    
    clk <= 0;
    rst_n <= 0;
    state_r <= 0;
    ifmap_adr_r <= 0; 
    weight_adr_r <= 0; 
    ofmap_adr_r <= 0; 
    ofmap_rdy_r <= 1;
    config_vld_r <= 0;
    config_data_r <= 0;
    config_adr_r <= 0;
    
    config_r[ 0] <=  weight_max_adr_c;
    config_r[ 1] <= (weight_max_adr_c >> 8);
    config_r[ 2] <=  ifmap_max_wadr_c;
    config_r[ 3] <= (ifmap_max_wadr_c >> 8);
    config_r[ 4] <=  ofmap_max_adr_c;
    config_r[ 5] <= (ofmap_max_adr_c >> 8);
    config_r[ 6] <=  OX0_c;
    config_r[ 7] <= (OX0_c >> 8);
    config_r[ 8] <=  OY0_c;
    config_r[ 9] <= (OY0_c >> 8);
    config_r[10] <=  FX_c;
    config_r[11] <= (FX_c >> 8);
    config_r[12] <=  FY_c;
    config_r[13] <= (FY_c >> 8);
    config_r[14] <=  STRIDE_c;
    config_r[15] <= (STRIDE_c >> 8);
    config_r[16] <=  IX0_c;
    config_r[17] <= (IX0_c >> 8);
    config_r[18] <=  IY0_c;
    config_r[19] <= (IY0_c >> 8);
    config_r[20] <=  IC1_c;
    config_r[21] <= (IC1_c >> 8);
    config_r[22] <=  OC1_c;
    config_r[23] <= (OC1_c >> 8);
    config_r[24] <= (OC1_c >> 16);
    config_r[25] <= (OC1_c >> 24);
    config_r[26] <=  IC1_FY_FX_OY0_OX0_c;
    config_r[27] <= (IC1_FY_FX_OY0_OX0_c >> 8);
    config_r[28] <= (IC1_FY_FX_OY0_OX0_c >> 16);
    config_r[29] <= (IC1_FY_FX_OY0_OX0_c >> 24);
    config_r[30] <=  OY0_OX0_c;
    config_r[31] <= (OY0_OX0_c >> 8);
    config_r[32] <= (OY0_OX0_c >> 16);
    config_r[33] <= (OY0_OX0_c >> 24);
 
    #20 rst_n <= 0;
    #20 rst_n <= 1;
  end
  
  always @ (posedge clk) begin
    if (rst_n) begin
      if (state_r == 0) begin
        if (config_rdy_w) begin
          config_data_r <= {config_adr_r, config_r[config_adr_r]}; 
          config_vld_r <= 1;
          config_adr_r <= config_adr_r + 1;
          if (config_adr_r == 34) begin
            state_r <= 1;
          end
        end
      end else if (state_r == 1) begin
        config_vld_r <= 0;
        state_r <= 2;
      end
    end

    if (ofmap_vld_w) begin
      
      $display("%t: ofmap_adr_r = %d, ofmap_data_w = %h, expected ofmap_data_w = %h",
        $time, ofmap_adr_r, ofmap_data_w, ofmap_memory[ofmap_adr_r]);
      
      assert(ofmap_data_w == ofmap_memory[ofmap_adr_r]) else $finish;
    
      ofmap_adr_r <= ofmap_adr_r + 1;

      if (ofmap_adr_r == `OC0*`OX0*`OY0*`OC1*`OX1*`OY1 - 1) begin
        $display("Done layer");
      	$display("Cycles taken = %d", $time/20);
	      $display("Ideal cycles = %d", `OX0*`OY0*`OX1*`OY1*`OC1*`IC1*`FX*`FY);
	      $finish;
      end
    end
  end

  always @ (posedge clk) begin
    if (rst_n) begin
      if (state_r == 2) begin
        if (ifmap_rdy_w) begin
          ifmap_adr_r <= ifmap_adr_r + `IFMAP_FIFO_WORDS;
        end
      end
    end else begin
      ifmap_adr_r <= 0;
    end
  end
  
  always @ (posedge clk) begin
    if (rst_n) begin
      if (state_r == 2) begin
        if (weight_rdy_w) begin
          weight_adr_r <= (weight_adr_r == `IC0*`OC0*`FX*`FY*`IC1*`OC1 - `WEIGHT_FIFO_WORDS) ? 
            0 : weight_adr_r + `WEIGHT_FIFO_WORDS;
        end
      end
    end else begin
      weight_adr_r <= 0;
    end
  end
 
  initial begin
    $vcdplusfile("dump.vcd");
    $vcdplusmemon();
    $vcdpluson(0, conv_tb);
    `ifdef FSDB
    $fsdbDumpfile("dump.fsdb");
    $fsdbDumpvars(0, conv_tb);
    $fsdbDumpMDA();
    `endif
    #200000000;
    $finish(2);
  end

endmodule
