module sm #(
    parameter NUM_WARPS = 4,
    parameter WARP_SIZE = 32,
    parameter PC_BITS = 16,
    localparam WARP_BITS = NUM_WARPS > 1 ? $clog2(NUM_WARPS) : 1
)(
    input logic clk,
    input logic reset,

    //kernel launch
    input logic launch,
    input logic [WARP_BITS-1:0] launch_warp,
    input logic [PC_BITS-1:0] start_pc,
    input logic [WARP_SIZE-1:0] thread_enable,
    input logic [15:0] blockDimx,
    input logic [15:0] blockIDx,
    output logic done,

    //instruction memory
    output logic imem_valid,
    output logic [PC_BITS-1:0] imem_addr,
    input logic [31:0] imem_rdata,
    input logic imem_ready,

    //data memory
    output logic dmem_valid,
    output logic dmem_we,
    output logic [15:0] dmem_addr,
    output logic [15:0] dmem_wdata,
    input logic [15:0] dmem_rdata,
    input logic dmem_ready
);

//control
logic [WARP_BITS-1:0] warp_id;
logic fetch;
logic fetch_done;
logic issue;
logic commit;

//warps
logic [PC_BITS-1:0] warp_pc [NUM_WARPS];
logic [WARP_SIZE-1:0] exec_mask [NUM_WARPS];
logic [NUM_WARPS-1:0] warp_done;
logic [NUM_WARPS-1:0] launch_vec;

//lanes
logic [WARP_SIZE-1:0] lane_done;
logic [WARP_SIZE-1:0] taken_mask;

//decoded instruction
logic [31:0] instruction;
logic [4:0] dec_rd; 
logic [4:0] dec_rs; 
logic [4:0]dec_rt;
logic [1:0] dec_alu_op; 
logic [1:0] dec_branch_cond;
logic [15:0] dec_immediate;
logic [15:0] dec_branch_target;
logic dec_wb; 
logic dec_is_mov;
logic dec_is_mem;
logic dec_load;
logic dec_is_branch;
logic dec_is_ret;

assign launch_vec = launch ? (NUM_WARPS'(1) << launch_warp) : '0;
assign done = &warp_done;

controlunit #(.WARP_SIZE(WARP_SIZE), .NUM_WARPS(NUM_WARPS)) u_control (
    .clk, 
    .reset,
    .warp_done,
    .warp_id,
    .commit,
    .fetch,
    .fetch_done,
    .issue,
    .lane_done
);

//instruction memory one fetcher
memchannelinterface #(.ADDR_BITS(PC_BITS), .DATA_BITS(32)) imem_ch [1] ();

fetcher #(.PC_BITS(PC_BITS)) u_fetcher (
    .clk, 
    .reset,
    .fetch,
    .pc(warp_pc[warp_id]),
    .instruction,
    .fetch_done,
    .mem(imem_ch[0])
);

memorycontroller #(.NUM_CONSUMERS(1), .DATA_WIDTH(32), .ADDR_BITS(PC_BITS)) u_imem_ctrl (
    .clk, 
    .reset,
    .consumers(imem_ch),
    .mem_valid(imem_valid),
    .mem_we(),
    .mem_addr(imem_addr),
    .mem_wdata(),
    .mem_rdata(imem_rdata),
    .mem_ready(imem_ready)
);

decoder u_decoder (
    .instr_bits(instruction),
    .decoded_rd(dec_rd),
    .decoded_rs(dec_rs),
    .decoded_rt(dec_rt),
    .decoded_alu_op(dec_alu_op),
    .decoded_immediate(dec_immediate),
    .decoded_reg_wb(dec_wb),
    .decoded_is_mov(dec_is_mov),
    .decoded_is_mem(dec_is_mem),
    .decoded_load(dec_load),
    .decoded_branch_cond(dec_branch_cond),
    .decoded_is_branch(dec_is_branch),
    .decoded_is_ret(dec_is_ret),
    .decoded_branch_target(dec_branch_target)
);

for (genvar w = 0; w < NUM_WARPS; w++) begin : warps
    warp #(.WARP_SIZE(WARP_SIZE), .PC_BITS(PC_BITS)) u_warp (
        .clk, 
        .reset,
        .start(launch_vec[w]),
        .start_pc,
        .thread_enable,
        //only the selected warp retires the instruction
        .commit(commit && warp_id == WARP_BITS'(w)),
        .is_branch(dec_is_branch),
        .is_ret(dec_is_ret),
        .taken_mask,
        .branch_target(dec_branch_target),
        .warp_pc(warp_pc[w]),
        .exec_mask(exec_mask[w]),
        .warp_done(warp_done[w])
    );
end

//data memory one LSU per lane
memchannelinterface #(.ADDR_BITS(16), .DATA_BITS(16)) dmem_ch [WARP_SIZE] ();

for (genvar l = 0; l < WARP_SIZE; l++) begin : lanes
    lane #(.NUM_WARPS(NUM_WARPS), .LANE_ID(l)) u_lane (
        .clk, 
        .reset,
        .warp_id,
        .alu_op(dec_alu_op),
        .rd(dec_rd),
        .rs(dec_rs),
        .rt(dec_rt),
        .immediate(dec_immediate),
        .wb(dec_wb),
        .is_mov(dec_is_mov),
        .is_mem(dec_is_mem),
        .load(dec_load),
        .branch_cond(dec_branch_cond),
        .issue,
        .active(exec_mask[warp_id][l]),
        .lane_done(lane_done[l]),
        .taken(taken_mask[l]),
        .launch(launch_vec),
        .blockDimx,
        .blockIDx,
        .mem(dmem_ch[l])
    );
end

memorycontroller #(.NUM_CONSUMERS(WARP_SIZE), .DATA_WIDTH(16), .ADDR_BITS(16)) u_dmem_ctrl (
    .clk, 
    .reset,
    .consumers(dmem_ch),
    .mem_valid(dmem_valid),
    .mem_we(dmem_we),
    .mem_addr(dmem_addr),
    .mem_wdata(dmem_wdata),
    .mem_rdata(dmem_rdata),
    .mem_ready(dmem_ready)
);

endmodule
