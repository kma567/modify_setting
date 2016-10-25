`define  T_RL	   	16
`define  T_WL      	16
`define  T_RCD   	2	// AL = 3
`define  T_RP	   	10
`define  T_WIDTH 	2
`define  T_MRD		6
`define  T_MOD		30
`define  T_RLL		1024
`define  T_ZQCS   	128

`define	 M_PRE		0	// PRE
`define  M_NOP1 	`M_PRE+`T_WIDTH // NOP after PRE
`define  M_MRS1		`M_NOP1+`T_RP // Set MR1 with DLL Set
`define  M_NOP2		`M_MRS1+`T_WIDTH // NOP after DLL Set
`define  M_MRS0		`M_NOP2+`T_MRD // Set MR0 with DLL Reset
`define  M_NOP3		`M_MRS0+`T_WIDTH // NOP after DLL Reset
`define  M_ZQCS		`M_NOP3+`T_MOD // Send ZQCS
`define  M_NOP4		`M_ZQCS+`T_WIDTH // NOP after ZQCS

`define  MR_MRS1	`M_NOP4+`T_ZQCS // Set MR1 with DLL Set
`define  MR_NOP1	`MR_MRS1+`T_WIDTH // NOP after DLL Set
`define  MR_MRS0	`MR_NOP1+`T_MRD // Set MR0 with DLL Reset
`define  MR_NOP2	`MR_MRS0+`T_WIDTH // NOP after DLL Reset
`define  MR_DONE	`MR_NOP2+`T_RLL // DONE

`define  SCR_READ	`T_RCD+1
`define  SCR_NOP	`SCR_READ+2
`define  SCR_LSN	`SCR_NOP+`T_RL-2
`define  SCR_DATA	`SCR_LSN+1
`define  SCR_DONE	`SCR_DATA+8+`T_RP

`define  SCW_WRITE	`T_RCD+1
`define  SCW_NOP	`SCW_WRITE+2
`define  SCW_DQS	`SCW_NOP+`T_WL-4
`define  SCW_GET	`SCW_DQS+1
`define  SCW_DM		`SCW_GET+1
`define  SCW_TSB	`SCW_DM+9
`define  SCW_DONE	`SCW_TSB+18

module Processing_logic(
	// Outputs
	DATA_get, 
	CMD_get,
	RETURN_put, 
	RETURN_address, RETURN_data,  //construct RETURN_data_in
	cs_bar, ras_bar, cas_bar, we_bar,  // read/write function
	BA, A, DM,
	DQS_out, DQ_out,
	ts_con, modify_setting,
	// Inputs
	clk, ck, reset, ready, 
	CMD_empty, CMD_data_out, DATA_data_out,
	RETURN_full,
	DQS_in, DQ_in
	);

	parameter BL = 8;  // Burst Length
	parameter BT = 0;  // Burst Type
	parameter CL = 5;  // CAS Latency (CL)
	parameter AL = 3;  // Posted CAS# Additive Latency (AL)


	input 	 	  clk, ck, reset, ready;
	input 	 	  CMD_empty, RETURN_full;
	input [33:0]  CMD_data_out;
	input [15:0]  DATA_data_out;
	input [15:0]  DQ_in;
	input [1:0]   DQS_in;

	output reg 			CMD_get;
	output reg		 	DATA_get, RETURN_put;
	output reg [25:0] 	RETURN_address;
	output wire [15:0] 	RETURN_data;
	output reg			cs_bar, ras_bar, cas_bar, we_bar;
	output reg [2:0]	BA;
	output reg [12:0] 	A;
	output reg [1:0]	DM;
	output reg [15:0]  	DQ_out;
	output reg [1:0]   	DQS_out;
	output reg ts_con;
	output reg modify_setting;
	
	reg [2:0] Pointer;
	reg [3:0] state;
	reg	[11:0] counter;
	
	//reg [25:0] CMD_addr ;
	

	reg listen;
	
	reg DM_flag;
	
	localparam	[2:0]
		INIT 		= 3'b000,
		MODIFY		= 3'b001,
		DECODE 		= 3'b010,
		ACTIVATE 	= 3'b011,
		S_SCR 		= 3'b100,
		S_ATR 		= 3'b101,
		S_SCW 		= 3'b110,
		S_ATW 		= 3'b111;
		
	localparam	[2:0]
		SCR 		= 3'b001,
		SCW 		= 3'b010;
		
	localparam	[3:0]
		NOP			= 4'b0111,
		ACT			= 4'b0011,
		READ		= 4'b0101,
		WRITE		= 4'b0100,
		PRE			= 4'b0010,
		MRS			= 4'b0000,
		ZQCS		= 4'b0110;	
		

always @(posedge clk)
    if (reset)
	begin
		modify_setting <= 0;
		
	    counter <= 0;
		state <= INIT;
		
		CMD_get <= 0;
		DATA_get <= 0;
		RETURN_put <= 0;
		
		ts_con <= 0;
		DM_flag <= 0;
		{cs_bar, ras_bar, cas_bar, we_bar} <= NOP;
		
		A <= 0;
		BA <= 0;
		listen <= 0;
		Pointer <= 0;		
	end
	else
	  begin
		
		case (state)
		
			INIT:
			begin
				if (ready)
				begin
					if (!counter[0])
					begin
						if (!modify_setting)
							state <= MODIFY;
						if (!CMD_empty && !RETURN_full)
						begin
							CMD_get <= 1;	
							counter <= counter + 1;
						end
					end
					else
					begin
						CMD_get <= 0;
						counter <= 0;
						state <= DECODE;
					end
				end
			end
			
			MODIFY:
			begin
				counter <= counter + 1;
				 case (counter)
				 
					`M_PRE:  begin
								{cs_bar, ras_bar, cas_bar, we_bar} <= PRE; // EMRS command
								A[10] <= 1;
							 end
							 
					`M_NOP1: begin
								{cs_bar,ras_bar,cas_bar,we_bar} <= NOP;
							 end
							 
					`M_MRS1: begin
								{cs_bar, ras_bar, cas_bar, we_bar} <= MRS; // EMRS command 
								A[12] <= 0; // Output enabled
								A[11] <= 0; // TDQS enabled for 8 banks
								A[10] <= 0;
								{A[9], A[6], A[2]} <= 3'b001; // A[9,6,2] RTT disabled
								A[8] <= 0;
								A[7] <= 0; // write leveling disabled					 
								{A[5], A[1]} <= 2'b00; // A[5,1] Output driver
								A[4:3] <= 2'b01; // AL = CL - 1 = 4
								A[0] <= 0; // DLL enabled
								BA <= 3'b001;
							end
							
					`M_NOP2: {cs_bar, ras_bar, cas_bar, we_bar} <= NOP; // NOP command

					`M_MRS0: begin
								{cs_bar, ras_bar, cas_bar, we_bar} <= MRS; // EMRS command  
								A[12] <= 0; // DLL off
								A[11:9] <= 3'b010; // Write Recovery = 6
								A[8] <= 1; // DLL Reset
								A[7] <= 0;
								A[6:4] <= 3'b001; // CAS latency = 5
								A[3] <= 0; // Read type = sequential
								A[2] <= 0;
								A[1:0] <= 2'b10; // Burst length = 4;
								BA <= 3'b000; // MRS
							end
								
					`M_NOP3: {cs_bar, ras_bar, cas_bar, we_bar} <= NOP; // NOP command

					`M_ZQCS: begin
							{cs_bar, ras_bar, cas_bar, we_bar} <= ZQCS; 
							A[10] <= 0; 
							end
							
					`M_NOP4: {cs_bar, ras_bar, cas_bar, we_bar} <= NOP; // NOP command	

					`MR_MRS1: begin
								{cs_bar, ras_bar, cas_bar, we_bar} <= MRS; // EMRS command
								A[12] <= 0; // Output enabled
								A[11] <= 0; // TDQS enabled for 8 banks
								A[10] <= 0;
								{A[9], A[6], A[2]} <= 3'b000; // A[9,6,2] RTT disabled
								A[8] <= 0;
								A[7] <= 0; // write leveling disabled					 
								{A[5], A[1]} <= 2'b00; // A[5,1] Output driver
								A[4:3] <= 2'b10; // AL = CL - 2 = 3
								A[0] <= 0; // DLL enabled
								BA <= 3'b001;
							end
							
					`MR_NOP1: {cs_bar, ras_bar, cas_bar, we_bar} <= NOP; // NOP command

					`MR_MRS0: begin
								{cs_bar, ras_bar, cas_bar, we_bar} <= MRS; // EMRS command  
								A[12] <= 0; // DLL off
								A[11:9] <= 3'b010; // Write Recovery = 6
								A[8] <= 1; // DLL Reset
								A[7] <= 0;
								A[6:4] <= 3'b001; // CAS latency = 5
								A[3] <= 0; // Read type = sequential
								A[2] <= 0;
								A[1:0] <= 2'b00; // Burst length = 8;
								BA <= 3'b000; // MRS
							end
								
					`MR_NOP2: {cs_bar, ras_bar, cas_bar, we_bar} <= NOP; // NOP command
					
					`MR_DONE: begin
						state <= INIT; // done
						modify_setting <= 1;
						counter <= 0;
						end
					
				endcase
			end
			
			DECODE:
			begin
				//CMD_addr <= CMD_data_out[30:5];
				case (CMD_data_out[33:31])			

					SCR, SCW:
					if (ck)
					begin
						{cs_bar, ras_bar, cas_bar, we_bar} <= ACT;
						A[12:0] <= CMD_data_out[27:15];
						BA <= CMD_data_out[30:28];
						state <= ACTIVATE;
					end
					
					default:
						state <= INIT;
				
				endcase
			end
			
			ACTIVATE:
			begin
				counter <= counter + 1;
				if (counter[0])
				begin
					{cs_bar, ras_bar, cas_bar, we_bar} <= NOP;
					case (CMD_data_out[33:31])
					
						SCR: state <= S_SCR;
						
						SCW: state <= S_SCW;
						
						default: state <= INIT;
						
					endcase
				end
			end
			
			S_SCR:
			begin
				counter <= counter + 1;
				case (counter)
					
					`SCR_READ:
					begin
						{cs_bar, ras_bar, cas_bar, we_bar} <= READ;
						A[10] <= 1; // auto precharge
						//A[9:0] <= CMD_addr[9:0];
						A[9:0] <= CMD_data_out[14:5];
					end
					
					`SCR_NOP:
					begin
						{cs_bar, ras_bar, cas_bar, we_bar} <= NOP;
					end
					
					`SCR_LSN:
					begin
						listen <= 1;
					end
					
					`SCR_DATA:
					begin
						listen <= 0;
						RETURN_address <= CMD_data_out[30:5];
					end
					
					`SCR_DATA+1:
					begin
						RETURN_put <= 1;
					end
					`SCR_DATA+2: 
					//`SCR_DATA+3, `SCR_DATA+4, `SCR_DATA+5, `SCR_DATA+6, `SCR_DATA+7 :
					begin
						RETURN_put <= 0;
					end			
					
					`SCR_DONE:
					begin
						state <= INIT;
						counter <= 0;
					end					
					
				endcase
			end
			
			S_SCW:
			begin
				counter <= counter + 1;
				case (counter)
				
					`SCW_WRITE:
					begin
						{cs_bar, ras_bar, cas_bar, we_bar} <= WRITE;
						A[10] <= 1; // auto precharge
						//A[9:0] <= CMD_addr[9:0];
						A[9:0] <= CMD_data_out[14:5];
					end
					
					`SCW_NOP:
					begin
						{cs_bar, ras_bar, cas_bar, we_bar} <= NOP;
					end
					
					`SCW_DQS:
					begin
						ts_con <= 1;
						DQS_out <= 0;
					end
					
					`SCW_GET:
					begin
						DATA_get <= 1;
						DQS_out <= ~DQS_out;
					end
					
					`SCW_DM:
					begin
						if (CMD_data_out[7:5] == 0)
							DM_flag <= 1;
						DATA_get <= 0;
						DQS_out <= ~DQS_out;
					end
					
					`SCW_DM+1, `SCW_DM+2, `SCW_DM+3, `SCW_DM+4, `SCW_DM+5, `SCW_DM+6, `SCW_DM+7, `SCW_DM+8: 
					begin
						DQS_out <= ~DQS_out;
						if (counter == `SCW_DM + CMD_data_out[7:5])
							DM_flag <= 1;
						if (DM_flag)
							DM_flag <= 0;
					end
					
					`SCW_TSB:
					begin
						ts_con <= 0;
					end
					
					`SCW_DONE:
					begin
						state <= INIT;
						counter <= 0;
					end
					
				endcase
			end
		
		endcase
		
	  end				
				
			

ddr3_ring_buffer8 ring_buffer(RETURN_data, listen, DQS_in[0], Pointer[2:0], DQ_in, reset);


always @(negedge clk)
  begin
    DQ_out <= DATA_data_out;
    if(DM_flag)
        DM <= 2'b00;
    else
        DM <= 2'b11;	
  end
 
endmodule // ddr_controller
