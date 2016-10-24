
module ddr3_controller(
	// Outputs
	dout, raddr, fillcount, validout, notfull, ready, ck_pad, ckbar_pad,
	cke_pad, csbar_pad, rasbar_pad, casbar_pad, webar_pad, ba_pad,
	a_pad, dm_pad, odt_pad, resetbar_pad,
	// Inouts
	dq_pad, dqs_pad, dqsbar_pad,
	// Inputs
	clk, reset, read, cmd, sz, op, din, addr, initddr
	);

	parameter BL = 8; // Burst Lenght = 8
	parameter BT = 0;   // Burst Type = Sequential
	parameter CL = 5;  // CAS Latency (CL) = 4
	parameter AL = 3;  // Posted CAS# Additive Latency (AL) = 3
	
	localparam	[2:0]
		SCR 		= 3'b001,
		SCW 		= 3'b010;


	input 	 	clk;
	input 	 	reset;
	input 	 	read;
	input [2:0] cmd;
	input [15:0] din;
	input [25:0] addr;
	input [1:0] sz;
	input [2:0] op;
	output [15:0] dout;
	output [25:0] raddr;
	output [5:0]  fillcount;
	output		 validout;
	output 		 notfull;
	input 		 initddr;
	output 		 ready;

	output 		 ck_pad;
	output 		 ckbar_pad;
	output 		 cke_pad;
	output 		 csbar_pad;
	output 		 rasbar_pad;
	output 		 casbar_pad;
	output 		 webar_pad;
	output [2:0]  ba_pad;
	output [13:0] a_pad;
	inout [15:0]  dq_pad;
	inout [1:0]  dqs_pad;
	inout [1:0]  dqsbar_pad;
	output [1:0] dm_pad;
	output 		 odt_pad;
	output		 resetbar_pad;

	/*autowire*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	wire [15:0]		dataOut;				// From XDFIN of fifo.v
	wire [15:0]		dq_o;					// From XSSTL of SSTL18DDR2INTERFACE.v
	wire [1:0]		dqs_o;					// From XSSTL of SSTL18DDR2INTERFACE.v
	wire [1:0]		dqsbar_o;				// From XSSTL of SSTL18DDR2INTERFACE.v
	wire			notfull, validout;				// From XDFIN of fifo.v
	wire [5:0]		CMD_fillcount, RETURN_fillcount;		// From XDFIN of fifo.v
	wire [5:0]		fillcount;
	// End of automatics

	//wire 		 ri_i;
	wire 		 ts_con, ts_i;   
	reg 		 ck_i;
	wire 		 cke_i;
	wire 		 csbar_i;
	wire 		 rasbar_i;
	wire 		 casbar_i;
	wire 		 webar_i;
	wire [2:0] 	 ba_i;
	wire [13:0]  a_i;
	wire [15:0]  dq_i;
	wire [1:0] 	 dqs_i;
	wire [1:0] 	 dqsbar_i;
	wire [1:0] 	 dm_i;
	wire 		 odt_i;
	wire		 resetbar_i;

	wire 		csbar, init_csbar;
	wire 		rasbar, init_rasbar;
	wire 		casbar, init_casbar;
	wire 		webar, init_webar;
	wire 		resetbar, init_resetbar;
	wire [2:0] 	ba, init_ba;
	wire [13:0]	a,init_a;
	wire [1:0] 	init_dm;
	wire 		init_cke;
	wire 		init_ts_con;
	wire 		ri_con;
	
	wire [15:0] IN_data_out;
	wire [33:0] CMD_data_in, CMD_data_out;
	wire [41:0] RETURN_data_in, RETURN_data_out;
	wire 		IN_empty, IN_full, CMD_empty, CMD_full, RETURN_empty, RETURN_full;
	wire 		IN_get, CMD_get, RETURN_put, RETURN_get;
	reg 		IN_put, CMD_put;
	
	// CK divider
	always @(posedge clk) 
	   if (reset==1)
	   begin
		   ck_i <= 0;
	   end
	   else
		   ck_i <= ~ck_i;  // 312.5 MHz Clock


	// Input data FIFO
	FIFO #(.DEPTH_P2(5), .WIDTH(16)) FIFO_IN (/*autoinst*/
						  .clk					(clk),
						  .reset				(reset),
						  .data_in              (din),
						  .put  				(IN_put),
						  .get					(IN_get),
						  .data_out				(IN_data_out),
						  .empty			    (IN_empty),
						  .full			     	(IN_full),
						  .fillcount			(fillcount)
						  ); 
	// Command FIFO						  
	FIFO #(.DEPTH_P2(5), .WIDTH(34)) FIFO_CMD (/*autoinst*/
						  .clk					(clk),
						  .reset				(reset),
						  .data_in              (CMD_data_in),
						  .put  				(CMD_put),
						  .get					(CMD_get),
						  .data_out				(CMD_data_out),
						  .empty			    (CMD_empty),
						  .full			     	(CMD_full),
						  .fillcount			(CMD_fillcount)
						  ); 
	// Return DATA and address FIFO	
	FIFO #(.DEPTH_P2(5), .WIDTH(42)) FIFO_RETURN (/*autoinst*/
						  .clk					(clk),
						  .reset				(reset),
						  .data_in              (RETURN_data_in),
						  .put  				(RETURN_put),
						  .get					(RETURN_get),
						  .data_out				(RETURN_data_out),
						  .empty			    (RETURN_empty),
						  .full			     	(RETURN_full),
						  .fillcount			(RETURN_fillcount)
						  ); 
						  
	
	// DDR2 Initialization engine
	ddr3_init_engine XINIT (
						   // Outputs
						   .ready				(ready),
						   .csbar				(init_csbar),
						   .rasbar				(init_rasbar),
						   .casbar				(init_casbar),
						   .webar				(init_webar),
						   .ba					(init_ba[2:0]),
						   .a					(init_a[13:0]),
						   .odt					(init_odt),
						   .ts_con				(init_ts_con),
						   .cke                 (init_cke),
						   .resetbar			(init_resetbar),
						   // Inputs
						   .clk					(clk),
						   .reset				(reset),
						   .init				(initddr),
						   .ck					(ck_i)		   );
						   
	Processing_logic  XPL  (
							// Outputs
							.DATA_get			(IN_get), 
							.CMD_get			(CMD_get),
							.RETURN_put			(RETURN_put), 
							.RETURN_address		(RETURN_data_in[41:16]), 
							.RETURN_data		(RETURN_data_in[15:0]),  
							.cs_bar				(csbar), 
							.ras_bar			(rasbar), 
							.cas_bar			(casbar), 
							.we_bar				(webar), 
							.BA					(ba[2:0]),
							.A					(a[13:0]), 
							.DM					(dm_i[1:0]),
							.DQS_out			(dqs_i[1:0]), 
							.DQ_out				(dq_i[15:0]),
							.ts_con				(ts_con),
							// Inputs
							.clk				(clk), 
							.ck					(ck_i), 
							.reset				(reset), 
							.ready				(ready), 
							.CMD_empty			(CMD_empty), 
							.CMD_data_out		(CMD_data_out),
							.DATA_data_out		(IN_data_out),
							.RETURN_full		(RETURN_full),
							.DQS_in				(dqs_o[1:0]), 
							.DQ_in				(dq_o[15:0])	);

	// FIFO control logic
	always @(cmd, notfull)
	begin
		if (!notfull)
		begin
			CMD_put = 0;
			IN_put = 0;
		end
		else
		begin
			case (cmd)
			
			SCR:
			begin
				CMD_put = 1;
				IN_put = 0;
			end
			
			SCW:
			begin
				CMD_put = 1;
				IN_put = 1;
			end
			
			default:
			begin
				CMD_put = 0;
				IN_put = 0;
			end
			
			endcase
		end
	end

	// FIFO signals
	assign		 CMD_data_in  = {cmd, addr, sz, op};
	assign		 RETURN_get	  = read;
	assign		 raddr        = RETURN_data_out[41:16];
	assign		 dout		  = RETURN_data_out[15:0];
	assign		 validout     = !RETURN_empty;
	assign		 notfull	  = !IN_full && !CMD_full;
	
	// Output Mux for control signals
	assign		 ts_i     = (ready) ? ts_con : init_ts_con;
	assign 		 a_i 	  = (ready) ? a      : init_a;
	assign 		 ba_i 	  = (ready) ? ba     : init_ba;
	assign 		 csbar_i  = (ready) ? csbar  : init_csbar;
	assign 		 rasbar_i = (ready) ? rasbar : init_rasbar;
	assign 		 casbar_i = (ready) ? casbar : init_casbar;
	assign 		 webar_i  = (ready) ? webar  : init_webar;	
	assign		 resetbar_i = init_resetbar && ~reset;
	assign		 dqsbar_i = ~dqs_i;
	assign 		 cke_i 	  = init_cke;
	assign 		 odt_i 	  = init_odt;
	assign 		 ri_con = 1;

	SSTL18DDR3INTERFACE XSSTL (/*autoinst*/
							  // Outputs
							  .ck_pad			(ck_pad),
							  .ckbar_pad		(ckbar_pad),
							  .cke_pad			(cke_pad),
							  .csbar_pad		(csbar_pad),
							  .rasbar_pad		(rasbar_pad),
							  .casbar_pad		(casbar_pad),
							  .webar_pad		(webar_pad),
							  .ba_pad			(ba_pad[2:0]),
							  .a_pad			(a_pad[13:0]),
							  .dm_pad			(dm_pad[1:0]),
							  .odt_pad			(odt_pad),
							  .resetbar_pad		(resetbar_pad),
							  .dq_o				(dq_o[15:0]),
							  .dqs_o			(dqs_o[1:0]),
							  .dqsbar_o			(dqsbar_o[1:0]),							  
							  // Inouts
							  .dq_pad			(dq_pad[15:0]),
							  .dqs_pad			(dqs_pad[1:0]),
							  .dqsbar_pad		(dqsbar_pad[1:0]),
							  // Inputs
							  .ri_i				(ri_con),
							  .ts_i				(ts_i),
							  .ck_i				(ck_i),
							  .cke_i			(cke_i),
							  .csbar_i			(csbar_i),
							  .rasbar_i			(rasbar_i),
							  .casbar_i			(casbar_i),
							  .webar_i			(webar_i),
							  .ba_i				(ba_i[2:0]),
							  .a_i				(a_i[13:0]),
							  .dq_i				(dq_i[15:0]),
							  .dqs_i			(dqs_i[1:0]),
							  .dqsbar_i			(dqsbar_i[1:0]),
							  .dm_i				(dm_i[1:0]),
							  .odt_i			(odt_i),
							  .resetbar_i		(resetbar_i));



endmodule // ddr2_controller
