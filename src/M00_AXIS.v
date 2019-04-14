`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/01/02 10:23:01
// Design Name: 
// Module Name: M00_AXIS
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module M00_AXIS(
		input      			  ddr_user_clk				,
		input                 ddr_user_rstn             ,
		input      		      ddr_to_mac_data_valid		,//用于控制wr_en 一次8个数据
		input  [127:0]   	  ddr_to_mac_data			,//	
		output                ddr_to_mac_rd_en ,
		output				  ddr_to_mac_done,		   //m_axis_aclk
		input                 ddr_to_mac_start            ,//总控制器给 DDR到MAC传输开始
		input  [63:0]	      I_cfg_value_rd_ddr			,
		input				  cfg_rd_end_flag   ,
		//	
		input wire  M_AXIS_ACLK,
		input wire  M_AXIS_ARESETN,
		output wire  M_AXIS_TVALID,
		output wire [31 : 0] M_AXIS_TDATA,
		output wire [3: 0] M_AXIS_TKEEP,
		output wire  M_AXIS_TLAST,
		input wire  M_AXIS_TREADY,
		
		//debug ddr_user_clk
		output wire       debug_ddr_to_mac_data_valid,
		output wire       debug_rd_en,
		output wire       debug_fifo_prog_full,	
		output wire       debug_fifo_wr_en,
		output wire [31:0]debug_rd_cnt_3,		
		output wire [31:0]debug_wr_cnt_3,
		output wire       debug_ddr_to_mac_rd_en,
		output wire[127:0]debug_fifo_din,
		
		output wire [1:0] debug_cfg_rd_cnt,		
		output wire       debug_fifo_rd_en,
		output wire       debug_fifo_empty,
		output wire [31:0]debug_fifo_dout,	
		output wire       debug_rd_begin,
		output wire [31:0]debug_wr_cnt_2,
		output wire [31:0]debug_rd_cnt_2,
		output wire       debug_s_axis_tready,
		output wire       debug_s_axis_tvalid,
		output wire [31:0]debug_s_axis_tdata,
		output wire       debug_s_axis_tlast,	
		//M_AXIS_ACLK
		output wire [31:0]debug_rd_data_count,
		output wire       debug_ddr_to_mac_done
		
    );
	
reg [31:0] rd_data_count;
wire s_axis_tvalid;
wire [31:0] s_axis_tdata;
wire s_axis_tready;
wire s_axis_tlast;

//=========== 加上握手信号
reg cfg_rd_end_flag_a,cfg_rd_end_flag_b;	
always @(posedge ddr_user_clk)begin
	if(ddr_user_rstn==0)begin
		cfg_rd_end_flag_a <= 0;
		cfg_rd_end_flag_b <= 0;
	end
	else if(s_axis_tready)begin
		cfg_rd_end_flag_a <= cfg_rd_end_flag;//如果 ready 一直在就直接是1 
		cfg_rd_end_flag_b <= cfg_rd_end_flag_a;
	end
end

reg [31:0] back_data;
reg [1:0] back_data_cnt;
reg back_data_valid;
reg back_data_valid_buf;
always @(posedge ddr_user_clk)begin
	if(ddr_user_rstn==0)begin
		back_data_valid <= 0;
	end
	else if(cfg_rd_end_flag_b)begin
		back_data_valid <= 1;
	end
	else if(back_data_cnt==3)begin
		back_data_valid <= 0;
	end
	else begin
		back_data_valid <= back_data_valid;
	end
end

always @(posedge ddr_user_clk)begin
	if(ddr_user_rstn==0)begin
		back_data_valid_buf <= 0;
	end
	else begin
		back_data_valid_buf <= back_data_valid;
	end
end

always @(posedge ddr_user_clk)begin
	if(ddr_user_rstn==0)begin
		back_data_cnt <= 0;
	end
	else if(back_data_cnt==3)begin
		back_data_cnt <= 0;
	end
	else if(back_data_valid)begin
		back_data_cnt <= back_data_cnt + 1;
	end
	else begin
		back_data_cnt <= back_data_cnt;
	end
end

always @(posedge ddr_user_clk)begin
	if(ddr_user_rstn==0)begin
		back_data <= 0;
	end
	else case(back_data_cnt)
		0:back_data <= 32'hffff_0000;
		1:back_data <= 32'h0000_ffff;
		2:back_data <= 32'hff00_00ff;
		3:back_data <= 32'hffff_ffff;
		default:back_data <= 0;
	endcase
end
reg cfg_last;
always @(posedge ddr_user_clk)begin
	if(ddr_user_rstn==0)begin
		cfg_last <= 0;
	end
	else if(s_axis_tready && (back_data_cnt==3))begin
		cfg_last <= 1;
	end
	else begin
		cfg_last <= 0;
	end
end

////============================================
reg [31:0]wr_data_count;
always @(posedge ddr_user_clk)begin
	if(ddr_user_rstn==0)begin
		wr_data_count <= 0;
	end
	else if(ddr_to_mac_done)begin
		wr_data_count <= 0;
	end
	else if(s_axis_tvalid&&s_axis_tready)begin	
		wr_data_count <= wr_data_count + 1;
	end
end

wire [128:0]fifo_din;
wire [31:0]fifo_dout;
wire       fifo_wr_en;
wire       fifo_rd_en;
wire       fifo_empty;
wire       fifo_prog_full;

////=====================================
reg [31:0] DDR2TEMAC_TRANSFER_NUM		;
always @(posedge ddr_user_clk)begin
	if(ddr_user_rstn==0)begin
		DDR2TEMAC_TRANSFER_NUM	<= 'b0;
	end
	else if(ddr_to_mac_start)begin
		DDR2TEMAC_TRANSFER_NUM	<= I_cfg_value_rd_ddr[63:32];		
	end
	else begin
		DDR2TEMAC_TRANSFER_NUM	<= DDR2TEMAC_TRANSFER_NUM;		
	end
end

reg [31:0] from_ddr_data_cnt;
reg [31:0] fifo_wr_valid_cnt;
always @(posedge ddr_user_clk)begin
	if(ddr_user_rstn==0)begin
		from_ddr_data_cnt <= 0;
	end
	else if(ddr_to_mac_done)begin
		from_ddr_data_cnt <= 0;
	end
	else if(ddr_to_mac_data_valid)begin
		from_ddr_data_cnt <= from_ddr_data_cnt + 1;
	end
end

always @(posedge ddr_user_clk)begin
	if(ddr_user_rstn==0)begin	
		fifo_wr_valid_cnt <= 0;
	end
	else if(ddr_to_mac_done)begin
		fifo_wr_valid_cnt <= 0;
	end
	else if(fifo_wr_en)begin
		fifo_wr_valid_cnt <= fifo_wr_valid_cnt + 1;
	end
end

reg [127:0] save_rd_data [2043:0];
reg [10:0] wr_cnt_3;
reg [10:0] rd_cnt_3;
always @(posedge ddr_user_clk)begin
	if(ddr_user_rstn==0)begin
		save_rd_data[wr_cnt_3] <= 0;
	end
	else if(ddr_to_mac_data_valid)begin
		save_rd_data[wr_cnt_3] <= ddr_to_mac_data;
	end
	else begin
		save_rd_data[wr_cnt_3] <= 0;
	end
end
always @(posedge ddr_user_clk)begin
	if(ddr_user_rstn==0)begin
		wr_cnt_3 <= 0;
	end
	else if(ddr_to_mac_data_valid)begin
		wr_cnt_3 <= wr_cnt_3 + 1;
	end
	else if(rd_cnt_3==(wr_cnt_3-1)&&fifo_wr_en)begin
		wr_cnt_3 <= 0;
	end
end

assign ddr_to_mac_rd_en = (wr_cnt_3<2000)?1:0;

reg rd_en;
always @(posedge ddr_user_clk)begin
	if(ddr_user_rstn==0)begin
		rd_en <= 0;
	end
	else if(fifo_wr_valid_cnt==4*DDR2TEMAC_TRANSFER_NUM-1)begin
		rd_en <= 0;
	end
	else if(rd_cnt_3==(wr_cnt_3-1)&&fifo_wr_en)begin
		rd_en <= 0;
	end
	else if((wr_cnt_3>=2000)||(from_ddr_data_cnt==4*DDR2TEMAC_TRANSFER_NUM-1))begin
		rd_en <= 1;
	end
end

always @(posedge ddr_user_clk)begin
	if(ddr_user_rstn==0)begin
		rd_cnt_3 <= 0;
	end
	else if(rd_cnt_3==(wr_cnt_3-1)&&fifo_wr_en)begin
		rd_cnt_3 <= 0;
	end
	else if(fifo_wr_en)begin
		rd_cnt_3 <= rd_cnt_3 + 1;
	end
end

assign fifo_din = save_rd_data[rd_cnt_3];
assign fifo_wr_en = rd_en && (~fifo_prog_full);


////=====================================

fifo_generator_0 temp_128x4096_32x16384 (
  .clk(ddr_user_clk),              // input wire clk
  .din(fifo_din),              // input wire [127 : 0] din
  .wr_en(fifo_wr_en),          // input wire wr_en
  .rd_en(fifo_rd_en),          // input wire rd_en
  .dout(fifo_dout),            // output wire [31 : 0] dout
  .full(),            // output wire full
  .empty(fifo_empty),          // output wire empty
  .prog_full(fifo_prog_full)  // output wire prog_full
);
assign fifo_rd_en = s_axis_tready && (~fifo_empty);

reg fifo_rd_valid_a;
reg fifo_rd_valid_b;
always @(posedge ddr_user_clk)begin
	if(ddr_user_rstn==0)begin
		fifo_rd_valid_a <= 0;
		fifo_rd_valid_b <= 0;
	end
	else begin
		fifo_rd_valid_a <= fifo_rd_en;
		fifo_rd_valid_b <= fifo_rd_valid_a;
	end
end

reg [31:0] save_fifo_data [4095:0];
reg [11:0] rd_cnt;
reg [31:0] rd_cnt_2;
reg [11:0] wr_cnt;
reg [31:0] wr_cnt_2;

reg [1:0] cfg_rd_cnt;
always @(posedge ddr_user_clk)begin
	if(ddr_user_rstn==0)begin	
		cfg_rd_cnt <= 0;
	end
	else if(ddr_to_mac_done)begin
		cfg_rd_cnt <= 0;
	end
	else if(cfg_rd_cnt==3)begin
		cfg_rd_cnt <= cfg_rd_cnt;
	end
	else if(s_axis_tvalid&&s_axis_tready)begin
		cfg_rd_cnt <= cfg_rd_cnt + 1;
	end
end

always @(posedge ddr_user_clk)begin
	if(ddr_user_rstn==0)begin
		wr_cnt <= 0;
		wr_cnt_2 <= 0;
	end
	else if(ddr_to_mac_done)begin
		wr_cnt <= 0;
		wr_cnt_2 <= 0;
	end
	else if(fifo_rd_valid_b)begin
		wr_cnt_2 <= wr_cnt_2 + 1;
		wr_cnt <= wr_cnt + 1;
	end
end
	
always @(posedge ddr_user_clk)begin
	if(ddr_user_rstn==0)begin
		save_fifo_data[wr_cnt] <= 0;
	end
	else if(fifo_rd_valid_b)begin
		save_fifo_data[wr_cnt] <= fifo_dout;
	end
end

reg rd_begin;
always @(posedge ddr_user_clk)begin
	if(ddr_user_rstn==0)begin
		rd_begin <= 0;
	end
	else if(ddr_to_mac_done)begin
		rd_begin <= 0;
	end
	else if(s_axis_tvalid&&s_axis_tready&&(cfg_rd_cnt==3))begin
		rd_begin <= 1;
	end
end

always @(posedge ddr_user_clk)begin
	if(ddr_user_rstn==0)begin
		rd_cnt <= 0;
		rd_cnt_2 <= 0;
	end
	else if(ddr_to_mac_done)begin
		rd_cnt <= 0;
		rd_cnt_2 <= 0;
	end
	else if(s_axis_tvalid&&s_axis_tready&&rd_begin)begin
		rd_cnt <= rd_cnt + 1;
		rd_cnt_2 <= rd_cnt_2 + 1;
	end
	else begin
		rd_cnt <= rd_cnt;
		rd_cnt_2 <=  rd_cnt_2;
	end
end

reg packct_last;
reg [31:0] ddr_to_mac_transfer_num;
always @(posedge ddr_user_clk)begin	
	if(ddr_user_rstn==0)begin
		packct_last <= 0;
	end
	else if(s_axis_tvalid&&s_axis_tready&&s_axis_tlast)begin
		packct_last <= 0;
	end
	else if((s_axis_tvalid&&s_axis_tready&&(wr_data_count==(16*ddr_to_mac_transfer_num+2))))begin///
		packct_last <= 1;
	end
end
assign s_axis_tvalid = (back_data_valid_buf || (wr_cnt_2>=(rd_cnt_2+1))) && s_axis_tready;
assign s_axis_tdata  = (s_axis_tready && back_data_valid_buf) ? back_data : save_fifo_data[rd_cnt][31:0];
assign s_axis_tlast = cfg_last || (s_axis_tvalid&&s_axis_tready&&packct_last);

axis_data_fifo_0 m00_32x4096_32x4096 (
  .s_axis_aresetn  (ddr_user_rstn),          // input wire s_axis_aresetn
  .m_axis_aresetn  (M_AXIS_ARESETN),          // input wire m_axis_aresetn
  .s_axis_aclk    (ddr_user_clk),                // input wire s_axis_aclk
  .s_axis_tvalid  (s_axis_tvalid),            // input wire s_axis_tvalid
  .s_axis_tready  (s_axis_tready),            // output wire s_axis_tready
  .s_axis_tdata  (s_axis_tdata),              // input wire [31 : 0] s_axis_tdata
  .s_axis_tkeep  (4'hf),              		  // input wire [3 : 0] s_axis_tkeep
  .s_axis_tlast  (s_axis_tlast),              // input wire s_axis_tlast
  .m_axis_aclk   (M_AXIS_ACLK),                // input wire m_axis_aclk
  .m_axis_tvalid (M_AXIS_TVALID),            // output wire m_axis_tvalid
  .m_axis_tready (M_AXIS_TREADY),            // input wire m_axis_tready
  .m_axis_tdata  (M_AXIS_TDATA),              // output wire [31 : 0] m_axis_tdata
  .m_axis_tkeep  (M_AXIS_TKEEP),              // output wire [3 : 0] m_axis_tkeep
  .m_axis_tlast  (M_AXIS_TLAST),              // output wire m_axis_tlast
  .axis_data_count(),        // output wire [31 : 0] axis_data_count
  .axis_wr_data_count(),  // output wire [31 : 0] axis_wr_data_count
  .axis_rd_data_count()  // output wire [31 : 0] axis_rd_data_count
);

//
wire w_fifo_wr_en_1;
wire [63:0] w_fifo_din_1;
wire w_fifo_rd_en_1;
wire [63:0] w_fifo_dout_1;
wire w_fifo_empty_1;
wire w_fifo_full_1;

fifo_generator_1 save_cfg_value_64x16_64x16 (//distributed 分布式RAM
  .wr_clk(ddr_user_clk),  // input wire wr_clk
  .rd_clk(M_AXIS_ACLK),  // input wire rd_clk
  .din(w_fifo_din_1),        // input wire [63 : 0] din
  .wr_en(w_fifo_wr_en_1),    // input wire wr_en
  .rd_en(w_fifo_rd_en_1),    // input wire rd_en
  .dout(w_fifo_dout_1),      // output wire [63 : 0] dout
  .full(w_fifo_full_1),      // output wire full
  .empty(w_fifo_empty_1)    // output wire empty
);

reg [63:0]			I_cfg_value_rd_ddr_reg;
reg					I_cfg_value_rd_ddr_valid_reg;
always @(posedge ddr_user_clk)begin
	if(ddr_user_rstn==0)begin
		I_cfg_value_rd_ddr_reg <= 0;
		I_cfg_value_rd_ddr_valid_reg <= 0;
	end
	else begin
		I_cfg_value_rd_ddr_reg <= I_cfg_value_rd_ddr;
		I_cfg_value_rd_ddr_valid_reg <= ddr_to_mac_start;
	end
end

assign w_fifo_wr_en_1 = I_cfg_value_rd_ddr_valid_reg && ~w_fifo_full_1;
assign w_fifo_din_1 = I_cfg_value_rd_ddr_reg;
assign w_fifo_rd_en_1 = ~w_fifo_empty_1;

reg cfg_data_valid_a;
always @(posedge M_AXIS_ACLK)begin
	if(M_AXIS_ARESETN==0)begin
		cfg_data_valid_a <= 0;
	end
	else begin
		cfg_data_valid_a <= w_fifo_rd_en_1;
	end
end

always @(posedge M_AXIS_ACLK)begin
	if(M_AXIS_ARESETN==0)begin
		ddr_to_mac_transfer_num <= 0;
	end
	else if(ddr_to_mac_done)begin
		ddr_to_mac_transfer_num <= 0;
	end
	else if(cfg_data_valid_a)begin
		ddr_to_mac_transfer_num <= w_fifo_dout_1[63:32];
	end
end	

always @(posedge M_AXIS_ACLK)begin
	if(M_AXIS_ARESETN==0)begin
		rd_data_count <= 0;
	end
	else if(ddr_to_mac_done)begin
		rd_data_count <= 0;
	end
	else if(M_AXIS_TVALID&&M_AXIS_TREADY)begin
		rd_data_count <= rd_data_count + 1;
	end
end

wire not_done = (rd_data_count==3)?0:1;
reg ddr_to_mac_done_reg;
always @(posedge M_AXIS_ACLK)begin	
	if(M_AXIS_ARESETN==0)begin
		ddr_to_mac_done_reg <= 0;
	end
	else if(not_done && (M_AXIS_TVALID&&M_AXIS_TREADY&&(rd_data_count==(16*ddr_to_mac_transfer_num+3))))begin
		ddr_to_mac_done_reg <= 1;
	end
	else begin
		ddr_to_mac_done_reg <= 0;
	end
end

assign ddr_to_mac_done = ddr_to_mac_done_reg;

//debug
assign debug_ddr_to_mac_data_valid = ddr_to_mac_data_valid;
assign debug_fifo_wr_en            = fifo_wr_en;
assign debug_rd_cnt_3	           = rd_cnt_3;		
assign debug_wr_cnt_3              = wr_cnt_3;
assign debug_ddr_to_mac_rd_en      = ddr_to_mac_rd_en;
assign debug_fifo_din              = fifo_din;                        
assign debug_rd_en                 = rd_en;

assign debug_cfg_rd_cnt      = cfg_rd_cnt      ;
assign debug_fifo_rd_en      = fifo_rd_en;
assign debug_fifo_empty      = fifo_empty;
assign debug_fifo_dout       = fifo_dout;
assign debug_fifo_prog_full  = fifo_prog_full;
assign debug_rd_begin        = rd_begin  ;      
assign debug_wr_cnt_2        = wr_cnt_2     ;   
assign debug_rd_cnt_2        = rd_cnt_2     ;   
assign debug_s_axis_tready   = s_axis_tready  ; 
assign debug_s_axis_tvalid   = s_axis_tvalid ;  
assign debug_s_axis_tdata    = s_axis_tdata ;   
assign debug_s_axis_tlast    = s_axis_tlast  ;  
assign debug_rd_data_count   = rd_data_count  ; 
assign debug_ddr_to_mac_done = ddr_to_mac_done ;
		
endmodule


