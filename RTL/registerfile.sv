module registerfile #(
   parameter blockDimx = 512,
   parameter threadIDx = 0,
   parameter blockIDx = 0
) (
    input logic clk,
    input logic reset,
    input logic we,

    input logic [15:0] dataIn,
    input logic [4:0] addr,
    output logic [15:0] data
);

logic [15:0] output_register;
assign data = output_register;

logic [15:0] registers [32];

initial begin
    registers[31] = blockDimx;
    registers[30] = blockIDx;
    registers[29] = threadIDx;
    for (int i = 0; i < 29; i++)
        registers[i] = 16'b0;
end

always_ff @(posedge clk) begin
    if (reset) begin
        for (int i = 0; i < 29; i++)
            registers[i] <= 16'b0;
    end

    if (we) begin
        registers[addr] <= dataIn;
    end else begin
        output_register <= registers[addr];
    end
end

endmodule