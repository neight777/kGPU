module lsu(
    input logic clk,
    input logic reset,
    memchannelinterface.requester requester,
    input logic load,
    input logic ready,
    output logic done,

    //combinational register file reads
    input logic [15:0] rs_data,     
    input logic [15:0] rt_data,     

    //load writeback
    output logic reg_we,
    output logic [15:0] reg_wdata
);

typedef enum logic {IDLE, WAIT} state_t;

state_t state;

always_ff @(posedge clk) begin
    if (reset) begin
        state <= IDLE;
        done <= 0;
        reg_we <= 0;
        reg_wdata <= '0;
        requester.valid <= 0;
        requester.we <= 0;
        requester.addr <= '0;
        requester.wdata <= '0;
    end else begin
        //done and reg_we are one cycle pulses
        done <= 0;
        reg_we <= 0;
        case (state)
            IDLE: begin
                if (ready) begin
                    requester.valid <= 1;
                    requester.we <= !load;
                    requester.addr <= rt_data;
                    requester.wdata <= rs_data;
                    state <= WAIT;
                end
            end

            WAIT: begin
                if (requester.done) begin
                    requester.valid <= 0;
                    requester.we <= 0;
                    //load writes the returned data to rs
                    reg_we <= load;
                    reg_wdata <= requester.rdata;
                    done <= 1;
                    state <= IDLE;
                end
            end
        endcase
    end
end

endmodule
