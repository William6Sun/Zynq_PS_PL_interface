`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2018/11/30 11:15:11
// Design Name: 
// Module Name: ctrl_interface
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


module ctrl_interface(
input wire				ddr_user_clk,
input wire				ddr_user_rst,
input wire [127:0]		cfg_data,
input wire				cfg_data_valid,
// 
input					I_sys_clk,//系统时钟
input					I_sys_rst_n,//系统复位
input [63:0]			I_cfg_value_rd_ddr,//�? DDR �?64位信�?
input					I_cfg_value_rd_ddr_valid,
output[127:0] 			sys_cfg_data,//配置信息
output					sys_cfg_data_valid,
//
output [63:0]			O_cfg_value_rd_ddr,
output wire				ddr_to_mac_start,
input  wire				ddr_to_mac_done,//M_AXI_ACLK
output wire				I_cfg_valid,
output wire [511:0]     I_cfg_value_wr_ddr
    );

//dealy 2 clk	
reg ddr_to_mac_done_reg_a;
reg ddr_to_mac_done_reg_b;
always @(posedge ddr_user_clk)begin
	if(ddr_user_rst)begin
		ddr_to_mac_done_reg_a <= 0;
		ddr_to_mac_done_reg_b <= 0;
	end
	else begin
		ddr_to_mac_done_reg_a <= ddr_to_mac_done;
		ddr_to_mac_done_reg_b <= ddr_to_mac_done_reg_a;
	end
end
wire w_ddr_to_mac_done = ddr_to_mac_done_reg_b;
	
//delay 1 clk
reg [127:0]cfg_data_reg_a;
reg cfg_data_valid_reg_a;
reg [2:0]cfg_value_wr_ddr_cnt;
always @(posedge ddr_user_clk)begin
	if(ddr_user_rst)begin
		cfg_value_wr_ddr_cnt <= 0;
	end
	else if(w_ddr_to_mac_done)begin
		cfg_value_wr_ddr_cnt <= 0;
	end
	else if(cfg_value_wr_ddr_cnt==4)begin
		cfg_value_wr_ddr_cnt <= cfg_value_wr_ddr_cnt;
	end
	else if(cfg_data_valid_reg_a)begin
		cfg_value_wr_ddr_cnt <= cfg_value_wr_ddr_cnt + 1;
	end
end

always @(posedge ddr_user_clk)begin
	if(ddr_user_rst)begin
		cfg_data_reg_a 			<= 0;
		cfg_data_valid_reg_a	<= 0;
	end
	else begin
		cfg_data_reg_a 			<= cfg_data;
		cfg_data_valid_reg_a	<= cfg_data_valid;
	end
end

reg [511:0] cfg_value_wr_ddr;
always @(posedge ddr_user_clk)begin
	if(ddr_user_rst)begin
		cfg_value_wr_ddr <= 0;
	end
	else if(w_ddr_to_mac_done)begin
		cfg_value_wr_ddr <= 0;
	end
	else if(cfg_value_wr_ddr_cnt<=3)begin
		cfg_value_wr_ddr <= {cfg_value_wr_ddr[383:0],cfg_data_reg_a};
	end
end

assign I_cfg_value_wr_ddr = cfg_value_wr_ddr;

reg cfg_value_wr_valid;
always @(posedge ddr_user_clk)begin
	if(ddr_user_rst)begin
		cfg_value_wr_valid <= 0;
	end
	else if(cfg_value_wr_ddr_cnt==3)begin
		cfg_value_wr_valid <= 1;	
	end
	else begin
		cfg_value_wr_valid <= 0;
	end
end

assign I_cfg_valid = cfg_value_wr_valid;
//1 clk
wire w_fifo_wr_en;
wire [127:0] w_fifo_din;
wire w_fifo_rd_en;
wire [127:0] w_fifo_dout;
wire w_fifo_empty;
wire w_fifo_prog_full;

assign w_fifo_wr_en = (cfg_value_wr_ddr_cnt==4) && cfg_data_valid_reg_a && ~w_fifo_prog_full;
assign w_fifo_din = cfg_data_reg_a;
assign w_fifo_rd_en = ~w_fifo_empty;

fifo_generator_4 main_ctrl_128x512_128x512 (
  .wr_clk(ddr_user_clk),        // input wire wr_clk
  .rd_clk(I_sys_clk),        // input wire rd_clk
  .din(w_fifo_din),              // input wire [127 : 0] din
  .wr_en(w_fifo_wr_en),          // input wire wr_en
  .rd_en(w_fifo_rd_en),          // input wire rd_en
  .dout(w_fifo_dout),            // output wire [127 : 0] dout
  .full(),            // output wire full
  .empty(w_fifo_empty),          // output wire empty
  .prog_full(w_fifo_prog_full)  // output wire prog_full
);	
	
assign sys_cfg_data = w_fifo_dout;	
	
reg sys_cfg_data_valid_reg_a;
reg sys_cfg_data_valid_reg_b;
always @(posedge I_sys_clk)begin
	if(I_sys_rst_n==0)begin
		sys_cfg_data_valid_reg_a <= 0;
		sys_cfg_data_valid_reg_b <= 0;
	end
	else begin
		sys_cfg_data_valid_reg_a <= w_fifo_rd_en;
		sys_cfg_data_valid_reg_b <= sys_cfg_data_valid_reg_a;
	end
end

assign sys_cfg_data_valid = sys_cfg_data_valid_reg_b;

//rd ddr
wire w_fifo_wr_en_1;
wire [63:0] w_fifo_din_1;
wire w_fifo_rd_en_1;
wire [63:0] w_fifo_dout_1;
wire w_fifo_empty_1;
wire w_fifo_full_1;

fifo_generator_0 save_cfg_value_64x16_64x16 (//distributed 分布式RAM
  .wr_clk(I_sys_clk),  // input wire wr_clk
  .rd_clk(ddr_user_clk),  // input wire rd_clk
  .din(w_fifo_din_1),        // input wire [63 : 0] din
  .wr_en(w_fifo_wr_en_1),    // input wire wr_en
  .rd_en(w_fifo_rd_en_1),    // input wire rd_en
  .dout(w_fifo_dout_1),      // output wire [63 : 0] dout
  .full(w_fifo_full_1),      // output wire full
  .empty(w_fifo_empty_1)    // output wire empty
);


reg [63:0]			I_cfg_value_rd_ddr_reg;
reg					I_cfg_value_rd_ddr_valid_reg;
always @(posedge I_sys_clk)begin
	if(I_sys_rst_n==0)begin
		I_cfg_value_rd_ddr_reg <= 0;
		I_cfg_value_rd_ddr_valid_reg <= 0;
	end
	else begin
		I_cfg_value_rd_ddr_reg <= I_cfg_value_rd_ddr;
		I_cfg_value_rd_ddr_valid_reg <= I_cfg_value_rd_ddr_valid;
	end
end

assign w_fifo_wr_en_1 = I_cfg_value_rd_ddr_valid_reg && ~w_fifo_full_1;
assign w_fifo_din_1 = I_cfg_value_rd_ddr_reg;
assign w_fifo_rd_en_1 = ~w_fifo_empty_1;

reg ddr_to_mac_start_reg;
always @(posedge ddr_user_clk)begin
	if(ddr_user_rst)begin
		ddr_to_mac_start_reg <= 0;
	end
	else if(w_fifo_rd_en_1)begin
		ddr_to_mac_start_reg <= 1;
	end
	else begin
		ddr_to_mac_start_reg <= 0;
	end
end

assign ddr_to_mac_start = ddr_to_mac_start_reg;
assign O_cfg_value_rd_ddr = w_fifo_dout_1;


// assign ddr_to_mac_start = ddr_to_mac_start_a && (~ddr_to_mac_start_b);
// assign O_cfg_value_rd_ddr = (ddr_to_mac_start)?{32'h0000_0040,32'h0100_0000}:0;//64 1-1024

	
endmodule
