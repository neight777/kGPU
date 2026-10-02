module fetcher#(
    parameter PC_BITS = 16
)(
    input logic clk,
    input logic reset,

    //from controller
    input logic fetch,
    input logic [PC_BITS-1:0] pc,

    //to decoder
    output logic [31:0] instruction,
    //to controller
    output logic fetch_done,

    memchannelinterface.requester mem
);  

localparam IDLE = 1'b0, WAIT = 1'b1;

logic state;
assign mem.we = 0;
assign mem.wdata = '0;

always_ff @(posedge clk) begin
    if (reset) begin
        state <= IDLE;
        mem.valid <= 0;
        fetch_done <= 0;
    end else begin
        fetch_done <= 0;
        case (state)
            IDLE: begin
                if (fetch) begin
                    mem.valid <= 1;
                    mem.addr <= pc;
                    state <= WAIT;
                end
            end
            WAIT: begin
                if (mem.done) begin
                    mem.valid <= 0;
                    instruction <= mem.rdata;
                    fetch_done <= 1;
                    state <= IDLE;
                end
            end
        endcase
    end
end

endmodule