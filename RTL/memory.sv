module memory#(
    //width in bits
    parameter width = 16,
    //size in bits
    parameter size = 2**16 * width,
    parameter addr_len = $clog2(size / width)
)(
    input logic clk,

    input logic we,
    input logic [addr_len - 1:0] addr_in,
    input logic [width-1:0] data_in,
    output logic [width-1:0] data_out
);

localparam depth = size / width;

logic [width-1:0] memblock [depth];

always_ff @(posedge clk) begin
    if (we) begin
        memblock[addr_in] <= data_in;
    end
end

always_comb begin
    data_out = memblock[addr_in];
end
endmodule