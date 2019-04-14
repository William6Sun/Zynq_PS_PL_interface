 `timescale 1ns / 1ps
module data_ctrl_v2(

//configure signal
input	wire				I_cfg_valid					,//配置信号有效
input	wire [511:0]		I_cfg_value_wr_ddr			,//只进行配置一次
//system signal
input						ddr_user_clk				,
input						ddr_user_sync_rst			,

//mac_to_ddr interface
output     		            mac_to_ddr_fifo_rd_en		,
input  [127:0]   	        mac_to_ddr_fifo_dout		,	
input                       mac_to_ddr_fifo_empty		,

//ddr_to_mac interface
input						ddr_to_mac_rd_en	        ,
output						ddr_to_mac_data_valid		,  
output [127:0]				ddr_to_mac_data     		,

//ddr interface
input           	        init_calib_complete         ,//DDR初始化完成
input                       ddr_to_mac_start            ,//总控制器给 DDR到MAC传输开始
input  [63:0]				I_cfg_value_rd_ddr			,

output 				        mac_to_ddr_done			    ,//传输给总控制器 MAC到DDR传输完成 
                            
output [3:0]                c0_ddr4_s_axi_awid				,
output [2:0]                c0_ddr4_s_axi_awsize		   	,
output [1:0]                c0_ddr4_s_axi_awburst	    	,
output                      c0_ddr4_s_axi_awlock		    ,
output [3:0]                c0_ddr4_s_axi_awcache	    	,
output [2:0]                c0_ddr4_s_axi_awprot		    ,
output [3:0]                c0_ddr4_s_axi_awqos	            ,			 
output [15:0]				c0_ddr4_s_axi_wstrb			    ,
output 						c0_ddr4_s_axi_bready			,
output [3:0]                c0_ddr4_s_axi_arid				,
output [2:0]                c0_ddr4_s_axi_arsize		   	,
output [1:0]                c0_ddr4_s_axi_arburst	    	,
output                      c0_ddr4_s_axi_arlock			,
output [3:0]                c0_ddr4_s_axi_arcache	    	,
output [2:0]                c0_ddr4_s_axi_arprot		    ,
output [3:0]                c0_ddr4_s_axi_arqos			    , 


output wire [28 : 0] c0_ddr4_s_axi_awaddr         ,
output wire [7 : 0] c0_ddr4_s_axi_awlen           ,
output wire c0_ddr4_s_axi_awvalid                 ,
input wire c0_ddr4_s_axi_awready                  ,
output wire [127 : 0] c0_ddr4_s_axi_wdata         ,
output wire c0_ddr4_s_axi_wlast                   ,
output wire c0_ddr4_s_axi_wvalid                  ,
input wire c0_ddr4_s_axi_wready                   ,	

input wire [3 : 0] c0_ddr4_s_axi_bid              ,//unuse
input wire [1 : 0] c0_ddr4_s_axi_bresp            ,//
input wire         c0_ddr4_s_axi_bvalid           ,//	

output wire [28 : 0] c0_ddr4_s_axi_araddr         ,
output wire [7 : 0] c0_ddr4_s_axi_arlen           ,
output wire c0_ddr4_s_axi_arvalid                 ,
input wire c0_ddr4_s_axi_arready                  ,
output wire c0_ddr4_s_axi_rready                  ,
input wire c0_ddr4_s_axi_rlast                    ,
input wire c0_ddr4_s_axi_rvalid                   ,
input wire [1 : 0] c0_ddr4_s_axi_rresp            ,
input wire [3 : 0] c0_ddr4_s_axi_rid              ,
input wire [127 : 0] c0_ddr4_s_axi_rdata          ,  

//debug
output						debug_mac_to_ddr_start,
output						debug_cfg_valid,
output		[28:0]			debug_mac_data_transfer_cnt,
output						debug_s_wlast_mac_to_ddr,
output						debug_mac_to_ddr_start_reg,
output						debug_mac_to_ddr_done,        	
//output	[11:0]				debug_cnt_interval,
output						debug_last_valid,
output						debug_s_wvalid_mac_to_ddr_reg,
output                      debug_rd_en_b,
output  [31:0]              debug_wr_cnt_2,
output                      debug_s_wvalid_mac_to_ddr,
output						debug_s_wready_mac_to_ddr,
output  [31:0]              debug_rd_cnt_2,
output                      debug_w_ddr_to_mac_start,
output						debug_rd_to_top_fifo_en,
output  [127:0]             debug_save_data
    );

//assign ddr_to_mac_data_valid   = s_rvalid_ddr_to_mac;
	
assign c0_ddr4_s_axi_wstrb			=   16'hffff;
reg s_axi_bready;
always@(posedge ddr_user_clk)begin
	if(ddr_user_sync_rst)
		s_axi_bready <= 1'b0;
	else if(init_calib_complete)
		s_axi_bready <= 1'b1;
	else
		s_axi_bready <= s_axi_bready;
end		

wire [28:0]s_awaddr_mac_to_ddr;
wire s_awvalid_mac_to_ddr;         
wire s_awready_mac_to_ddr ;     
wire [127:0] s_wdata_mac_to_ddr;
wire  s_wlast_mac_to_ddr;         
wire s_wvalid_mac_to_ddr;         
wire s_wready_mac_to_ddr;                  
    
wire [28:0]s_araddr_ddr_to_mac;         
wire s_arvalid_ddr_to_mac;        
wire s_arready_ddr_to_mac ;               
wire s_rready_ddr_to_mac;          
wire s_rlast_ddr_to_mac    ;                    
wire s_rvalid_ddr_to_mac  ;                                
wire [127:0] s_rdata_ddr_to_mac ;     

	
reg		[31:0]				s_awaddr_cnt				;//写地址计数
reg		[31:0]				s_araddr_cnt				;//读地址计数
reg 						s_wvalid_mac_to_ddr_reg		;
reg							ddr_to_mac_start_reg		;//
reg							cfg_valid					;
assign c0_ddr4_s_axi_awlen = 3;//4-1//实际的长度AxLen=3+1
assign c0_ddr4_s_axi_arlen = 3;

/*******************************************************
			接收配置信息
*******************************************************/

//MAC写入到DDR的配置信息
reg [31:0] WR_DDR_HEAD_ADDR				;
reg [31:0] WR_DDR_TRANSFER_NUM			;
reg [511:0] cfg_value_wr				;
reg 	[28:0] 				mac_data_transfer_cnt		;//写传输次数,
wire		mac_to_ddr_start;

always @(posedge ddr_user_clk)begin
	if(ddr_user_sync_rst)begin
		WR_DDR_HEAD_ADDR 		<= 'b0;	
		WR_DDR_TRANSFER_NUM		<= 'b0;
		cfg_value_wr			<= 'b0;
	end
	else if(I_cfg_valid)begin
		cfg_value_wr 			<= I_cfg_value_wr_ddr;
		WR_DDR_HEAD_ADDR 		<= 'b0;	
		WR_DDR_TRANSFER_NUM		<= 'b0;		
	end
	else if(( (cfg_value_wr!=0) && (mac_data_transfer_cnt==WR_DDR_TRANSFER_NUM-1) && s_wlast_mac_to_ddr) || mac_to_ddr_start)begin
		WR_DDR_HEAD_ADDR 		<= cfg_value_wr[63:32];	
		WR_DDR_TRANSFER_NUM		<= cfg_value_wr[31:0];
		cfg_value_wr			<= {64'h0,cfg_value_wr[511:64]};
	end
	else begin
		WR_DDR_HEAD_ADDR 	<= WR_DDR_HEAD_ADDR;	
		WR_DDR_TRANSFER_NUM	<= WR_DDR_TRANSFER_NUM;
		cfg_value_wr		<= cfg_value_wr;
	end	
end	

//从DDR读出数据到MAC的配置信息
reg [31:0] DDR2TEMAC_HEAD_ADDR			;
reg [31:0] DDR2TEMAC_TRANSFER_NUM		;
always @(posedge ddr_user_clk)begin
	if(ddr_user_sync_rst)begin
		DDR2TEMAC_HEAD_ADDR		<= 'b0;
		DDR2TEMAC_TRANSFER_NUM	<= 'b0;
	end
	else if(ddr_to_mac_start)begin
		DDR2TEMAC_HEAD_ADDR		<= I_cfg_value_rd_ddr[31:0 ];
		DDR2TEMAC_TRANSFER_NUM	<= I_cfg_value_rd_ddr[63:32];		
	end
	else begin
		DDR2TEMAC_HEAD_ADDR		<= DDR2TEMAC_HEAD_ADDR;
		DDR2TEMAC_TRANSFER_NUM	<= DDR2TEMAC_TRANSFER_NUM;		
	end
end

reg			mac_to_ddr_fifo_empty_reg = 0;
always @(posedge ddr_user_clk)begin
	mac_to_ddr_fifo_empty_reg <= mac_to_ddr_fifo_empty;
end
/*******************************************************
			写地址通道
*******************************************************/
//写地址
assign      mac_to_ddr_start = cfg_valid&&(!mac_to_ddr_fifo_empty)&&init_calib_complete&&s_awready_mac_to_ddr;

always @(posedge ddr_user_clk)begin
	if(ddr_user_sync_rst)begin
		cfg_valid <= 0;
	end
	else if(I_cfg_valid)begin//
		cfg_valid <= 1;
	end
	else if(mac_to_ddr_start)begin
		cfg_valid <= 0;
	end
	else begin
		cfg_valid <= cfg_valid;
	end
end

reg mac_to_ddr_start_reg = 0;
always @(posedge ddr_user_clk)begin
	if(mac_to_ddr_start || ( (cfg_value_wr!=0 ) && (mac_data_transfer_cnt==WR_DDR_TRANSFER_NUM-1)&& s_wlast_mac_to_ddr ))begin
		mac_to_ddr_start_reg <= 1;//在一个部分写完的最后一个拉高
	end
	else begin
		mac_to_ddr_start_reg <= 0;
	end
end

always @(posedge ddr_user_clk)begin
	if(ddr_user_sync_rst)begin
		s_awaddr_cnt <= 'b0;
	end
	else if(s_awvalid_mac_to_ddr&&s_awready_mac_to_ddr&&(s_awaddr_cnt==WR_DDR_TRANSFER_NUM-1))begin
		s_awaddr_cnt <= 'b0;
	end
	else if(s_awvalid_mac_to_ddr&&s_awready_mac_to_ddr)begin
		s_awaddr_cnt <= s_awaddr_cnt + 1;
	end
	else begin
		s_awaddr_cnt <= s_awaddr_cnt;
	end
end
	
reg [28:0]s_awaddr_mac_to_ddr_reg;
always @(posedge ddr_user_clk)begin
	if(ddr_user_sync_rst)begin
		s_awaddr_mac_to_ddr_reg <= 'b0;
	end
	else if(mac_to_ddr_start_reg)begin//s_awaddr_cnt==WR_DDR_TRANSFER_NUM-1s时执行
		s_awaddr_mac_to_ddr_reg <= WR_DDR_HEAD_ADDR[28:0];
	end	
	else if(s_awvalid_mac_to_ddr&&s_awready_mac_to_ddr&&(s_awaddr_cnt==WR_DDR_TRANSFER_NUM-1))begin//该部分 只在全部读完之后 最后执行
		s_awaddr_mac_to_ddr_reg	<= 0;
	end		
	else if(s_awvalid_mac_to_ddr&&s_awready_mac_to_ddr)begin
		s_awaddr_mac_to_ddr_reg <= s_awaddr_mac_to_ddr_reg + 64;//每次传输4*128/8=64byte 
	end
	else begin
		s_awaddr_mac_to_ddr_reg	<= s_awaddr_mac_to_ddr_reg;
	end
end

assign s_awaddr_mac_to_ddr = s_awaddr_mac_to_ddr_reg;
//写地址有效 s_awvalid_mac_to_ddr
reg		s_awvalid_mac_to_ddr_reg;
always @(posedge ddr_user_clk)begin
	if(ddr_user_sync_rst)begin
		s_awvalid_mac_to_ddr_reg <= 'b0;
	end
	else if(mac_to_ddr_start_reg)begin
		s_awvalid_mac_to_ddr_reg <= 'b1;
	end
	else if(s_awvalid_mac_to_ddr&&s_awready_mac_to_ddr&&(s_awaddr_cnt==WR_DDR_TRANSFER_NUM-1))begin//直到最后一个 awvalid无效
		s_awvalid_mac_to_ddr_reg <= 'b0;
	end
	else begin
		s_awvalid_mac_to_ddr_reg <= s_awvalid_mac_to_ddr_reg;
	end
end
assign  s_awvalid_mac_to_ddr = s_awvalid_mac_to_ddr_reg&&(!mac_to_ddr_fifo_empty_reg);//logic

/*******************************************************
			写数据通道
*******************************************************/
reg 	[7:0]  				mac_data_valid_cnt			;//对写传输数据计数


always @(posedge ddr_user_clk)begin
	if(ddr_user_sync_rst)begin	
		mac_data_valid_cnt <= 'b0;
	end
	else if((mac_data_valid_cnt==3)&&s_wready_mac_to_ddr&&s_wvalid_mac_to_ddr)begin//4次传完之后,mac_data_transfer_cnt加1
		mac_data_valid_cnt <= 'b0;
	end
	else if(s_wready_mac_to_ddr&&s_wvalid_mac_to_ddr)begin	
		mac_data_valid_cnt <= mac_data_valid_cnt + 1;
	end
	else begin
		mac_data_valid_cnt <= mac_data_valid_cnt;
	end
end


assign s_wlast_mac_to_ddr = (s_wready_mac_to_ddr&&s_wvalid_mac_to_ddr&&(mac_data_valid_cnt==3))?1'b1:1'b0;//

always @(posedge ddr_user_clk)begin
	if(ddr_user_sync_rst)begin
		mac_data_transfer_cnt <= 'b0;
	end
	else if(s_wlast_mac_to_ddr&&(mac_data_transfer_cnt==WR_DDR_TRANSFER_NUM-1))begin
		mac_data_transfer_cnt <= 'b0;
	end
	else if(s_wlast_mac_to_ddr)begin
		mac_data_transfer_cnt <= mac_data_transfer_cnt + 1;
	end
	else begin
		mac_data_transfer_cnt <= mac_data_transfer_cnt;
	end
end

reg mac_to_ddr_done_reg;
assign mac_to_ddr_done = mac_to_ddr_done_reg;
always @(posedge ddr_user_clk)begin
	if(ddr_user_sync_rst)begin
		mac_to_ddr_done_reg <= 'b0;
	end
	else if((mac_data_transfer_cnt==WR_DDR_TRANSFER_NUM-1)&&(cfg_value_wr==0)&&s_wlast_mac_to_ddr)begin//全部写完
		mac_to_ddr_done_reg <= 'b1;
	end
	else begin
		mac_to_ddr_done_reg <= 'b0;
	end
end

reg rd_en_a,rd_en_b;
always @(posedge ddr_user_clk)begin
	if(ddr_user_sync_rst)begin
		rd_en_a <= 0;
		rd_en_b <=0;
	end
	else begin
		rd_en_a <= mac_to_ddr_fifo_rd_en;
		rd_en_b <= rd_en_a;//延迟两个周期才是真实数据
	end
end

reg [127:0] save_data [4095:0];//用于寄存fifo读出的数据
reg [11:0] wr_cnt;
reg [11:0] rd_cnt;
reg [31:0] wr_cnt_2;
reg [31:0] rd_cnt_2;

always @(posedge ddr_user_clk)begin
	if(ddr_user_sync_rst)begin
		save_data[wr_cnt] <= 0;
		wr_cnt <= 0;
		wr_cnt_2 <= 0;
	end
	else if(rd_en_b)begin
		save_data[wr_cnt] <= mac_to_ddr_fifo_dout;
		wr_cnt <= wr_cnt + 1;
		wr_cnt_2 <= wr_cnt_2 + 1;
	end
	else begin//
		save_data[wr_cnt] <= save_data[wr_cnt];
		wr_cnt <= wr_cnt;
		wr_cnt_2 <= wr_cnt_2;
	end
end

always @(posedge ddr_user_clk)begin
	if(ddr_user_sync_rst)begin
		s_wvalid_mac_to_ddr_reg <= 'b0;
	end
	else if(s_wlast_mac_to_ddr&&(mac_data_transfer_cnt==WR_DDR_TRANSFER_NUM-1))begin
		s_wvalid_mac_to_ddr_reg <= 'b0;
	end	
	else if(mac_to_ddr_start_reg)begin
		s_wvalid_mac_to_ddr_reg <= 'b1;
	end	
	else begin
		s_wvalid_mac_to_ddr_reg <= s_wvalid_mac_to_ddr_reg;
	end
end

always @(posedge ddr_user_clk)begin
	if(ddr_user_sync_rst)begin
		rd_cnt <= 0;
		rd_cnt_2 <= 0;
	end
	else if(s_wready_mac_to_ddr && s_wvalid_mac_to_ddr)begin//s_wready_mac_to_ddr 不是一直有效
		rd_cnt <= rd_cnt + 1;
		rd_cnt_2 <= rd_cnt_2 + 1;
		
	end
	else begin
		rd_cnt <= rd_cnt;
		rd_cnt_2 <= rd_cnt_2;
	end
end


reg last_valid;
always @(posedge ddr_user_clk)begin
    if(ddr_user_sync_rst)begin
		last_valid <= 0;
	end
	else if(last_valid)begin
		last_valid <= 0;
	end
	else if((cfg_value_wr==0)&&((mac_data_transfer_cnt==WR_DDR_TRANSFER_NUM-1)&&(mac_data_valid_cnt==3)))begin
		last_valid <= 1;
	end
end

assign s_wvalid_mac_to_ddr = s_wvalid_mac_to_ddr_reg && (wr_cnt_2 > (rd_cnt_2+1)) || last_valid;
assign s_wdata_mac_to_ddr = save_data[rd_cnt][127:0];//只有两者同时有效数据才会有效
assign mac_to_ddr_fifo_rd_en = (!mac_to_ddr_fifo_empty)&&(mac_to_ddr_start_reg|| s_wvalid_mac_to_ddr_reg);
/*******************************************************
			读地址通道
*******************************************************/
reg 						s_arvalid_ddr_to_mac_reg	;
reg							ddr_to_mac_start0;//,ddr_to_mac_start1;
wire						w_ddr_to_mac_start;
always @(posedge ddr_user_clk)begin
	if(ddr_user_sync_rst)begin
		ddr_to_mac_start0 <= 0;
	end
	else if(ddr_to_mac_start)begin
		ddr_to_mac_start0 <= 1;
	end
	else begin
		ddr_to_mac_start0 <= 0;
	end
end

assign w_ddr_to_mac_start = ddr_to_mac_start0;//&&(!ddr_to_mac_start1);

//读地址计数
always @(posedge ddr_user_clk)begin
	if(ddr_user_sync_rst)begin
		s_araddr_cnt <= 'b0;
	end
	else if(s_arready_ddr_to_mac&&s_arvalid_ddr_to_mac&&(s_araddr_cnt==(DDR2TEMAC_TRANSFER_NUM-1)))begin//表示突发传输的次数
		s_araddr_cnt <= 'b0;
	end
	else if(s_arready_ddr_to_mac&&s_arvalid_ddr_to_mac)begin
		s_araddr_cnt <= s_araddr_cnt + 1;
	end
	else begin
		s_araddr_cnt <= s_araddr_cnt;
	end
end
//读地址
reg [28:0]s_araddr_ddr_to_mac_reg;
always @(posedge ddr_user_clk)begin
	if(ddr_user_sync_rst)begin
		s_araddr_ddr_to_mac_reg <= 'b0;
	end
	else if(w_ddr_to_mac_start)begin//
		s_araddr_ddr_to_mac_reg <= DDR2TEMAC_HEAD_ADDR[28:0];
	end
	else if(s_arready_ddr_to_mac&&s_arvalid_ddr_to_mac)begin//可以连续读地址有效
		s_araddr_ddr_to_mac_reg <= s_araddr_ddr_to_mac_reg + 64;   //每次传输4*128/8=64byte
	end
	else begin
		s_araddr_ddr_to_mac_reg <= s_araddr_ddr_to_mac_reg;
	end
end

assign s_araddr_ddr_to_mac = s_araddr_ddr_to_mac_reg;
//读有效
always @(posedge ddr_user_clk)begin
	if(ddr_user_sync_rst)begin
		s_arvalid_ddr_to_mac_reg <= 'b0;
	end
	else if(s_arready_ddr_to_mac&&s_arvalid_ddr_to_mac&&(s_araddr_cnt==(DDR2TEMAC_TRANSFER_NUM-1)))begin
		s_arvalid_ddr_to_mac_reg <= 'b0;
	end
	else if(w_ddr_to_mac_start)begin
		s_arvalid_ddr_to_mac_reg <= 'b1;
	end
	else begin
		s_arvalid_ddr_to_mac_reg <= s_arvalid_ddr_to_mac_reg;
	end
end

always @(posedge ddr_user_clk)begin
	if(ddr_user_sync_rst)begin
		ddr_to_mac_start_reg <= 'b0;
	end
	else begin
		ddr_to_mac_start_reg <= w_ddr_to_mac_start;
	end
end
		
reg ddr_to_mac_rd_en_a,ddr_to_mac_rd_en_b;
always @(posedge ddr_user_clk)begin
	if(ddr_user_sync_rst)begin
		ddr_to_mac_rd_en_a <= 0;
		ddr_to_mac_rd_en_b <= 0;
	end
	else begin
		ddr_to_mac_rd_en_a <= ddr_to_mac_rd_en;
		ddr_to_mac_rd_en_b <= ddr_to_mac_rd_en_a;
	end
end

wire ddr_to_mac_rd_en_L2H = ddr_to_mac_rd_en_a && (~ddr_to_mac_rd_en_b);

assign s_arvalid_ddr_to_mac =  ddr_to_mac_rd_en_L2H || ddr_to_mac_start_reg || (s_arvalid_ddr_to_mac_reg&&s_rlast_ddr_to_mac&&ddr_to_mac_rd_en);


/*******************************************************
			读数据通道
*******************************************************/
reg 	[28:0] 				ddr_data_transfer_cnt		;
//reg 	[7:0]  				ddr_data_valid_cnt			;//对读传输数据计数,一个数据记为0-15
//输出的读准备信号 当init_calib_complete有效时为1	
reg s_rready_ddr_to_mac_reg;
assign s_rready_ddr_to_mac = s_rready_ddr_to_mac_reg;
always @(posedge ddr_user_clk)begin
	if(ddr_user_sync_rst)begin
		s_rready_ddr_to_mac_reg <= 'b0;
	end
	else if(init_calib_complete)begin
		s_rready_ddr_to_mac_reg <= 'b1;
	end
	else begin
		s_rready_ddr_to_mac_reg <= 'b0;
	end
end
		
always @(posedge ddr_user_clk)begin//8 -- 4个数为一次突发传输的概念 ddr_data_transfer_cnt==4-1
	if(ddr_user_sync_rst)begin
		ddr_data_transfer_cnt <= 'b0;
	end
	else if(s_rready_ddr_to_mac_reg&&s_rvalid_ddr_to_mac&&s_rlast_ddr_to_mac&&(ddr_data_transfer_cnt==(DDR2TEMAC_TRANSFER_NUM-1)))begin
		ddr_data_transfer_cnt <= 'b0;
	end
	else if(s_rready_ddr_to_mac_reg&&s_rvalid_ddr_to_mac&&s_rlast_ddr_to_mac)begin
		ddr_data_transfer_cnt <= ddr_data_transfer_cnt + 1;
	end
	else begin
		ddr_data_transfer_cnt <= ddr_data_transfer_cnt;
	end
end

//加这个是为了阻止外部有效就直接写数据到 Master端
reg rd_to_top_fifo_en;//因为接口的读地址 ready 没有拉高 在读数据有效时 用来阻止M00 不需要拉高的时候拉高
always @(posedge ddr_user_clk)begin
	if(ddr_user_sync_rst)begin
		rd_to_top_fifo_en <= 0;
	end
	else if(s_rready_ddr_to_mac_reg&&s_rvalid_ddr_to_mac&&s_rlast_ddr_to_mac&&(ddr_data_transfer_cnt==(DDR2TEMAC_TRANSFER_NUM-1)))begin
		rd_to_top_fifo_en <= 0;
	end
	//else if(s_arvalid_ddr_to_mac)begin 
	else if(w_ddr_to_mac_start)begin //2019/2/25 s_arvalid_ddr_to_mac 
		rd_to_top_fifo_en <= 1;
	end
end

assign  ddr_to_mac_data_valid   = s_rvalid_ddr_to_mac && rd_to_top_fifo_en;

assign	ddr_to_mac_data = s_rdata_ddr_to_mac;


assign c0_ddr4_s_axi_awid			=	4'd0;
assign c0_ddr4_s_axi_awsize			=	3'b100;   	
assign c0_ddr4_s_axi_awburst	   	=   2'b01;
assign c0_ddr4_s_axi_awlock			=   0;
assign c0_ddr4_s_axi_awcache	   	=	4'b0010;
assign c0_ddr4_s_axi_awprot			=	3'b0;
assign c0_ddr4_s_axi_awqos	       	=	4'b0;
assign c0_ddr4_s_axi_arid			= 	4'b0;
assign c0_ddr4_s_axi_arsize			=	3'b100;//2^4=16byte突发的大小
assign c0_ddr4_s_axi_arburst	  	= 	2'b01;
assign c0_ddr4_s_axi_arlock			=	0;
assign c0_ddr4_s_axi_arcache	  	=	4'b0010;
assign c0_ddr4_s_axi_arprot			=	3'b0;
assign c0_ddr4_s_axi_arqos	       	=	4'b0;

assign c0_ddr4_s_axi_awaddr        = s_awaddr_mac_to_ddr;

assign c0_ddr4_s_axi_awvalid       = s_awvalid_mac_to_ddr;         
assign s_awready_mac_to_ddr        = c0_ddr4_s_axi_awready;
assign c0_ddr4_s_axi_wdata         = s_wdata_mac_to_ddr;
assign c0_ddr4_s_axi_wlast         = s_wlast_mac_to_ddr;         
assign c0_ddr4_s_axi_wvalid        = s_wvalid_mac_to_ddr;         
assign s_wready_mac_to_ddr         = c0_ddr4_s_axi_wready ;                  
// assign c0_ddr4_s_axi_bid             
// assign c0_ddr4_s_axi_bresp           
// assign c0_ddr4_s_axi_bvalid          
assign c0_ddr4_s_axi_araddr        = s_araddr_ddr_to_mac;         

assign c0_ddr4_s_axi_arvalid       = s_arvalid_ddr_to_mac;        
assign s_arready_ddr_to_mac        = c0_ddr4_s_axi_arready;                  
assign c0_ddr4_s_axi_rready        = s_rready_ddr_to_mac;          
assign s_rlast_ddr_to_mac          = c0_ddr4_s_axi_rlast;                    
assign s_rvalid_ddr_to_mac         = c0_ddr4_s_axi_rvalid;                   
// assign c0_ddr4_s_axi_rresp             
// assign c0_ddr4_s_axi_rid              
assign s_rdata_ddr_to_mac          = c0_ddr4_s_axi_rdata;
assign c0_ddr4_s_axi_bready        = s_axi_bready;

//debug

assign     debug_cfg_valid			  = cfg_valid;
assign     debug_mac_data_transfer_cnt=mac_data_transfer_cnt;
assign     debug_s_wlast_mac_to_ddr   =s_wlast_mac_to_ddr;
assign     debug_mac_to_ddr_start     = mac_to_ddr_start;
assign     debug_mac_to_ddr_start_reg = mac_to_ddr_start_reg;
assign     debug_mac_to_ddr_done      = mac_to_ddr_done;
//assign     debug_cnt_interval         = cnt_interval;
assign     debug_last_valid           = last_valid;
assign     debug_s_wvalid_mac_to_ddr_reg = s_wvalid_mac_to_ddr_reg;
assign     debug_rd_en_b              = rd_en_b;
assign     debug_wr_cnt_2             = wr_cnt_2;
assign     debug_s_wvalid_mac_to_ddr  = s_wvalid_mac_to_ddr;
assign     debug_s_wready_mac_to_ddr  = s_wready_mac_to_ddr;
assign     debug_rd_cnt_2             = rd_cnt_2;
assign     debug_w_ddr_to_mac_start   = w_ddr_to_mac_start;
assign     debug_rd_to_top_fifo_en    = rd_to_top_fifo_en;
assign     debug_save_data            = save_data[rd_cnt];

endmodule
