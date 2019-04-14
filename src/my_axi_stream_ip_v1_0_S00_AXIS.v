
`timescale 1 ns / 1 ps

	module my_axi_stream_ip_v1_0_S00_AXIS #
	(
		// Users to add parameters here

		// User parameters ends
		// Do not modify the parameters beyond this line

		// AXI4Stream sink: Data Width
		parameter integer C_S_AXIS_TDATA_WIDTH	= 32
	)
	(
		// Users to add ports here
		input      			  ddr_user_clk				,
		input				  ddr_user_rst				,
		input      		      mac_to_ddr_fifo_rd_en 	,//读数据到ddr
		input				  ddr_to_mac_done			,
		output  [127:0]   	  mac_to_ddr_fifo_dout		,	
		output                mac_to_ddr_fifo_empty		,//引出去给 data control
		
		output  			  cfg_rd_end_flag,   //给Master
		output				  mac_to_ctrl_valid, //给主控制器
		output	[127:0]		  mac_to_ctrl_data,  //
		// User ports ends
		// Do not modify the ports beyond this line
		
		//debug
		output		[31:0]  debug_din,
		output				debug_wr_en,
		output      		debug_rd_en,
		output      [127:0] debug_dout,
		output              debug_fifo_empty,
		
		//

		// AXI4Stream sink: Clock
		input wire  S_AXIS_ACLK,
		// AXI4Stream sink: Reset
		input wire  S_AXIS_ARESETN,
		// Ready to accept data in
		output wire  S_AXIS_TREADY,
		// Data in
		input wire [C_S_AXIS_TDATA_WIDTH-1 : 0] S_AXIS_TDATA,
		// Byte qualifier
		input wire [(C_S_AXIS_TDATA_WIDTH/8)-1 : 0] S_AXIS_TSTRB,
		// Indicates boundary of last packet
		input wire  S_AXIS_TLAST,
		// Data is in valid
		input wire  S_AXIS_TVALID
	);
	// Add user logic here
	
	localparam CFG_NUM = 20;//配置信息数量
	
	
//读配置信息		
	wire wr_en2;
	wire rd_en2;
	wire [127:0] dout2;
	wire empty2;
	wire prog_full2;
	wire [C_S_AXIS_TDATA_WIDTH-1 : 0] din2;
	reg stop_wr_en2;
	
	assign wr_en2 = S_AXIS_TREADY && S_AXIS_TVALID && !prog_full2 && ~stop_wr_en2;
	assign din2 = S_AXIS_TDATA;
	reg [7:0]config_valid_cnt;//计数16次 为1个512bits=16*32
	reg [7:0]cfg_trans_num;//2
	always @(posedge S_AXIS_ACLK)begin
		if(S_AXIS_ARESETN==0)begin
			config_valid_cnt <= 0;
			cfg_trans_num	 <= 0;
		end
		else if(ddr_to_mac_done)begin
			config_valid_cnt <= 0;
			cfg_trans_num	 <= 0;
		end
		else if(config_valid_cnt==15)begin
			config_valid_cnt <= 0;
			cfg_trans_num    <= cfg_trans_num + 1;
		end
		else if(wr_en2)begin
			config_valid_cnt <= config_valid_cnt + 1;
			cfg_trans_num 	 <= cfg_trans_num;
		end
		else begin
			config_valid_cnt <= config_valid_cnt;
			cfg_trans_num 	 <= cfg_trans_num;
		end
	end
	
	fifo_generator_11 ps_ctrl2pl_ctrl_32x512_128x128 (
	  .wr_clk(S_AXIS_ACLK),        // input wire wr_clk
	  .rd_clk(ddr_user_clk),        // input wire rd_clk
	  .din(din2),              // input wire [31 : 0] din
	  .wr_en(wr_en2),          // input wire wr_en
	  .rd_en(rd_en2),          // input wire rd_en
	  .dout(dout2),            // output wire [127 : 0] dout
	  .full(),            // output wire full
	  .empty(empty2),          // output wire empty
	  .prog_full(prog_full2)  // output wire prog_full
	);


	assign rd_en2 = stop_wr_en2&&~empty2;//非空时读出
	
	reg ctrl_data_valid_a=0;
	reg ctrl_data_valid_b=0;
	always @(posedge ddr_user_clk)begin
			ctrl_data_valid_a <= rd_en2;
			ctrl_data_valid_b <= ctrl_data_valid_a;
	end
		
	assign mac_to_ctrl_data  = dout2;//每128bit传输一次
	assign mac_to_ctrl_valid = ctrl_data_valid_b;
	
	reg cfg_rd_end_flag_reg;
	
	always @(posedge S_AXIS_ACLK)begin
		if(S_AXIS_ARESETN==0)begin
			cfg_rd_end_flag_reg <= 0;
			//stop_wr_en2 <= 0;
		end
		else if((cfg_trans_num==(CFG_NUM-1))&&(config_valid_cnt==15))begin
			cfg_rd_end_flag_reg <= 1;
			//stop_wr_en2 <= 1;
		end
		else begin
			cfg_rd_end_flag_reg <= 0;
			//stop_wr_en2 <= stop_wr_en2;
		end
	end

	always @(posedge S_AXIS_ACLK)begin
		if(S_AXIS_ARESETN==0)begin
			stop_wr_en2 <= 0;
		end
		else if(ddr_to_mac_done)begin
			stop_wr_en2 <= 0;
		end
		else if((cfg_trans_num==(CFG_NUM-1))&&(config_valid_cnt==15))begin
			stop_wr_en2 <= 1;
		end
	end
	
	assign cfg_rd_end_flag   = cfg_rd_end_flag_reg;
	
//读数据	
	reg rd_data_begin;
	always @(posedge S_AXIS_ACLK)begin
		if(S_AXIS_ARESETN==0)begin
			rd_data_begin <= 0;
		end
		else if(ddr_to_mac_done)begin
			rd_data_begin <= 0;
		end
		else if(cfg_rd_end_flag)begin
			rd_data_begin <= 1;//
		end
		else begin
			rd_data_begin <= rd_data_begin;
		end
	end
	
	wire [31:0] din = S_AXIS_TDATA;
	wire wr_en = S_AXIS_TREADY && S_AXIS_TVALID && !prog_full && rd_data_begin;
	
	reg s_axi_tready;
	always @(posedge S_AXIS_ACLK)begin
		if(S_AXIS_ARESETN==0)begin
			s_axi_tready <= 0;
		end
		else if(!prog_full || (!prog_full2))begin
			s_axi_tready <= 1;
		end
		else begin
			s_axi_tready <= 0;
		end
	end
	
	assign S_AXIS_TREADY = s_axi_tready;
	
	wire data_fifo_empty;
	fifo_generator_0 ps_data2pl_data_32x32768_128x8192(
	  .wr_clk			(S_AXIS_ACLK			), // input wire wr_clk
	  .rd_clk			(ddr_user_clk			), // input wire rd_clk
	  .din				(din					), // input wire [31 : 0] din
	  .wr_en			(wr_en					), // input wire wr_en
	  .rd_en			(mac_to_ddr_fifo_rd_en	), // input wire rd_en
	  .dout				(mac_to_ddr_fifo_dout	), // output wire [127 : 0] dout
	  .full				(						), // output wire full
	  .empty			(data_fifo_empty		), // output wire empty
	  .prog_full		(prog_full				)  // output wire prog_full
	);	
	
	
/* 	fifo_generator_0 ps_data2pl_data_32x32768_128x8192(
	  .rst				((~S_AXIS_ARESETN)||ddr_to_mac_done),                  // input wire rst
	  .wr_clk			(S_AXIS_ACLK			), // input wire wr_clk
	  .rd_clk			(ddr_user_clk			), // input wire rd_clk
	  .din				(din					), // input wire [31 : 0] din
	  .wr_en			(wr_en					), // input wire wr_en
	  .rd_en			(mac_to_ddr_fifo_rd_en	), // input wire rd_en
	  .dout				(mac_to_ddr_fifo_dout	), // output wire [127 : 0] dout
	  .full				(						), // output wire full
	  .empty			(data_fifo_empty		), // output wire empty
	  .prog_full		(prog_full				), // output wire prog_full
	  .wr_rst_busy		(),  // output wire wr_rst_busy
	  .rd_rst_busy		()  // output wire rd_rst_busy
	);	 */
	
	assign mac_to_ddr_fifo_empty = data_fifo_empty;
	// User logic ends

//debug	
	assign debug_din = din;
	assign debug_wr_en = wr_en;
	assign debug_rd_en = mac_to_ddr_fifo_rd_en;
	assign debug_dout = mac_to_ddr_fifo_dout;
	assign debug_fifo_empty = data_fifo_empty;

	endmodule
