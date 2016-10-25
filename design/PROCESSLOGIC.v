//set configuration
`define INIPRE1 		17'd1
`define NOP1			`INIPRE1 + 17'd2//trp(min) = 5CK
`define MRS0			`NOP1 + 17'd10
`define NOP2			`MRS0 + 17'd2//tmrd(min) = 4CK
`define MRS1			`NOP2 + 17'd8
`define NOP3			`MRS1 + 17'd2
`define REMRS0			`NOP3 + 17'd8
`define NOP4			`REMRS0 + 17'd2
`define REMRS1			`NOP4 + 17'd8
`define NOP5			`REMRS1 + 17'd2//tmod(min) = 12 CK or 15ns
`define END				`NOP5 +  17'd24
//memory begins
`define INI1			17'd0
`define FETCH			`INI1 + 17'd1	
`define DECODE			`FETCH + 17'd1
`define ACT				`DECODE + 17'd1

//scr
`define READNOP1		17'd100
`define SCR				`READNOP1 + 17'd2 //trcd(min)=5CK, AL=3CK
// `define SCR				17'd100
`define READNOP2		`SCR + 17'd2
`define PRE_READDATA	`READNOP2 + 17'd14 //AL=3CK, CL=5CK, RL = AL+CL
`define READDATA1		`PRE_READDATA + 17'd1
`define READDATA2		`READDATA1 + 17'd1
`define READDATA3		`READDATA2 + 17'd1
`define READDATA4		`READDATA3 + 17'd1
`define READDATA5		`READDATA4 + 17'd1
`define READDATA6		`READDATA5 + 17'd1
`define READDATA7		`READDATA6 + 17'd1
`define READDATA8		`READDATA7 + 17'd1
`define POSTREADNOP		`READDATA8 + 17'd20//tccd(min) = 4CK

//scw
`define WRITENOP1		17'd300
`define SCW				`WRITENOP1 + 17'd2 //trcd(min)=5CK, AL=3CK
`define WRITENOP2		`SCW + 17'd2 
`define PRE_WRITEDATA1	`WRITENOP2 + 17'd13 //AL=3CK, CWL=5CK, WL = AL+CWL
`define WRITEDATA1		`PRE_WRITEDATA1 + 17'd1
`define WRITEDATA2		`WRITEDATA1 + 17'd1
`define WRITEDATA3		`WRITEDATA2 + 17'd1
`define WRITEDATA4		`WRITEDATA3 + 17'd1
`define WRITEDATA5		`WRITEDATA4 + 17'd1
`define WRITEDATA6		`WRITEDATA5 + 17'd1
`define WRITEDATA7		`WRITEDATA6 + 17'd1
`define WRITEDATA8		`WRITEDATA7 + 17'd1
`define POSTWRITENOP1	`WRITEDATA8 + 17'd1//tccd(min) = 4CK
`define POSTWRITENOP2	`POSTWRITENOP1 + 17'd1
`define POSTWRITENOP3	`POSTWRITENOP2 + 17'd1//tccd(min) = 4CK
`define POSTWRITENOP4	`POSTWRITENOP3 + 17'd20
module Processing_logic(
   // Outputs
   DATA_get, 
   CMD_get,
   RETURN_put, 
   RETURN_address, RETURN_data,  //construct RETURN_data_in
   cs_bar, ras_bar, cas_bar, we_bar,  // read/write function
   BA, A, DM,
   DQS_out, DQ_out,
   ts_con,resetbar,
   // Inputs
   clk, ck, reset, ready, 
   CMD_empty, CMD_data_out, DATA_data_out,
   RETURN_full,
   DQS_in, DQ_in
   );

   parameter BL = 4'd8; // Burst Length
   parameter BT = 1'b0;   // Burst Type
   parameter CL = 3'd5;  // CAS Latency (CL)
   parameter AL = 3'd3;  // Posted CAS# Additive Latency (AL)

   
   input 	 clk, ck, reset, ready;
   input 	 CMD_empty, RETURN_full;
   input [33:0]	 CMD_data_out;
   input [15:0]  DATA_data_out;
   input [15:0]  DQ_in;
   input [1:0]   DQS_in;
 
   output reg CMD_get;
   output reg		 DATA_get, RETURN_put;
   output reg [25:0] RETURN_address;
   output wire [15:0] RETURN_data;
   output reg	cs_bar, ras_bar, cas_bar, we_bar;
   output reg [2:0]	 BA;
   output reg [13:0] A;
   output reg [1:0]	 DM;
   output reg [15:0]  DQ_out;
   output reg [1:0]   DQS_out;
   output reg ts_con;
   output reg resetbar;

   reg listen;

   reg DM_flag;
   reg [2:0] Pointer;
   reg reset_flag;
   reg [16:0] counter;
   
   reg [2:0] op;
   reg [1:0] sz;
   reg [2:0] cmd;
   reg [25:0] addr;
   reg [15:0] data;
   reg [10:0] dll_count;
   reg dll_finsh;
   reg [25:0] raddr;
   reg rd_mark;
   
   parameter NOP = 4'b0111;
always @(posedge clk)
    if(reset)
	begin
		CMD_get <= 0;
		DATA_get <= 0;
		RETURN_put <= 0;
		cs_bar <= 1;
		ras_bar <= 1;
		cas_bar <= 1;
		we_bar <= 1;
		DM_flag <= 0;
		Pointer <= 3'b000;
		ts_con <= 0;
		reset_flag <= 1;
		counter <= 0;
		resetbar <= 1;
		A <= 0;
		listen <= 0;
		DQS_out <= 2'b00;
		dll_count <= 0;
		dll_finsh <= 0;
		rd_mark <= 0;
	end
	else
	begin
		if(ready)
			if(reset_flag == 1)
			begin
				counter <= counter + 1;
				case(counter)
				`INIPRE1: begin
								{cs_bar,ras_bar,cas_bar,we_bar} <= 4'b0010;
								A[10] <= 1;
						  end
				`NOP1:	  begin
								{cs_bar,ras_bar,cas_bar,we_bar} <= NOP;
						  end
				`MRS0:    begin
								{cs_bar,ras_bar,cas_bar,we_bar} <= 4'b0000;
								BA <= 3'b000;
								A[1:0] <= 2'b10;
								A[3] <= 0;
								A[6:4] <= 3'b001;
								A[8] <= 1;
								A[11:9] <= 3'b010;
								A[12] <= 0;
						  end
				`NOP2:	  begin
								{cs_bar,ras_bar,cas_bar,we_bar} <= NOP;
						  end
				`MRS1:	  begin
								{cs_bar,ras_bar,cas_bar,we_bar} <= 4'b0000;
								BA <= 3'b001;
								A[5:3] <= 3'b001;
								A[6] <= 0;
								A[7] <= 0;
								A[10:9] <= 2'b00;
								A[12:11] <= 2'b10;
						  end
				`NOP3:	  begin
								{cs_bar,ras_bar,cas_bar,we_bar} <= NOP;
						  end
				`REMRS0:  begin
								{cs_bar,ras_bar,cas_bar,we_bar} <= 4'b0000;
								BA <= 3'b000;
								A[1:0] <= 2'b00;
								A[3] <= 0;
								A[6:4] <= 3'b001;
								A[8] <= 1;
								A[11:9] <= 3'b010;
								A[12] <= 0;
						  end
				`NOP4:	  begin
								{cs_bar,ras_bar,cas_bar,we_bar} <= NOP;
						  end
				`REMRS1:  begin
								{cs_bar,ras_bar,cas_bar,we_bar} <= 4'b0000;
								BA <= 3'b001;
								A[5:3] <= 3'b010;
								A[6] <= 0;
								A[7] <= 0;
								A[10:9] <= 2'b00;
								A[12:11] <= 2'b00;
						  end
				`NOP5: 	  begin
								{cs_bar,ras_bar,cas_bar,we_bar} <= NOP;
						  end
				`END:     begin
								reset_flag <= 0;
								counter <= 0;
								dll_count <= 0;
								dll_finsh <= 0;
						  end
				endcase
			end
			else
			begin
				case(counter)
				`INI1:	  begin
								{cs_bar,ras_bar,cas_bar,we_bar} <= NOP;
								dll_count <= dll_count + 1;
								if(CMD_empty != 1) 
								begin
									CMD_get <= 1;
									counter <= counter + 1;
									rd_mark <= 0;
								end
						  end
				`FETCH:	  begin
								CMD_get <= 0;
								dll_count <= dll_count + 1;
								rd_mark <= 1;
								if(rd_mark == 0)
								begin
									addr <= CMD_data_out[25:0];
									cmd <= CMD_data_out[28:26];
									sz <= CMD_data_out[30:29];
									op <= CMD_data_out[33:31];
								end
								if(CMD_data_out[28:26] == 3'b000) counter <= 0;
								else if((CMD_data_out[28:26] == 3'b001)  && ((dll_count > 11'd1024) || (dll_finsh == 1)))
								//else if(CMD_data_out[28:26] == 3'b001)
								begin
									counter <= counter + 1;
									dll_finsh <= 1;
								end	
								else if(CMD_data_out[28:26] == 3'b010)
								begin
									counter <= counter + 1;
									DATA_get <= 1;
								end
								else if(CMD_data_out[28:26] != 3'b001) counter <= 0;//if read cmd comes, but it does not reach dll requirement,
																						//controller will stay in this state
						  end
				`DECODE:  begin
								DATA_get <= 0;
								counter <= counter + 1;
								dll_count <= dll_count + 1;
								if(cmd == 3'b010)	data <= DATA_data_out;
						  end
				`ACT:	  begin
								{cs_bar,ras_bar,cas_bar,we_bar} <= 4'b0011;
								BA <= addr[12:10];
								A <= addr[25:13];
								dll_count <= dll_count + 1;
								if(cmd == 3'b001) counter <= 17'd99;
								else if(cmd == 3'b010) counter <= 17'd299;
						  end
						  
						  
				//scalar read 
				`READNOP1: begin
								{cs_bar,ras_bar,cas_bar,we_bar} <= NOP;
								counter <= counter + 1;
						  end
				`SCR:	  begin
								{cs_bar,ras_bar,cas_bar,we_bar} <= 4'b0101;
								BA <= addr[12:10];
								A[9:0] <= addr[9:0];
								A[10] <= 1;
								counter <= counter + 1;
						  end
				`READNOP2:begin
								{cs_bar,ras_bar,cas_bar,we_bar} <= NOP;
								counter <= counter + 1;
						  end
				`PRE_READDATA: begin
								listen <= 1;
								counter <= counter + 1;
								ts_con <= 0;
							   end
				`READDATA1: begin
								listen <= 0;
								counter <= counter + 1;
								Pointer <= 3'b000;
								RETURN_put <= 1;
							end
				`READDATA2: begin
								counter <= counter + 1;
								Pointer <= Pointer + 1;
								RETURN_put <= 0;
							end
				`READDATA3: begin
								counter <= counter + 1;
								Pointer <= Pointer + 1;
								RETURN_put <= 0;
							end
				`READDATA4: begin
								counter <= counter + 1;
								Pointer <= Pointer + 1;
								RETURN_put <= 0;
							end
				`READDATA5: begin
								counter <= counter + 1;
								Pointer <= Pointer + 1;
								RETURN_put <= 0;
							end
				`READDATA6: begin
								counter <= counter + 1;
								Pointer <= Pointer + 1;
								RETURN_put <= 0;
							end
				`READDATA7: begin
								counter <= counter + 1;
								Pointer <= Pointer + 1;
								RETURN_put <= 0;
							end
				`READDATA8: begin
								counter <= counter + 1;
								Pointer <= Pointer + 1;
								RETURN_put <= 0;
							end
				`POSTREADNOP: begin
								{cs_bar,ras_bar,cas_bar,we_bar} <= NOP;
								counter <= 17'd0;
								ts_con <= 0;
							  end
				
				

				//scalar write
				`WRITENOP1: begin
								{cs_bar,ras_bar,cas_bar,we_bar} <= NOP;
								counter <= counter + 1;
								dll_count <= dll_count + 1;
							end
				`SCW: begin
								{cs_bar,ras_bar,cas_bar,we_bar} <= 4'b0100;
								counter <= counter + 1;
								A[10] <= 1;
								A[9:0] <= addr[9:0];
								dll_count <= dll_count + 1;
					  end
				`WRITENOP2: begin
								{cs_bar,ras_bar,cas_bar,we_bar} <= NOP;
								counter <= counter + 1;
								dll_count <= dll_count + 1;
							end	
				`PRE_WRITEDATA1: begin
								DQS_out <= 2'b11;
								counter <= counter + 1;
								// if(addr[2:0] == 0)	DM_flag <= 1;
								// else				DM_flag <= 0;
								DM_flag <= 0;
								ts_con <= 1;
								dll_count <= dll_count + 1;
								 end
				`WRITEDATA1: begin
								DQS_out <= ~DQS_out;
								counter <= counter + 1;
								//ts_con <= 0;
								if(addr[2:0] == 0)	DM_flag <= 1;
								else				DM_flag <= 0;
								//DM_flag <= 1;
								RETURN_address <= addr;
								dll_count <= dll_count + 1;
							 end
				`WRITEDATA2: begin
								DQS_out <= ~DQS_out;
								counter <= counter + 1;
								//ts_con <= 0;
								if(addr[2:0] == 1)	DM_flag <= 1;
								else				DM_flag <= 0;
								//DM_flag <= 0;
								dll_count <= dll_count + 1;
							 end
				`WRITEDATA3: begin
								DQS_out <= ~DQS_out;
								counter <= counter + 1;
								//ts_con <= 0;
								if(addr[2:0] == 2)	DM_flag <= 1;
								else				DM_flag <= 0;
								dll_count <= dll_count + 1;
							 end
				`WRITEDATA4: begin
								DQS_out <= ~DQS_out;
								counter <= counter + 1;
								//ts_con <= 0;
								if(addr[2:0] == 3)	DM_flag <= 1;
								else				DM_flag <= 0;
								dll_count <= dll_count + 1;
							 end
				`WRITEDATA5: begin
								DQS_out <= ~DQS_out;
								counter <= counter + 1;
								//ts_con <= 0;
								if(addr[2:0] == 4)	DM_flag <= 1;
								else				DM_flag <= 0;
								dll_count <= dll_count + 1;
							 end
				`WRITEDATA6: begin
								DQS_out <= ~DQS_out;
								counter <= counter + 1;
								//ts_con <= 0;
								if(addr[2:0] == 5)	DM_flag <= 1;
								else				DM_flag <= 0;
								dll_count <= dll_count + 1;
							 end
				`WRITEDATA7: begin
								DQS_out <= ~DQS_out;
								counter <= counter + 1;
								//ts_con <= 0;
								if(addr[2:0] == 6)	DM_flag <= 1;
								else				DM_flag <= 0;
								dll_count <= dll_count + 1;
							 end
				`WRITEDATA8: begin
								DQS_out <= ~DQS_out;
								counter <= counter + 1;
								//ts_con <= 0;
								if(addr[2:0] == 7)	DM_flag <= 1;
								else				DM_flag <= 0;
								dll_count <= dll_count + 1;
							 end
				`POSTWRITENOP1, `POSTWRITENOP2: begin
								{cs_bar,ras_bar,cas_bar,we_bar} <= NOP;
								counter <= counter + 1;
								DQS_out <= ~DQS_out;
								DM_flag <= 0;
								dll_count <= dll_count + 1;
							   end
				`POSTWRITENOP3: begin
								counter <= counter + 1;
								ts_con <= 0;
								dll_count <= dll_count + 1;
							   end
				`POSTWRITENOP4: begin
								counter <= 17'd0;
								ts_con <= 0;
								dll_count <= dll_count + 1;
							   end
				default: begin
								counter <= counter + 1;
								dll_count <= dll_count + 1;
						 end
				endcase			   
			end	
	end
ddr3_ring_buffer8 ring_buffer(RETURN_data, listen, DQS_in[0], Pointer[2:0], DQ_in, reset);


always @(negedge clk)
  begin
   // DQ_out <= DATA_data_out;
   DQ_out <= data;
    if(DM_flag)
        DM <= 2'b00;
    else
        DM <= 2'b11;	
  end
 
endmodule // ddr_controller
