module lane#(
    parameter NUM_WARPS = 4,
    parameter LANE_ID = 0,
    localparam WARP_BITS = NUM_WARPS > 1 ? $clog2(NUM_WARPS) : 1
)(
    input logic clk,
    input logic reset,
    input  logic [WARP_BITS-1:0] warp_id,

    //decoded instruction
    input  logic [1:0]  alu_op,
    input  logic [4:0]  rd,
    input  logic [4:0]  rs,
    input  logic [4:0]  rt,
    input  logic [15:0] immediate,
    input  logic wb,          
    input  logic is_mov,        
    input  logic is_mem,
    input  logic load,
    input  logic [1:0]  branch_cond,

    //one cycle pulse at the start of each instruction
    input  logic issue,

    //per lane
    input  logic active,
    output logic lane_done,
    output logic taken,

    //launch per warp
    input  logic [NUM_WARPS-1:0] launch,
    input  logic [15:0] blockDimx,
    input  logic [15:0] blockIDx,
    memchannelinterface.requester mem
);

localparam BEQ = 2'b00, BNE = 2'b01, BLT = 2'b10, B = 2'b11;

logic [15:0] rs_val, rt_val, alu_out;

logic lsu_done, lsu_reg_we;
logic [15:0] lsu_reg_wdata;

registerfile #(.NUM_WARPS(NUM_WARPS)) u_rf (
    .clk, 
    .reset, 
    .warp_id,
    .launch, 
    .blockDimx, 
    .blockIDx,
    .threadIDx(16'(LANE_ID)),
    .wb_enable(issue && active && wb),
    .wb_addr(rd),
    .wb_data(is_mov ? immediate : alu_out),
    .rs_addr(rs), 
    .rt_addr(rt),
    .rs(rs_val), 
    .rt(rt_val),
    .lsu_we(lsu_reg_we),
    .lsu_addr(rs),
    .lsu_wdata(lsu_reg_wdata)
);

ALU u_alu (
    .operation(alu_op),
    .operand_A(rs_val),
    .operand_B(rt_val),
    .ALU_out(alu_out)
);

lsu u_lsu (
    .clk, .reset,
    .requester(mem),
    .load,
    //drop ready once done
    .ready(active && is_mem && !lane_done),
    .done(lsu_done),
    .rs_data(rs_val),
    .rt_data(rt_val),
    .reg_we(lsu_reg_we),
    .reg_wdata(lsu_reg_wdata)
);

logic done_q;
assign lane_done = done_q || lsu_done;

always_ff @(posedge clk) begin
    if (reset) begin
        done_q <= 1;
    end else if (issue) begin
        done_q <= !(active && is_mem);
    end else if (lsu_done) begin
        done_q <= 1;
    end
end

always_comb begin
    case (branch_cond)
        BEQ: taken = (rs_val == rt_val);
        BNE: taken = (rs_val != rt_val);
        BLT: taken = ($signed(rs_val) < $signed(rt_val));
        B: taken = 1;
        default: taken = 0;
    endcase
end

endmodule
