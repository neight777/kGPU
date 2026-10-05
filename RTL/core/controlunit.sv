module controlunit #(
    parameter WARP_SIZE = 32,
    parameter NUM_WARPS = 4,
    localparam WARP_BITS = NUM_WARPS > 1 ? $clog2(NUM_WARPS) : 1
)(
    input logic clk,
    input logic reset,

    //warp
    input  logic [NUM_WARPS-1:0] warp_done,
    output logic [WARP_BITS-1:0] warp_id,
    output logic commit,

    //fetcher
    output logic fetch,
    input logic fetch_done,

    //lanes
    output logic issue,
    input logic [WARP_SIZE-1:0] lane_done
);

typedef enum logic [2:0] {IDLE, FETCH, ISSUE, WAIT, COMMIT} state_t;
state_t state;

logic [WARP_BITS-1:0] next_warp;
logic any_live;

//at least one warp still has running threads
assign any_live = !(&warp_done);

always_comb begin
    next_warp = warp_id;
    for (int k = NUM_WARPS; k >= 1; k--) begin
        //Yosys gets mad without automatic
        //each iter gets temp variable
        automatic int w;
        w = (int'(warp_id) + k) % NUM_WARPS;
        if (!warp_done[w]) begin
            next_warp = WARP_BITS'(w);
        end
    end
end

always_ff @(posedge clk) begin
    if (reset) begin
        state <= IDLE;
        warp_id <= '0;
        fetch <= 0;
        issue <= 0;
        commit <= 0;
    end else begin
        fetch <= 0;
        issue <= 0;
        commit <= 0;
        case (state)
            IDLE: begin
                if (any_live) begin
                    warp_id <= next_warp;
                    fetch <= 1;
                    state <= FETCH;
                end
            end

            FETCH: begin
                if (fetch_done) begin
                    issue <= 1;
                    state <= ISSUE;
                end
            end

            ISSUE: begin
                //lane_done stale. needs to be checked in wait state
                state <= WAIT;
            end

            WAIT: begin
                if (&lane_done) begin
                    commit <= 1;
                    state <= COMMIT;
                end
            end

            COMMIT: begin
                //back to IDLE to pick next warp
                state <= IDLE;
            end

            default: begin
                state <= IDLE;
            end
        endcase
    end
end

endmodule
