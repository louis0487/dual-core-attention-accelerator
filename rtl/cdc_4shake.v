module cdc_4phase (clk_src, clk_dest, reset_src, reset_dest, data_in, send, data_out, busy);

parameter bw = 8;
parameter bw_psum = 2*bw + 4;

input  clk_src;             // source clock domain
input  clk_dest;            // destination clock domain
input  reset_src;             // source clock domain
input  reset_dest;            // destination clock domain
input  [bw_psum+3:0] data_in;   // data from source domain
input  send;               // pulse: new data available
output reg [bw_psum+3:0] data_out; // data received in destination
output reg busy;            // source is waiting for handshake
reg [bw_psum+3:0] data_latched;

// Source domain signals
reg req;               // request signal
wire ack_sync;             // ack synchronized from destination

reg send_d;   // delayed send
wire send_pulse;
always @(posedge clk_src or posedge reset_src) begin
    if (reset_src)
        send_d <= 1'b0;
    else
        send_d <= send;
end
assign send_pulse = send & ~send_d;

// Handshake pulse
always @(posedge clk_src or posedge reset_src) begin
    if (reset_src) begin
        req <= 1'b0;
        busy <= 1'b0;
    end else if (send_pulse) begin
        req <= 1'b1;        // assert request
        busy <= 1'b1;       // indicate source is busy
        data_latched <= data_in;
    end else if (req || ack_sync) begin
        req <= 1'b0;        // deassert request after ack
        busy <= 1'b0;
    end
end

// Synchronize req to destination
wire req_sync;
sync sync_req ( 
    .clk(clk_dest), 
    .in(req), 
    .out(req_sync) 
);

// Destination domain
reg ack;
reg req_sync_d;

always @(posedge clk_dest or posedge reset_dest) begin
    req_sync_d <= req_sync;
    if (reset_dest) begin
        ack <= 1'b0;
        busy <= 1'b0;
    end
    // Detect rising edge of req
    else if (req_sync && !req_sync_d) begin
        data_out <= data_latched;   // capture stable data
        ack <= 1'b1;            // send ack back
    end else if (!req_sync) begin
        ack <= 1'b0;            // reset ack after request deasserted
    end
end

// Synchronize ack back to source
sync sync_ack ( 
    .clk(clk_src), 
    .in(ack), 
    .out(ack_sync) 
);

endmodule