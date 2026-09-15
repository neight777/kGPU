module registerfile #(
   parameter blockDimx = 8,
   parameter blockIDx = 0,
   parameter threadIDx = 0
) (
    input logic clk,
    input logic reset,

    //address signals
    input logic [4:0] wb_addr,
    input logic [15:0] wb_data,
    input logic wb_enable,
    input logic [4:0] rs_addr,
    input logic [4:0] rt_addr,

    //output signals
    output logic [15:0] rs,
    output logic [15:0] rt
);

logic [15:0] registers [32];

initial begin
    registers[31] = blockDimx;
    registers[30] = blockIDx;
    registers[29] = threadIDx;
    for (int i = 0; i < 29; i++)
        registers[i] = 16'b0;
end

assign rs = registers[rs_addr];
assign rt = registers[rt_addr];

always_ff @(posedge clk) begin
    if (reset) begin
        for (int i = 0; i < 29; i++) begin
            registers[i] <= 16'b0;
        end
    end else begin
        if (wb_enable) begin
            registers[wb_addr] <= wb_data;
        end
    end
end

endmodule