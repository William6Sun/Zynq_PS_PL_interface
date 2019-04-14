`timescale 1ns / 1ps

module main_controller
(
//-------------------clk and reset ------------------//
input						I_sys_clk           ,    
input						I_sys_rst_n         ,
input wire					ddr_user_clk		,
input wire					ddr_user_rst		,

//-----------------configuration input-----------------//
//-------------connection with Top Interface------------//
input		[127:0]			I_cfg_value			,   //Configuration information from PS
input						I_cfg_valid			,


input                       I_mac_to_ddr_done    ,
input                       I_ddr_to_mac_done    ,


output 	 [63:0]			    O_cfg_rd_ddr		,    //configuration for reading data from DDR 
output 					    O_cfg_rd_ddr_valid  ,


//-------------connection with algo_ctrl_top------------//

output reg                  O_SPMV_sel			,   //0 表示LSTM,FC; 1 表示CNN;
//-------------connection with lstm_FC_top------------//

output reg			        O_mode_sel			,	//选择进行lstm还是fc层的运算，mode=0,为lstm;mode=1,为fc

//-------------connection with FC_ctrl------------//

input                       I_FC_cal_done		,
output reg		[511:0]		O_FC_cfg_value		,
output reg					O_FC_cfg_valid		,
output reg					O_FC_cal_start		,

output reg				    O_fc_relu_en		,	//�?后一层不�?要relu，最后一层拉�?
//-------------connection with CNN_ctrl------------//
input                       I_CNN_cal_done		,
output reg		[511:0]		O_CNN_cfg_value		,
output reg					O_CNN_cfg_valid		,
output reg					O_CNN_cal_start		,


//-------------connection with LSTM_ctrl------------//
input                       I_LSTM_cal_done		,
output reg		[511:0]		O_LSTM_cfg_value	,		
output reg					O_LSTM_cfg_valid	,
output reg					O_LSTM_cal_start	,

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
	
	
localparam	IDLE				=	3'b000	;//0
localparam	CONFIG				=	3'b001	;//1
localparam	DATA_PREPARE		=	3'b010	;//2
localparam	CAL          		=	3'b011	;//3
localparam	RESULT_READ			=	3'b100	;//4	
localparam	AlGO_CFG            =   3'b101	;//5 
	
reg	[2:0] cur_state = IDLE ;


wire         MC_algo_cfg_done  ;	
wire         MC_mac_to_ddr_done;   
wire         MC_layer_cal_done ;
wire         MC_task_done      ;   
wire         MC_result_done    ; 	

wire[3:1]    algo_select	;      
wire[8:4]    layer_num       ;   
wire         last_layer      ;   
wire[127:96] result_ddr_length;
wire[95:64]  result_ddr_addr  ;     


//配置寄存器和状�?�寄存器 
/* reg		[511:0] 	cfg_gmac_reg	=  0  ; */
reg		[511:0] 	cfg_algo_reg	=  0  ;  
reg		[31:0]		state_r	=  0  ;	

reg     algo_cfg_done;
reg     mac_to_ddr_done;
reg     layer_cal_done;
reg     task_done;
reg     result_done;




assign	MC_algo_cfg_done			=	state_r[2]	;
assign  MC_mac_to_ddr_done          =   state_r[3]  ;
assign	MC_layer_cal_done        	=	state_r[4]	;	
assign  MC_task_done                =   state_r[5]	;	
assign  MC_result_done              =   state_r[6]	;



assign	algo_select	            =	cfg_algo_reg[3:1];
assign  layer_num               =   cfg_algo_reg[8:4];
assign  last_layer              =   cfg_algo_reg[9];	
assign  result_ddr_length       =   cfg_algo_reg[127:96];	
assign  result_ddr_addr         =   cfg_algo_reg[95:64];

//dealy 2 clk
reg	ddr_to_mac_done_reg;	
reg ddr_to_mac_done_reg_a;
reg ddr_to_mac_done_reg_b;
reg	R_ddr_to_mac_done;
/*在系统时钟下可能采样不到I_ddr_to_mac_done信号，需要在ddr时钟下对该信号进行采�?
always @(posedge I_sys_clk)begin
	if(I_sys_rst_n==0)begin
		ddr_to_mac_done_reg_a <= 0;
		ddr_to_mac_done_reg_b <= 0;
	end
	else begin
		ddr_to_mac_done_reg_a <= I_ddr_to_mac_done;
		ddr_to_mac_done_reg_b <= ddr_to_mac_done_reg_a;
	end
end
*/
always@(posedge ddr_user_clk)begin
	if(ddr_user_rst)
		ddr_to_mac_done_reg <= 0;
	else if(R_ddr_to_mac_done)
		ddr_to_mac_done_reg <= 0;
	else if(I_ddr_to_mac_done)
		ddr_to_mac_done_reg <= 1;
	else
		ddr_to_mac_done_reg <= ddr_to_mac_done_reg;
end

always@(posedge I_sys_clk)begin
	if(!I_sys_rst_n)begin
		ddr_to_mac_done_reg_a <= 0;
		ddr_to_mac_done_reg_b <= 0;
	end
	else begin
		ddr_to_mac_done_reg_a <= ddr_to_mac_done_reg;
		ddr_to_mac_done_reg_b <= ddr_to_mac_done_reg_a;
	end
end

always@(posedge I_sys_clk)begin
	if(!I_sys_rst_n)
		R_ddr_to_mac_done <= 0;
	else
		R_ddr_to_mac_done <= ddr_to_mac_done_reg_a&(~ddr_to_mac_done_reg_b);
end

//状�?�寄存器的赋值与输出
always@(posedge I_sys_clk)begin
	if(!I_sys_rst_n | (cur_state == IDLE))
		state_r	<=	32'd0	;
	else if(R_ddr_to_mac_done)
	    state_r	<=	32'd0	;
	else
		state_r	<=	{25'd0,result_done,task_done,layer_cal_done,mac_to_ddr_done,algo_cfg_done,1'b0,1'b0};
end	

//dealy 2 clk
reg mac_to_ddr_done_reg;
reg mac_to_ddr_done_reg_a;
reg mac_to_ddr_done_reg_b;
reg R_mac_to_ddr_done;

/*
always @(posedge I_sys_clk)begin
	if(!I_sys_rst_n)begin
		mac_to_ddr_done_reg_a <= 0;
		mac_to_ddr_done_reg_b <= 0;
	end
	else begin
		mac_to_ddr_done_reg_a <= I_mac_to_ddr_done;
		mac_to_ddr_done_reg_b <= mac_to_ddr_done_reg_a;
	end
end
*/
always@(posedge ddr_user_clk)begin
	if(ddr_user_rst)
		mac_to_ddr_done_reg <= 0;
	else if(R_mac_to_ddr_done)
		mac_to_ddr_done_reg <= 0;
	else if(I_mac_to_ddr_done)
		mac_to_ddr_done_reg <= 1;
	else
		mac_to_ddr_done_reg <= mac_to_ddr_done_reg;
end

always@(posedge I_sys_clk)begin
	if(!I_sys_rst_n)begin
		mac_to_ddr_done_reg_a <= 0;
		mac_to_ddr_done_reg_b <= 0;
	end
	else begin
		mac_to_ddr_done_reg_a <= mac_to_ddr_done_reg;
		mac_to_ddr_done_reg_b <= mac_to_ddr_done_reg_a;
	end
end

always@(posedge I_sys_clk)begin
	if(!I_sys_rst_n)
		R_mac_to_ddr_done <= 0;
	else
		R_mac_to_ddr_done <= mac_to_ddr_done_reg_a&(~mac_to_ddr_done_reg_b);
end

/////计数19个配置信息，�?修改
reg [6:0]   gmac_param_cnt  =  7'd0  ; 
always@(posedge I_sys_clk)begin
	if(!I_sys_rst_n | (gmac_param_cnt == 75))
		 gmac_param_cnt	 <=	 7'd0 ;
	else if(R_ddr_to_mac_done)
		 gmac_param_cnt	 <=	 7'd0 ;
	else if(I_cfg_valid)
		 gmac_param_cnt	 <=	 gmac_param_cnt + 7'd1;
	else 
	     gmac_param_cnt	 <=	 gmac_param_cnt  ;
end	


  
//寄存算法配置信息

always@(posedge I_sys_clk)begin
	if(!I_sys_rst_n)
		 cfg_algo_reg	 <=	512'b0 ;
	else if(R_ddr_to_mac_done)
		cfg_algo_reg	 <=	512'b0 ;
	else if(I_cfg_valid & (gmac_param_cnt == 0))
		 cfg_algo_reg[511:384]	<=	 I_cfg_value  ;	
	else if(I_cfg_valid & (gmac_param_cnt == 1))
		 cfg_algo_reg[383:256]	<=	 I_cfg_value  ;
	else if(I_cfg_valid & (gmac_param_cnt == 2))
	     cfg_algo_reg[255:128]	<=	 I_cfg_value ;
	else if(I_cfg_valid & (gmac_param_cnt == 3))
	     cfg_algo_reg[127:0]    <=   I_cfg_value ;
    else if(bf_latency_cnt == 3)begin
	     cfg_algo_reg[511:384]   <=  bf_data_out[127:0]; //其他层配�?
		 cfg_algo_reg[383:256]   <=  bf_data_out[255:128]; 
		 cfg_algo_reg[255:128]   <=  bf_data_out[383:256]; 
		 cfg_algo_reg[127:0]   <=  bf_data_out[511:384]; //Bug修正：2018.12.29，ram输出的配置高低位反了
	end	
	else 
		 cfg_algo_reg   <=   cfg_algo_reg ;
end	


reg cur_algo_cfg_done; //第一层配置完�?

always@(posedge I_sys_clk)begin
	if(!I_sys_rst_n)
		cur_algo_cfg_done <= 0;
	else if (I_cfg_valid & (gmac_param_cnt == 4))	
		cur_algo_cfg_done <= 1;
	else if (bf_latency_cnt == 3)
		cur_algo_cfg_done <= 1;
	else
		cur_algo_cfg_done <=  0;
end



//存储算法层配置信息到片上SRAM
reg[127:0]   cfg_bf_reg ;
reg[6:0]     bf_addr_cnt;
reg          bf_wr_valid;
reg    next_layer_cfg_start;

wire         wr_buffer_en  ;	
wire[6:0]    bf_addr;
wire[127:0]  bf_data_in;
wire[511:0]  bf_data_out;

 
always@(posedge I_sys_clk)begin
	if(!I_sys_rst_n)
		 cfg_bf_reg  <=	128'b0 ;
	else if(R_ddr_to_mac_done)
		 cfg_bf_reg  <=	128'b0 ;
	else if(I_cfg_valid & (gmac_param_cnt > 3) & (gmac_param_cnt < 76))
		 cfg_bf_reg    <=   I_cfg_value ;
	else 
		 cfg_bf_reg   <=   cfg_bf_reg ;
end		


reg[1:0] addr_increase;
	
always@(posedge I_sys_clk)begin
	if(!I_sys_rst_n)
		  addr_increase  <=	0 ;
	else if(cur_algo_cfg_done & (addr_increase < 2) )
		  addr_increase  <=	addr_increase + 1 ;
	else if(R_ddr_to_mac_done )
		  addr_increase  <=	0 ;	
	else 
		  addr_increase  <=	addr_increase  ;
end		
	
always@(posedge I_sys_clk)begin
	if(!I_sys_rst_n)
		  bf_addr_cnt  <=	7'd0 ;
	else if(R_ddr_to_mac_done)
		  bf_addr_cnt  <=	7'd0 ;
	else if(I_cfg_valid & (gmac_param_cnt > 4) & (gmac_param_cnt < 76))
		  bf_addr_cnt  <=   bf_addr_cnt  +  7'd1 ;
	else if((cur_state == AlGO_CFG) &  next_layer_cfg_start & (addr_increase == 2) )
		  bf_addr_cnt  <=   bf_addr_cnt  +  7'd4 ;    //层计算完成，读取下一层配�?	
	else if((cur_state == DATA_PREPARE) & bf_addr_cnt ==  7'd71)
		  bf_addr_cnt  <=   7'd0;
	else 
		  bf_addr_cnt  <=   bf_addr_cnt ;
end	

always@(posedge I_sys_clk)begin
	if(!I_sys_rst_n)
		  bf_wr_valid  <=	0 ;
	else if(R_ddr_to_mac_done)
		  bf_wr_valid  <=	0 ;
	else if(I_cfg_valid & (gmac_param_cnt > 3) & (gmac_param_cnt < 76))
		  bf_wr_valid  <=   1 ;
	else 
		  bf_wr_valid  <=   0 ;
end	

  
//读取sram配置信息

reg[2:0]  bf_latency_cnt;

always@(posedge I_sys_clk)begin
	if(!I_sys_rst_n)
		bf_latency_cnt   <=	 0 ;
	else if(R_ddr_to_mac_done)
		bf_latency_cnt   <=	 0 ;
	else if((cur_state == AlGO_CFG) &  next_layer_cfg_start)
		bf_latency_cnt   <=  bf_latency_cnt  +  1 ;
	else if( (cur_state == AlGO_CFG) &  bf_latency_cnt > 0 & bf_latency_cnt < 4)  //未置�?
		bf_latency_cnt   <=  bf_latency_cnt  +  1 ;  
	else if( bf_latency_cnt == 4)
		bf_latency_cnt   <=	 0 ;	
	else
		bf_latency_cnt   <=  bf_latency_cnt;
end



assign	bf_data_in = cfg_bf_reg;
assign 	bf_addr =  bf_addr_cnt;
assign  wr_buffer_en = bf_wr_valid;

blk_mem_gen_0  cfg_buffer  
(
    .clka(I_sys_clk), // IN STD_LOGIC
    .wea(wr_buffer_en), //IN STD_LOGIC_VECTOR(0 DOWNTO 0)
    .addra(bf_addr),// IN STD_LOGIC_VECTOR(6 DOWNTO 0)
    .dina(bf_data_in), // IN STD_LOGIC_VECTOR(127 DOWNTO 0)
    .douta(bf_data_out) // OUT STD_LOGIC_VECTOR(511 DOWNTO 0)
  );
 

//配置算法控制器开始信�?  
reg algo_select_start;
reg algo_cal_start;


always@(posedge I_sys_clk)begin
	if(!I_sys_rst_n)
		 algo_select_start	<=	0;
	else if((cur_state  ==  CONFIG) & cur_algo_cfg_done)
		 algo_select_start  <=  1;
	else if((cur_state  ==  AlGO_CFG) & cur_algo_cfg_done)
		 algo_select_start  <=  1;
	else 
		 algo_select_start  <=  0 ;
end		

always@(posedge I_sys_clk)begin
	if(!I_sys_rst_n)
		 algo_cal_start	<=	0;
	else if((cur_state  ==  AlGO_CFG) & algo_select_start)
		 algo_cal_start  <=  1;
	else 
		 algo_cal_start  <=  0 ;
end	



//配置顶层控制�?


always@(posedge I_sys_clk)begin
	if(!I_sys_rst_n)	
		O_SPMV_sel <= 0;                        //0 表示LSTM,FC; 1 表示CNN;
	else if( algo_select_start & (algo_select == 3'b001))
		O_SPMV_sel <= 1;
	else if( algo_select_start & (algo_select == 3'b011 | algo_select == 3'b010 ))
		O_SPMV_sel <= 0;		
	else
		O_SPMV_sel <=  O_SPMV_sel;
end

always@(posedge I_sys_clk)begin
	if(!I_sys_rst_n)
		O_mode_sel	<= 0;	 
	else if(algo_select_start & (algo_select == 3'b010))//选择进行lstm还是fc层的运算，mode=0,为lstm;mode=1,为fc
		O_mode_sel	<= 1;
	else if(algo_select_start & (algo_select == 3'b011))
		O_mode_sel	<= 0;
	else 
		O_mode_sel	<=  O_mode_sel;
end 
		



//配置算法控制�?
always@(posedge I_sys_clk)begin
	if(!I_sys_rst_n)begin
		O_CNN_cfg_value <= 0;
		O_CNN_cfg_valid <= 0;
	end
	else if(algo_select_start & (algo_select == 3'b001))begin
		O_CNN_cfg_value <= cfg_algo_reg;
		O_CNN_cfg_valid <= 1;
	end
	else begin
		O_CNN_cfg_value <= 0;
		O_CNN_cfg_valid <= 0;
	end
end	


always@(posedge I_sys_clk)begin
	if(!I_sys_rst_n)begin
		O_FC_cfg_value <= 0;
		O_FC_cfg_valid <= 0;
	end
	else if(algo_select_start & (algo_select == 3'b010))begin
		O_FC_cfg_value <= cfg_algo_reg;
		O_FC_cfg_valid <= 1;	
	end
	else begin
		O_FC_cfg_value <= 0;
		O_FC_cfg_valid <= 0;
	end
end	


always@(posedge I_sys_clk)begin
	if(!I_sys_rst_n)
		O_fc_relu_en <= 0;
	else if (algo_select_start & (algo_select == 3'b010) & (!last_layer))  //�?后一层不�?要relu，最后一层拉�?
		O_fc_relu_en <= 1;
	else if (algo_select_start & (algo_select == 3'b010) & (last_layer))  //�?后一层不�?要relu，最后一层拉�?
		O_fc_relu_en <= 0;		
	else
		O_fc_relu_en <=  O_fc_relu_en;
end
	
	
always@(posedge I_sys_clk)begin
	if(!I_sys_rst_n)begin
		O_LSTM_cfg_value <= 0;
		O_LSTM_cfg_valid <= 0;
	end
	else if(algo_select_start & (algo_select == 3'b011))begin
		O_LSTM_cfg_value <= cfg_algo_reg;
		O_LSTM_cfg_valid <= 1;		 
	end
	else begin
		O_LSTM_cfg_value <= 0;
		O_LSTM_cfg_valid <= 0;
	end
end	


always@(posedge I_sys_clk)begin
	if(!I_sys_rst_n)
		 algo_cfg_done	<=	0;
	else if((cur_state  ==  CONFIG) & algo_select_start)
		 algo_cfg_done <=  1;
	else 
		 algo_cfg_done  <=  0 ;
end	






//等待数据全部存入DDR
always@(posedge I_sys_clk)begin
	if(!I_sys_rst_n)
		 mac_to_ddr_done	<=	0;
	else if(R_ddr_to_mac_done)
		 mac_to_ddr_done   <=  0;		  
	else if((cur_state  ==  DATA_PREPARE) & R_mac_to_ddr_done)
		 mac_to_ddr_done    <=  1;
	else 
		 mac_to_ddr_done   <=  mac_to_ddr_done ;
end	


//控制子算法控制器�?始运�?


always@(posedge I_sys_clk)begin
	if(!I_sys_rst_n)
	O_CNN_cal_start <= 0;	
	else if((cur_state  ==  DATA_PREPARE) & R_mac_to_ddr_done & (algo_select == 3'b001))
	O_CNN_cal_start <= 1;	
	else if((cur_state  == AlGO_CFG) & algo_cal_start    & (algo_select == 3'b001))
	O_CNN_cal_start <= 1;	
	else 
	O_CNN_cal_start <= 0;
end

always@(posedge I_sys_clk)begin
	if(!I_sys_rst_n)
	O_FC_cal_start <= 0;	
	else if((cur_state  ==  DATA_PREPARE) & R_mac_to_ddr_done  & (algo_select == 3'b010) )
	O_FC_cal_start <= 1;	
	else if((cur_state  == AlGO_CFG) & algo_cal_start  & (algo_select == 3'b010) )
	O_FC_cal_start <= 1;		
	else 
	O_FC_cal_start <= 0;
end

always@(posedge I_sys_clk)begin
	if(!I_sys_rst_n)
	O_LSTM_cal_start <= 0;	
	else if((cur_state  ==  DATA_PREPARE) & R_mac_to_ddr_done  & (algo_select == 3'b011))
	O_LSTM_cal_start <= 1;	
	else if((cur_state  == AlGO_CFG) & algo_cal_start  & (algo_select == 3'b011))
	O_LSTM_cal_start <= 1;	
	else 
	O_LSTM_cal_start <= 0;
end

wire cal_start;
assign cal_start = O_CNN_cal_start | O_FC_cal_start| O_LSTM_cal_start;

//等待计算完成

always@(posedge I_sys_clk)begin
	if(!I_sys_rst_n)
		 layer_cal_done	 <=	0;
	else if((I_FC_cal_done | I_CNN_cal_done | I_LSTM_cal_done) & (!last_layer))
		 layer_cal_done  <=  1;
	else
		 layer_cal_done  <=  0;
end	

always@(posedge I_sys_clk)begin
	if(!I_sys_rst_n)
		 task_done 		 <=  0;	
	else if((I_FC_cal_done | I_CNN_cal_done | I_LSTM_cal_done) & (last_layer))
		 task_done 		 <=  1;		 
	else
		 task_done 		 <=  0;	
end 		 
		 
//�?始下�?层配�?

always@(posedge I_sys_clk)begin
	if(!I_sys_rst_n)
		 next_layer_cfg_start  <=  0;
	else if(MC_layer_cal_done)
		 next_layer_cfg_start  <=  1;
	else 
		 next_layer_cfg_start  <=  0 ;
end




//任务结束，网口从DDR读数�?,配置网口控制器读地址

assign O_cfg_rd_ddr = (task_done)? {result_ddr_length,result_ddr_addr} :0;
assign O_cfg_rd_ddr_valid = (task_done)? 1:0;



//数据从DDR到网口传输结�?
always@(posedge I_sys_clk)begin
	if(!I_sys_rst_n)
		 result_done  <=  0;
	else if((cur_state == RESULT_READ) &  R_ddr_to_mac_done)
		 result_done  <=  1;
	else 
		 result_done  <=  0 ;
end




//debug 信号
assign MC_algo_cfg_done_debug = MC_algo_cfg_done;
assign cal_start_debug = cal_start;
assign MC_mac_to_ddr_done_debug = MC_mac_to_ddr_done;
assign MC_task_done_debug = MC_task_done;
assign MC_result_done_debug = MC_result_done;
assign MC_layer_cal_done_debug =  MC_layer_cal_done;
assign cur_state_debug = cur_state;

assign cfg_bf_reg_debug = cfg_bf_reg;
assign bf_addr_cnt_debug = bf_addr_cnt;
assign bf_wr_valid_debug = bf_wr_valid;
assign next_layer_cfg_start_debug = next_layer_cfg_start;
assign wr_buffer_en_debug = wr_buffer_en;	
assign bf_addr_debug = bf_addr;
assign bf_data_in_debug = bf_data_in;
assign bf_data_out_debug = bf_data_out;
assign cur_algo_cfg_done_debug = cur_algo_cfg_done; 
assign algo_select_start_debug = algo_select_start;
assign algo_cal_start_debug =  algo_cal_start;
assign last_layer_debug  =  last_layer;


//state_machine

always@(posedge I_sys_clk)begin
	if(!I_sys_rst_n)
		cur_state <= IDLE ;
	else begin 
		case(cur_state)
			IDLE	:begin
				if(I_cfg_valid )
					cur_state  <=  CONFIG  ;
				else
					cur_state  <=  IDLE    ;
			end
			CONFIG   :begin
				if(MC_algo_cfg_done)
					cur_state  <=  DATA_PREPARE ;

				else 
					cur_state  <=  CONFIG   ;
			end
			AlGO_CFG  :begin
				if (cal_start )
					cur_state  <=  	CAL	;
				else
					cur_state  <=  	AlGO_CFG	;
			end				
			DATA_PREPARE  :begin
				if(MC_mac_to_ddr_done)
					cur_state  <=  CAL  ;
				else
					cur_state  <=  DATA_PREPARE  ;			
			end	
			CAL   :begin
				if(MC_task_done)
					cur_state  <=  RESULT_READ  ;
				else if(MC_layer_cal_done )
					cur_state  <=  AlGO_CFG   ;
				else
					cur_state  <=  CAL  ;
			end			
			RESULT_READ   :begin
				if(MC_result_done)
					cur_state  <=  IDLE  ;					
				else 
					cur_state  <=  RESULT_READ  ;
			end
			default :   cur_state  <=  IDLE  ;		
		endcase
	end
end	
	
	
	
	
endmodule	
	
	
	
	

	

