module conv 
#(
  parameter IFMAP_WIDTH = 16,
  parameter WEIGHT_WIDTH = 16,
  parameter OFMAP_WIDTH = 32,

  parameter ARRAY_WIDTH = 4,
  parameter ARRAY_HEIGHT = 4,
  
  parameter WEIGHT_BANK_ADDR_WIDTH = 8, // Should be ceil(log2(WEIGHT_BANK_DEPTH))
  parameter WEIGHT_BANK_DEPTH = 256,
  parameter IFMAP_BANK_ADDR_WIDTH = 8, // Should be ceil(log2(IFMAP_BANK_DEPTH))
  parameter IFMAP_BANK_DEPTH = 256,
  parameter OFMAP_BANK_ADDR_WIDTH = 8, // Should be ceil(log2(OFMAP_BANK_ADDR_WIDTH))
  parameter OFMAP_BANK_DEPTH = 256,
  
  parameter CONFIG_DATA_WIDTH = 8,
  parameter CONFIG_ADDR_WIDTH = 8,
  
  parameter WEIGHT_FIFO_WORDS = 1,
  parameter IFMAP_FIFO_WORDS = 1
)
(
    input clk,
    input rst_n,
    
    input [IFMAP_FIFO_WORDS*IFMAP_WIDTH - 1 : 0] ifmap_data,
    output ifmap_rdy,
    input ifmap_vld,
    
    input [WEIGHT_FIFO_WORDS*WEIGHT_WIDTH - 1 : 0] weight_data,
    output reg weight_rdy,
    input weight_vld,
    
    output [OFMAP_WIDTH - 1 : 0] ofmap_data,
    input ofmap_rdy,
    output reg ofmap_vld,
    
    input [CONFIG_ADDR_WIDTH + CONFIG_DATA_WIDTH - 1: 0] config_data,
    output reg config_rdy,
    input config_vld
);

  localparam CONFIG_WIDTH = CONFIG_ADDR_WIDTH + CONFIG_DATA_WIDTH;

  // Below we have created all the wires for you. You only need to instantiate
  // the missing modules as indicated and make connections between them using
  // these wires.
  
  // ---------------------------------------------------------------------------
  // Wires connecting to the interface FIFOs. You do not need to modify these,
  // or use them in your blocks.
  // ---------------------------------------------------------------------------

  wire [IFMAP_FIFO_WORDS*IFMAP_WIDTH - 1 : 0] ifmap_fifo_dout;
  wire ifmap_fifo_deq;
  wire ifmap_fifo_empty_n;
  
  wire [WEIGHT_FIFO_WORDS*WEIGHT_WIDTH - 1 : 0] weight_fifo_dout;
  wire weight_fifo_deq;
  wire weight_fifo_empty_n;
  
  wire [OFMAP_WIDTH - 1 : 0] ofmap_fifo_din;
  wire ofmap_fifo_enq;
  wire ofmap_fifo_full_n;
  wire ofmap_vld_w;

  wire params_fifo_full_n;
  wire [CONFIG_WIDTH - 1 : 0] params_fifo_dout;
  wire params_fifo_deq;
  wire params_fifo_empty_n;

  // ---------------------------------------------------------------------------
  // Wires coming out of the controller that have the configuration signals
  // for the various address generators. You will need to use these to wire up
  // configuration signals to the appropriate address generators.
  // ---------------------------------------------------------------------------

  wire config_en;
  
  wire [WEIGHT_BANK_ADDR_WIDTH - 1 : 0] weight_max_adr_c;
  wire [IFMAP_BANK_ADDR_WIDTH - 1 : 0] ifmap_max_wadr_c;
  wire [OFMAP_BANK_ADDR_WIDTH - 1 : 0] ofmap_max_adr_c;

  wire [IFMAP_BANK_ADDR_WIDTH - 1 : 0] OX0_c, OY0_c, FX_c, FY_c, STRIDE_c, IX0_c, IY0_c, IC1_c;
 
  // ---------------------------------------------------------------------------
  // Control signals coming out of aggregators/deaggregator
  // ---------------------------------------------------------------------------

  wire weight_wen;
  wire ifmap_wen;
  wire ofmap_wb_ren;
  
  // ---------------------------------------------------------------------------
  // Control signals coming out of the convolution controller 
  // ---------------------------------------------------------------------------

  wire weight_ren;
  wire ifmap_ren;
  wire ofmap_wen;
  wire ofmap_ren;

  wire weight_switch_banks; 
  wire ifmap_switch_banks; 
  wire ofmap_switch_banks;

  wire weight_db_full_n;
  wire ifmap_db_full_n;
  wire ofmap_db_empty_n;
  
  wire ofmap_skew_en; 
  wire ofmap_initialize;
  
  wire systolic_array_weight_wen [ARRAY_HEIGHT - 1 : 0];
  wire systolic_array_weight_en;
  wire systolic_array_en;
  
  // ---------------------------------------------------------------------------
  // Wires for the addresses generated by the various address generators. You
  // will need to connect these to the appropriate address generators.
  // ---------------------------------------------------------------------------

  wire [WEIGHT_BANK_ADDR_WIDTH - 1 : 0] weight_radr;
  wire [WEIGHT_BANK_ADDR_WIDTH - 1 : 0] weight_wadr;
  wire [IFMAP_BANK_ADDR_WIDTH - 1 : 0] ifmap_radr;
  wire [IFMAP_BANK_ADDR_WIDTH - 1 : 0] ifmap_wadr;
  wire [OFMAP_BANK_ADDR_WIDTH - 1 : 0] ofmap_radr;
  wire [OFMAP_BANK_ADDR_WIDTH - 1 : 0] ofmap_wb_radr;
  wire [OFMAP_BANK_ADDR_WIDTH - 1 : 0] ofmap_wadr;
  
  // ---------------------------------------------------------------------------
  // The ifmap, weight and ofmap data connections between the systolic array
  // with skew and the three double buffers.
  // ---------------------------------------------------------------------------

  // Input to the systolic array
  wire signed [IFMAP_WIDTH - 1 : 0] ifmap [ARRAY_HEIGHT - 1 : 0];        
  
  // Output of the ifmap double buffer
  wire signed [ARRAY_HEIGHT*IFMAP_WIDTH - 1 : 0] ifmap_flat;             

  // Output of the ifmap aggeregator and input to the ifmap double buffer  
  wire signed [ARRAY_HEIGHT*IFMAP_WIDTH - 1 : 0] ifmap_aggregator_dout; 
                                         

  
  // Input to the systolic array
  wire signed [WEIGHT_WIDTH - 1 : 0] weight [ARRAY_WIDTH - 1 : 0];
  
  // Output of the weight double buffer
  wire signed [ARRAY_WIDTH*WEIGHT_WIDTH - 1 : 0] weight_flat;           
  
  // Output of the weight aggregator and input to the weight double buffer
  wire signed [ARRAY_WIDTH*WEIGHT_WIDTH - 1 : 0] weight_aggregator_dout; 
                                                                         
  
  // Output of the systolic array 
  wire signed [OFMAP_WIDTH - 1 : 0] ofmap [ARRAY_WIDTH - 1 : 0];        
  
  // Flattened version of above
  wire signed [ARRAY_WIDTH*OFMAP_WIDTH - 1 : 0] ofmap_flat;             
  
  // Ofmap after the initialization mux
  wire signed [OFMAP_WIDTH - 1 : 0] ofmap_from_db [ARRAY_WIDTH - 1 : 0]; 

  // Output of the backward skew registers and input to the systolic array
  wire signed [OFMAP_WIDTH - 1 : 0] ofmap_from_db_skewed [ARRAY_WIDTH - 1 : 0]; 
                                                                    
  // Output of the accumulation buffer                                                                        
  wire signed [ARRAY_WIDTH*OFMAP_WIDTH - 1 : 0] ofmap_from_db_flat; 

  // Output of the accumulation buffer and input to the deaggregator 
  wire signed [ARRAY_WIDTH*OFMAP_WIDTH - 1 : 0] ofmap_wb_data;

  // ---------------------------------------------------------------------------
  //  Weight double buffer and address generators
  // ---------------------------------------------------------------------------

  // Instantiate and connect the weight double buffer, along with two address
  // generators, one that generates write addresses for data coming from the
  // external interface (output of the weight aggregator), one that generates
  // read addresses for data going into the systolic array through skew
  // registers.
 
  // Your code starts here

  // Your code ends here

  // ---------------------------------------------------------------------------
  //  Input double buffer and address generators
  // ---------------------------------------------------------------------------
  
  // Instantiate and connect the input double buffer, along with two address
  // generators, one that generates write addresses for data coming from the
  // external interface (output of the ifmap aggregator), one that generates
  // read addresses for data going into the systolic array through skew
  // registers.
 
  // Your code starts here

  // Your code ends here
  
  // ---------------------------------------------------------------------------
  //  Systolic array with skew
  // ---------------------------------------------------------------------------

  // The data stored in the double buffers is in flattened form whereas the
  // systolic array needs it in the form of unflattened vectors. The generate
  // statement below perform this conversion.

  genvar i;
  generate 
    for (i = 0; i < ARRAY_HEIGHT; i = i + 1) begin: unflatten_ifmap
      assign ifmap[i] = ifmap_flat[(i + 1)*IFMAP_WIDTH - 1 : i*IFMAP_WIDTH];
    end
    for (i = 0; i < ARRAY_WIDTH; i = i + 1) begin: unflatten_weight
      assign weight[i] = weight_flat[(i + 1)*WEIGHT_WIDTH - 1 : i*WEIGHT_WIDTH];
    end
    for (i = 0; i < ARRAY_WIDTH; i = i + 1) begin: unflatten_ofmap
      assign ofmap_from_db[i] = ofmap_initialize ? 0 : 
        ofmap_from_db_flat[(i + 1)*OFMAP_WIDTH - 1 : i*OFMAP_WIDTH];
    end
    for (i = 0; i < ARRAY_WIDTH; i = i + 1) begin: flatten_ofmap
      assign ofmap_flat[(i + 1)*OFMAP_WIDTH - 1 : i*OFMAP_WIDTH] = ofmap[i];
    end
  endgenerate

  // Instantiate and connect the module systolic_array_with_skew. 

  // - It takes as inputs systolic_array_en, systolic_array_weight_en and
  // systolic_array_weight_wen from conv_controller. 
  
  // - The ifmap_in port connects to the ifmap array generated right above
  // from ifmap_flat. The reason we need this conversion is because the input
  // double buffer stores a flattened version of this vector, and we need to
  // unflatten it before we feed it into the systolic array. 
  
  // - Similarly, the weight_in port connects to the weight array generated
  // above.
 
  // - The ofmap_in port connects to the output of the backward skew registers
  // that you need instantiate in the next code section.

  // - The ofmap_out port connects to the ofmap array declared above. The
  // above code is converting this array into a flattened version ofmap_flat,
  // which is what you will write into the accumulation buffer in the next
  // code section.

  // Your code starts here

  // Your code ends here
 
  // ---------------------------------------------------------------------------
  //  Accumulation double buffer and address generators
  // ---------------------------------------------------------------------------
  
  // Instantiate and connect the accumulation buffer, along with three address
  // generators, one that generates write addresses for data coming from the
  // systolic array, one that generates read addresses for data going into the
  // systolic array through skew registers, and finally one that generates
  // read address for ofmap data being sent out of the accelerator.
  
  // Please connect the data towards the systolic array to the ofmap_from_db_flat
  // wire. This goes through the initilization mux and is then unflatted to
  // create ofmap_from_db signal.
  
  // You also need to instantiate the skew registers on the backward path. The
  // input of the skew registers is ofmap_from_db signal created in the
  // generate block above. 

  // Your code starts here

  // Your code ends here

  // The code below instantiate the interface FIFOs for ifmap, weights and
  // ofmap. It also instantiates the aggregators for ifmap and weights that
  // collect several words from the respective fifos and then write them into
  // the ifmap and weight double buffer respectively. Similarly, it
  // instantiates the deaggregator that reads from the accumulation buffer and
  // then sends this data out of the accelerator one word at a time through
  // the ofmap interface fifo. Finally, this code instantiates the convolution
  // controller that generates all the control signals that orchestrate the
  // flow of data through the accelerator (for example, various enable signals
  // for the different sub modules). 

  // You do not need to make any changes to the code below.

  // ---------------------------------------------------------------------------
  //  Interface fifos
  // ---------------------------------------------------------------------------
 
  fifo
  #(
    .DATA_WIDTH(IFMAP_FIFO_WORDS*IFMAP_WIDTH),
    .FIFO_DEPTH(3),
    .COUNTER_WIDTH(1)
  ) ifmap_fifo_inst (
    .clk(clk),
    .rst_n(rst_n),
    .din(ifmap_data),
    .enq(ifmap_rdy_w && ifmap_vld),
    .full_n(ifmap_rdy_w),
    .dout(ifmap_fifo_dout),
    .deq(ifmap_fifo_deq),
    .empty_n(ifmap_fifo_empty_n),
    .clr(1'b0)
  );

  assign ifmap_rdy = ifmap_rdy_w;

  aggregator
  #(
    .DATA_WIDTH(IFMAP_FIFO_WORDS*IFMAP_WIDTH),
    .FETCH_WIDTH(ARRAY_HEIGHT/IFMAP_FIFO_WORDS)
  ) ifmap_aggregator_inst
  (
    .clk(clk),
    .rst_n(rst_n),
    .sender_data(ifmap_fifo_dout),
    .sender_empty_n(ifmap_fifo_empty_n),
    .sender_deq(ifmap_fifo_deq),
    .receiver_data(ifmap_aggregator_dout),
    .receiver_full_n(ifmap_db_full_n),
    .receiver_enq(ifmap_wen)
  );

  fifo
  #(
    .DATA_WIDTH(WEIGHT_FIFO_WORDS*WEIGHT_WIDTH),
    .FIFO_DEPTH(3),
    .COUNTER_WIDTH(1)
  ) weight_fifo_inst (
    .clk(clk),
    .rst_n(rst_n),
    .din(weight_data),
    .enq(weight_rdy_w && weight_vld),
    .full_n(weight_rdy_w),
    .dout(weight_fifo_dout),
    .deq(weight_fifo_deq),
    .empty_n(weight_fifo_empty_n),
    .clr(1'b0)
  );

  assign weight_rdy = weight_rdy_w;

  aggregator
  #(
    .DATA_WIDTH(WEIGHT_FIFO_WORDS*WEIGHT_WIDTH),
    .FETCH_WIDTH(ARRAY_WIDTH/WEIGHT_FIFO_WORDS)
  ) weight_aggregator_inst
  (
    .clk(clk),
    .rst_n(rst_n),
    .sender_data(weight_fifo_dout),
    .sender_empty_n(weight_fifo_empty_n),
    .sender_deq(weight_fifo_deq),
    .receiver_data(weight_aggregator_dout),
    .receiver_full_n(weight_db_full_n),
    .receiver_enq(weight_wen)
  );

  fifo
  #(
    .DATA_WIDTH(OFMAP_WIDTH),
    .FIFO_DEPTH(3),
    .COUNTER_WIDTH(1)
  ) ofmap_fifo_inst (
    .clk(clk),
    .rst_n(rst_n),
    .din(ofmap_fifo_din),
    .enq(ofmap_fifo_enq),
    .full_n(ofmap_fifo_full_n),
    .dout(ofmap_data),
    .deq(ofmap_rdy && ofmap_vld_w),
    .empty_n(ofmap_vld_w),
    .clr(1'b0)
  );

  assign ofmap_vld = ofmap_vld_w;

  deaggregator
  #(
    .DATA_WIDTH(OFMAP_WIDTH),
    .FETCH_WIDTH(ARRAY_WIDTH)
  ) ofmap_deaggregator_inst
  (
    .clk(clk),
    .rst_n(rst_n),
    .sender_data(ofmap_wb_data),
    .sender_empty_n(ofmap_db_empty_n),
    .sender_deq(ofmap_wb_ren),
    .receiver_data(ofmap_fifo_din),
    .receiver_full_n(ofmap_fifo_full_n),
    .receiver_enq(ofmap_fifo_enq)
  );

  fifo
  #(
    .DATA_WIDTH(CONFIG_WIDTH),
    .FIFO_DEPTH(3),
    .COUNTER_WIDTH(1)
  ) params_fifo_inst (
    .clk(clk),
    .rst_n(rst_n),
    .din(config_data),
    .enq(params_fifo_full_n && config_vld),
    .full_n(params_fifo_full_n),
    .dout(params_fifo_dout),
    .deq(params_fifo_deq),
    .empty_n(params_fifo_empty_n),
    .clr(1'b0)
  );
  
  assign config_rdy = params_fifo_full_n;

  // ---------------------------------------------------------------------------
  //  Top level controller
  // ---------------------------------------------------------------------------
 
  conv_controller
  #(
    .IFMAP_WIDTH(IFMAP_WIDTH),
    .WEIGHT_WIDTH(WEIGHT_WIDTH),
    .OFMAP_WIDTH(OFMAP_WIDTH),
  
    .ARRAY_WIDTH(ARRAY_WIDTH),
    .ARRAY_HEIGHT(ARRAY_HEIGHT),
    
    .WEIGHT_BANK_ADDR_WIDTH(WEIGHT_BANK_ADDR_WIDTH),
    .WEIGHT_BANK_DEPTH(WEIGHT_BANK_DEPTH),
    .IFMAP_BANK_ADDR_WIDTH(IFMAP_BANK_ADDR_WIDTH),
    .IFMAP_BANK_DEPTH(IFMAP_BANK_DEPTH),
    .OFMAP_BANK_ADDR_WIDTH(OFMAP_BANK_ADDR_WIDTH),
    .OFMAP_BANK_DEPTH(OFMAP_BANK_DEPTH),

    .CONFIG_ADDR_WIDTH(CONFIG_ADDR_WIDTH),
    .CONFIG_DATA_WIDTH(CONFIG_DATA_WIDTH)
  ) conv_controller_inst
  (
    .clk(clk),
    .rst_n(rst_n),

    .params_fifo_dout(params_fifo_dout),
    .params_fifo_deq(params_fifo_deq),
    .params_fifo_empty_n(params_fifo_empty_n),

    .config_en(config_en),
    .weight_max_adr_c(weight_max_adr_c),
    .ifmap_max_wadr_c(ifmap_max_wadr_c),
    .ofmap_max_adr_c(ofmap_max_adr_c),

    .OX0_c(OX0_c),
    .OY0_c(OY0_c),
    .FX_c(FX_c),
    .FY_c(FY_c),
    .STRIDE_c(STRIDE_c),
    .IX0_c(IX0_c),
    .IY0_c(IY0_c),
    .IC1_c(IC1_c),

    .weight_ren(weight_ren),
    .ifmap_ren(ifmap_ren), 
    .ofmap_wen(ofmap_wen),
    .ofmap_ren(ofmap_ren),

    .weight_db_full_n(weight_db_full_n),
    .ifmap_db_full_n(ifmap_db_full_n),
    .ofmap_db_empty_n(ofmap_db_empty_n),

    .weight_switch_banks(weight_switch_banks),
    .ifmap_switch_banks(ifmap_switch_banks),   
    .ofmap_switch_banks(ofmap_switch_banks),

    .weight_wen(weight_wen),
    .ifmap_wen(ifmap_wen),
    .ofmap_wb_ren(ofmap_wb_ren),   

    .ofmap_skew_en(ofmap_skew_en),
    .ofmap_initialize(ofmap_initialize),
    
    .systolic_array_weight_wen(systolic_array_weight_wen),
    .systolic_array_weight_en(systolic_array_weight_en),
    .systolic_array_en(systolic_array_en)
  );

endmodule
