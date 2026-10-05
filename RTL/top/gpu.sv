module gpu #(
    parameter NUM_SMS = 1,
    parameter NUM_WARPS = 2,
    parameter WARP_SIZE = 8,
    parameter PC_BITS = 16,
    localparam SM_BITS = NUM_SMS > 1 ? $clog2(NUM_SMS) : 1,
    localparam WARP_BITS = NUM_WARPS > 1 ? $clog2(NUM_WARPS) : 1
)(
    input  logic clk,
    input  logic reset,

    //instruction memory requst
    output logic imem_valid,
    output logic [PC_BITS-1:0] imem_addr,
    //instruction memory response
    input  logic [31:0] imem_rdata,
    input  logic imem_ready,

    //data memory request
    output logic dmem_valid,
    output logic dmem_we,
    output logic [15:0] dmem_wdata,
    output logic [15:0] dmem_addr,
    //data memory response
    input  logic [15:0] dmem_rdata,
    input  logic dmem_ready,

    //kernel launch from host
    input  logic start,
    input  logic [PC_BITS-1:0] start_pc,
    input  logic [15:0] num_blocks,
    input  logic [15:0] blockDimx,
    output logic kernel_done
);

memchannelinterface #(.DATA_BITS(32), .ADDR_BITS(PC_BITS)) imem_ch [NUM_SMS] ();
memchannelinterface dmem_ch [NUM_SMS*WARP_SIZE] ();

logic [NUM_WARPS-1:0] warp_done [NUM_SMS];

//launch from dispatcher to sms
logic launch;
logic [SM_BITS-1:0] launch_sm;
logic [WARP_BITS-1:0] launch_warp;
logic [PC_BITS-1:0] launch_pc;
logic [WARP_SIZE-1:0] thread_enable;
logic [15:0] launch_blockDimx;
logic [15:0] blockIDx;

dispatcher #(
    .NUM_SMS(NUM_SMS),
    .NUM_WARPS(NUM_WARPS),
    .WARP_SIZE(WARP_SIZE),
    .PC_BITS(PC_BITS)
) u_dispatcher (
    .clk,
    .reset,
    .start,
    .start_pc,
    .num_blocks,
    .blockDimx,
    .kernel_done,
    .warp_done,
    .launch,
    .launch_sm,
    .launch_warp,
    .launch_pc,
    .thread_enable,
    .launch_blockDimx,
    .blockIDx
);

//sm instantiation
for (genvar s = 0; s < NUM_SMS; s++) begin : sms
    sm #(
        .NUM_WARPS(NUM_WARPS),
        .WARP_SIZE(WARP_SIZE),
        .PC_BITS(PC_BITS)
    ) u_sm (
        .clk,
        .reset,
        .launch(launch && launch_sm == SM_BITS'(s)),
        .launch_warp,
        .start_pc(launch_pc),
        .thread_enable,
        .blockDimx(launch_blockDimx),
        .blockIDx,
        .warp_done(warp_done[s]),
        .imem(imem_ch[s]),
        .dmem(dmem_ch[s*WARP_SIZE +: WARP_SIZE])
    );
end


//instruction memory
memorycontroller #(.NUM_CONSUMERS(NUM_SMS), .DATA_WIDTH(32), .ADDR_BITS(PC_BITS)) u_imem_ctrl (
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

//data memory
memorycontroller #(.NUM_CONSUMERS(NUM_SMS*WARP_SIZE), .DATA_WIDTH(16), .ADDR_BITS(16)) u_dmem_ctrl (
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