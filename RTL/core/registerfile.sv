module registerfile #(
    parameter NUM_WARPS = 4,
    localparam WARP_BITS = NUM_WARPS > 1 ? $clog2(NUM_WARPS) : 1
) (
    input logic clk,
    input logic reset,

    //selects which warp's registers are read and written
    input logic [WARP_BITS-1:0] warp_id,

    //load registers for new block/warp, one bit per warp
    input logic [NUM_WARPS-1:0] launch,
    input logic [15:0] blockDimx,
    input logic [15:0] blockIDx,
    input logic [15:0] threadIDx,

    //writeback from ALU or MOV immediate
    input logic [4:0] wb_addr,
    input logic [15:0] wb_data,
    input logic wb_enable,

    input logic [4:0] rs_addr,
    input logic [4:0] rt_addr,

    //LSU load writeback
    input logic lsu_we,
    input logic [4:0] lsu_addr,
    input logic [15:0] lsu_wdata,

    //output signals
    output logic [15:0] rs,
    output logic [15:0] rt
);

logic [15:0] registers [NUM_WARPS][32];

assign rs = registers[warp_id][rs_addr];
assign rt = registers[warp_id][rt_addr];

always_ff @(posedge clk) begin
    if (reset) begin
        for (int w = 0; w < NUM_WARPS; w++) begin
            for (int i = 0; i < 32; i++) begin
                registers[w][i] <= '0;
            end
        end
    end else begin
        //single issue, so LSU and writeback never happen in the same cycle
        if (lsu_we) begin
            registers[warp_id][lsu_addr] <= lsu_wdata;
        end
        if (wb_enable) begin
            registers[warp_id][wb_addr] <= wb_data;
        end
        //launch comes last so it wins over a write to the same warp
        for (int w = 0; w < NUM_WARPS; w++) begin
            if (launch[w]) begin
                registers[w][31] <= blockDimx;
                registers[w][30] <= blockIDx;
                registers[w][29] <= threadIDx;
                for (int i = 0; i < 29; i++) begin
                    registers[w][i] <= '0;
                end
            end
        end
    end
end

endmodule
