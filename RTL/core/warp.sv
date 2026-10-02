module warp #(
    parameter WARP_SIZE = 32,
    parameter PC_BITS = 16
) (
    input logic clk,
    input logic reset,

    //load every enabled thread with start_pc
    input logic start,
    input logic [PC_BITS-1:0] start_pc,
    input logic [WARP_SIZE-1:0] thread_enable,

    //instruction retire from core
    input logic commit,
    input logic is_branch,
    input logic is_ret,
    input logic [WARP_SIZE-1:0] taken_mask,
    input logic [PC_BITS-1:0] branch_target,

    //to fetch/scheduler
    output logic [PC_BITS-1:0] warp_pc,
    output logic [WARP_SIZE-1:0] exec_mask,
    output logic warp_done
);

//pc per thread
logic [PC_BITS-1:0] pc [WARP_SIZE];
logic [WARP_SIZE-1:0] finished;

assign warp_done = &finished;

//fetch lowest pc among live threads and execute until that jit catches up
always_comb begin
    warp_pc = '1;
    for (int i = 0; i < WARP_SIZE; i++) begin
        if (!finished[i] && pc[i] < warp_pc) begin
            warp_pc = pc[i];
        end
    end
    for (int i = 0; i < WARP_SIZE; i++) begin
        exec_mask[i] = !finished[i] && (pc[i] == warp_pc);
    end
end

always_ff @(posedge clk) begin
    if (reset) begin
        finished <= '1;
    end else if (start) begin
        //one hot bitwise not to know thread states
        finished <= ~thread_enable;
        for (int i = 0; i < WARP_SIZE; i++) begin
            pc[i] <= start_pc;
        end
    end else if (commit) begin
        //only threads that executed this instruction advance
        for (int i = 0; i < WARP_SIZE; i++) begin
            if (exec_mask[i]) begin
                if (is_ret) begin
                    finished[i] <= 1;
                end else if (is_branch && taken_mask[i]) begin
                    pc[i] <= branch_target;
                end else begin
                    pc[i] <= pc[i] + 1;
                end
            end
        end
    end
end

endmodule
