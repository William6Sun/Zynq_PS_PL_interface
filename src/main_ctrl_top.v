`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2018/11/30 11:14:44
// Design Name: 
// Module Name: main_ctrl_top
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


module main_ctrl_top(
//-------------------clk and reset ------------------//
input						I_sys_clk           ,    
input						I_sys_rst_n         ,
input wire					ddr_user_clk		,
input wire					ddr_user_rst		,

//-----------------configuration input-----------------//
//-------------connection with Top Interface------------//
// input		[127:0]			I_cfg_value			,   //Configuration information from PS
// input						I_cfg_valid			,
input                       I_mac_to_ddr_done   ,
input                       I_ddr_to_mac_done   ,
// output 	 [63:0]			    O_cfg_rd_ddr		,    //configuration for reading data from DDR 
// output 					    O_cfg_rd_ddr_valid  ,

//-------------connection with algo_ctrl_top------------//

output wire                  O_SPMV_sel			,   //0 表示LSTM,FC; 1 表示CNN;
//-------------connection with lstm_FC_top------------//

output wire			        O_mode_sel			,	//选择进行lstm还是fc层的运算，mode=0,为lstm;mode=1,为fc

//-------------connection with FC_ctrl------------//

input                       I_FC_cal_done		,
output wire		[511:0]		O_FC_cfg_value		,
output wire					O_FC_cfg_valid		,
output wire					O_FC_cal_start		,

output wire				    O_fc_relu_en		,	//�?后一层不�?要relu，最后一层拉�?
//-------------connection with CNN_ctrl------------//
input                       I_CNN_cal_done		,
output wire		[511:0]		O_CNN_cfg_value		,
output wire					O_CNN_cfg_valid		,
output wire					O_CNN_cal_start		,


//-------------connection with LSTM_ctrl------------//
input                       I_LSTM_cal_done		,
output wire		[511:0]		O_LSTM_cfg_value	,		
output wire					O_LSTM_cfg_valid	,
output wire					O_LSTM_cal_start	,

//===============control the top interface
input wire [127:0]			I_cfg_data			,//from s00 
input wire					I_cfg_data_valid	,

output [63:0]				O_cfg_value_rd_ddr	,//�? data ctrl new
output wire					ddr_to_mac_start	,
output wire					I_cfg_valid			,
output wire [511:0]    		I_cfg_value_wr_ddr ,

//debug 信号
output wire					MC_algo_cfg_done_debug,
output wire					cal_start_debug		,
output wire					MC_mac_to_ddr_done_debug,
output wire					MC_task_done_debug	,
output wire					MC_result_done_debug,
output wire		[2:0]		cur_state_debug,

output wire [127:0]   		cfg_bf_reg_debug ,
output wire [6:0]     		bf_addr_cnt_debug,
output wire           		bf_wr_valid_debug,
output wire     	  		next_layer_cfg_start_debug,
output wire           		wr_buffer_en_debug,
output wire [6:0]     		bf_addr_debug,
output wire [127:0]   		bf_data_in_debug,
output wire [511:0]   		bf_data_out_debug,
output wire       	  		cur_algo_cfg_done_debug,
output wire           		algo_select_start_debug,
output wire					algo_cal_start_debug, 
output wire                 MC_layer_cal_done_debug,
output wire                 last_layer_debug


    );
	
wire [127:0]sys_cfg_data ;
wire sys_cfg_data_valid	 ;
wire [63:0]O_cfg_rd_ddr  ;  
wire O_cfg_rd_ddr_valid  ;

main_controller	control_0(
	.I_sys_clk           			(I_sys_clk           			),    
	.I_sys_rst_n         			(I_sys_rst_n         			),
	.ddr_user_clk					(ddr_user_clk					),
	.ddr_user_rst					(ddr_user_rst					),
	
	.I_cfg_value					(sys_cfg_data					),   //Configuration information from PS
	.I_cfg_valid					(sys_cfg_data_valid				),
	.I_mac_to_ddr_done    			(I_mac_to_ddr_done    			),
	.I_ddr_to_mac_done    			(I_ddr_to_mac_done    			),
	.O_cfg_rd_ddr					(O_cfg_rd_ddr					),    //configuration for reading data from DDR 
	.O_cfg_rd_ddr_valid  			(O_cfg_rd_ddr_valid  			),
	
	.O_SPMV_sel						(O_SPMV_sel						),   //0 表示LSTM,FC; 1 表示CNN;
	.O_mode_sel						(O_mode_sel						),	//选择进行lstm还是fc层的运算，mode=0,为lstm;mode=1,为fc
	.I_FC_cal_done					(I_FC_cal_done					),
	.O_FC_cfg_value					(O_FC_cfg_value					),
	.O_FC_cfg_valid					(O_FC_cfg_valid					),
	.O_FC_cal_start					(O_FC_cal_start					),
	.O_fc_relu_en					(O_fc_relu_en					),	//�?后一层不�?要relu，最后一层拉�?
	.I_CNN_cal_done					(I_CNN_cal_done					),
	.O_CNN_cfg_value				(O_CNN_cfg_value				),
	.O_CNN_cfg_valid				(O_CNN_cfg_valid				),
	.O_CNN_cal_start				(O_CNN_cal_start				),
	.I_LSTM_cal_done				(I_LSTM_cal_done				),
	.O_LSTM_cfg_value				(O_LSTM_cfg_value				),		
	.O_LSTM_cfg_valid				(O_LSTM_cfg_valid				),
	.O_LSTM_cal_start				(O_LSTM_cal_start				),
	.MC_algo_cfg_done_debug        (MC_algo_cfg_done_debug),
    .cal_start_debug                 (cal_start_debug),
    .MC_mac_to_ddr_done_debug       (MC_mac_to_ddr_done_debug),
    .MC_task_done_debug              (MC_task_done_debug),
    .MC_result_done_debug           (MC_result_done_debug),
    .cur_state_debug                (cur_state_debug),
	
 	.cfg_bf_reg_debug                  (cfg_bf_reg_debug             ),
   	.bf_addr_cnt_debug                 (bf_addr_cnt_debug            ),
    .bf_wr_valid_debug                 (bf_wr_valid_debug            ),
   	.next_layer_cfg_start_debug        (next_layer_cfg_start_debug   ),
    .wr_buffer_en_debug                (wr_buffer_en_debug           ),
	.bf_addr_debug                     (bf_addr_debug                ),
	.bf_data_in_debug                  (bf_data_in_debug             ),
	.bf_data_out_debug                 (bf_data_out_debug            ),
    .cur_algo_cfg_done_debug           (cur_algo_cfg_done_debug      ),
    .algo_select_start_debug           (algo_select_start_debug      ),
	.algo_cal_start_debug              (algo_cal_start_debug         ),
    .MC_layer_cal_done_debug           (MC_layer_cal_done_debug      ),
    .last_layer_debug	               (last_layer_debug	          )
	
	
    );
	
ctrl_interface	control_1(
	.ddr_user_clk					(ddr_user_clk					),
	.ddr_user_rst					(ddr_user_rst					),
	.I_sys_clk						(I_sys_clk						),
	.I_sys_rst_n					(I_sys_rst_n					),	
	
	.cfg_data						(I_cfg_data						),
	.cfg_data_valid					(I_cfg_data_valid				),
	.I_cfg_value_rd_ddr				(O_cfg_rd_ddr					),//�? DDR �?64位信�?
	.I_cfg_value_rd_ddr_valid		(O_cfg_rd_ddr_valid				),
	.sys_cfg_data					(sys_cfg_data					),//配置信息
	.sys_cfg_data_valid				(sys_cfg_data_valid				),
	
	.O_cfg_value_rd_ddr				(O_cfg_value_rd_ddr				),
	.ddr_to_mac_start				(ddr_to_mac_start				),
	.ddr_to_mac_done				(I_ddr_to_mac_done				),//M_AXI_ACLK
	.I_cfg_valid					(I_cfg_valid					),
	.I_cfg_value_wr_ddr				(I_cfg_value_wr_ddr				)
    );	
	
	
	

endmodule
