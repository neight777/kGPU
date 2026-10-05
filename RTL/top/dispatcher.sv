module dispatcher #(
    parameter NUM_SMS = 1,
    parameter NUM_WARPS = 4,
    parameter WARP_SIZE = 32,
    parameter PC_BITS = 16,
    localparam SM_BITS = NUM_SMS > 1 ? $clog2(NUM_SMS) : 1,
    localparam WARP_BITS = NUM_WARPS > 1 ? $clog2(NUM_WARPS) : 1
)(
    input  logic clk,
    input  logic reset,

    //from testbench
    input  logic start,
    input  logic [PC_BITS-1:0] start_pc,
    input  logic [15:0] num_blocks,
    input  logic [15:0] blockDimx,
    output logic kernel_done,           

    //slot status from every sm
    input  logic [NUM_WARPS-1:0] warp_done [NUM_SMS],

    //to sms
    output logic launch,
    output logic [SM_BITS-1:0] launch_sm,
    output logic [WARP_BITS-1:0] launch_warp,
    output logic [PC_BITS-1:0] launch_pc,
    output logic [WARP_SIZE-1:0] thread_enable,
    output logic [15:0] launch_blockDimx,
    output logic [15:0] blockIDx
);

//kernel description
logic running;
logic [15:0] next_block;
logic [15:0] num_blocks_q;
logic [PC_BITS-1:0] start_pc_q;
logic [15:0] blockDimx_q;

assign launch_pc = start_pc_q;
assign launch_blockDimx = blockDimx_q;

//one bit per thread that exists in the block
always_comb begin
    for (int i = 0; i < WARP_SIZE; i++) begin
        thread_enable[i] = 16'(i) < blockDimx_q;
    end
end

//first free slot
logic found;
logic [SM_BITS-1:0] free_sm;
logic [WARP_BITS-1:0] free_warp;

always_comb begin
    found = 0;
    free_sm = '0;
    free_warp = '0;
    //loops run backwards so the lowest free slot is assigned last and wins
    for (int s = NUM_SMS-1; s >= 0; s--) begin
        for (int w = NUM_WARPS-1; w >= 0; w--) begin
            if (warp_done[s][w] && !(launch && launch_sm == SM_BITS'(s) && launch_warp == WARP_BITS'(w))) begin
                found = 1;
                free_sm = SM_BITS'(s);
                free_warp = WARP_BITS'(w);
            end
        end
    end
end

//every warp on every sm finished
logic all_done;

always_comb begin
    all_done = 1;
    for (int s = 0; s < NUM_SMS; s++) begin
        all_done = all_done && (&warp_done[s]);
    end
end

always_ff @(posedge clk) begin
    if (reset) begin
        running <= 0;
        kernel_done <= 0;
        launch <= 0;
        next_block <= '0;
    end else begin
        //launch is a one cycle pulse
        launch <= 0;
        if (start) begin
            num_blocks_q <= num_blocks;
            start_pc_q <= start_pc;
            blockDimx_q <= blockDimx;
            next_block <= '0;
            running <= 1;
            kernel_done <= 0;
        end else if (running) begin
            if (next_block < num_blocks_q) begin
                if (found) begin
                    launch <= 1;
                    launch_sm <= free_sm;
                    launch_warp <= free_warp;
                    blockIDx <= next_block;
                    next_block <= next_block + 1;
                end
            //the last launched warp still reads done while launch is high
            end else if (all_done && !launch) begin
                running <= 0;
                kernel_done <= 1;
            end
        end
    end
end

endmodule
