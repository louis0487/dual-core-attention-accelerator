// Created for ECE260B Project Step 1 Baseline (Pure Combinational)
module mac_8in (out, a, b, clk, reset);

parameter bw = 8;
parameter bw_psum = 2*bw+6; // For sum of 8 product, we only need 3 extra space for carry out.
parameter pr = 64; // Parallel factor is exactly 8

input clk;
input reset;

output signed [bw_psum-1:0] out;
input  signed [pr*bw-1:0] a;
input  signed [pr*bw-1:0] b;

reg [2*bw-1:0] product_pipeline[0:7];
reg [bw_psum-1:0] inter_pipeline[0:1];
reg [bw_psum-1:0] out_pipeline;

wire [bw_psum-1:0]	intermediate_sum0;
wire [bw_psum-1:0]	intermediate_sum1;
wire [bw_psum-1:0]	final_sum;

// 8 multipliers only
wire [2*bw-1:0]	product0;
wire [2*bw-1:0]	product1;
wire [2*bw-1:0]	product2;
wire [2*bw-1:0]	product3;
wire [2*bw-1:0]	product4;
wire [2*bw-1:0]	product5;
wire [2*bw-1:0]	product6;
wire [2*bw-1:0]	product7;

genvar i;

assign	product0	=	{{(bw){a[bw*	1	-1]}},	a[bw*	1	-1:bw*	0	]}	*	{{(bw){b[bw*	1	-1]}},	b[bw*	1	-1:	bw*	0	]};
assign	product1	=	{{(bw){a[bw*	2	-1]}},	a[bw*	2	-1:bw*	1	]}	*	{{(bw){b[bw*	2	-1]}},	b[bw*	2	-1:	bw*	1	]};
assign	product2	=	{{(bw){a[bw*	3	-1]}},	a[bw*	3	-1:bw*	2	]}	*	{{(bw){b[bw*	3	-1]}},	b[bw*	3	-1:	bw*	2	]};
assign	product3	=	{{(bw){a[bw*	4	-1]}},	a[bw*	4	-1:bw*	3	]}	*	{{(bw){b[bw*	4	-1]}},	b[bw*	4	-1:	bw*	3	]};
assign	product4	=	{{(bw){a[bw*	5	-1]}},	a[bw*	5	-1:bw*	4	]}	*	{{(bw){b[bw*	5	-1]}},	b[bw*	5	-1:	bw*	4	]};
assign	product5	=	{{(bw){a[bw*	6	-1]}},	a[bw*	6	-1:bw*	5	]}	*	{{(bw){b[bw*	6	-1]}},	b[bw*	6	-1:	bw*	5	]};
assign	product6	=	{{(bw){a[bw*	7	-1]}},	a[bw*	7	-1:bw*	6	]}	*	{{(bw){b[bw*	7	-1]}},	b[bw*	7	-1:	bw*	6	]};
assign	product7	=	{{(bw){a[bw*	8	-1]}},	a[bw*	8	-1:bw*	7	]}	*	{{(bw){b[bw*	8	-1]}},	b[bw*	8	-1:	bw*	7	]};

assign intermediate_sum0 = 
		{{(4){product_pipeline[0][2*bw-1]}},product_pipeline[0]	}
	+	{{(4){product_pipeline[1][2*bw-1]}},product_pipeline[1]	}
	+	{{(4){product_pipeline[2][2*bw-1]}},product_pipeline[2]	}
	+	{{(4){product_pipeline[3][2*bw-1]}},product_pipeline[3]	};

assign intermediate_sum1 = 
		{{(4){product_pipeline[4][2*bw-1]}},product_pipeline[4]	}
	+	{{(4){product_pipeline[5][2*bw-1]}},product_pipeline[5]	}
	+	{{(4){product_pipeline[6][2*bw-1]}},product_pipeline[6]	}
	+	{{(4){product_pipeline[7][2*bw-1]}},product_pipeline[7]	};

assign final_sum = inter_pipeline[0] + inter_pipeline[1];

// Pipelining
always @(posedge clk) begin
	if(reset) begin
		product_pipeline[0] <= 0;
		product_pipeline[1] <= 0;
		product_pipeline[2] <= 0;
		product_pipeline[3] <= 0;
		product_pipeline[4] <= 0;
		product_pipeline[5] <= 0;
		product_pipeline[6] <= 0;
		product_pipeline[7] <= 0;
	end
	else begin
		product_pipeline[0] <= product0;
		product_pipeline[1] <= product1;
		product_pipeline[2] <= product2;
		product_pipeline[3] <= product3;
		product_pipeline[4] <= product4;
		product_pipeline[5] <= product5;
		product_pipeline[6] <= product6;
		product_pipeline[7] <= product7;
	end
end

always @(posedge clk) begin
	if(reset) begin
		inter_pipeline[0] <= 0;
		inter_pipeline[1] <= 0;
	end
	else begin
		inter_pipeline[0] <= intermediate_sum0;
		inter_pipeline[1] <= intermediate_sum1;
	end
end

always @(posedge clk) begin
	if(reset) begin
		out_pipeline <= 0;
	end
	else begin
		out_pipeline <= final_sum;
	end
end

assign out = out_pipeline;


endmodule