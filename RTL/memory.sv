module memory#(
    //size in bits
    parameter size = 2**16,
    //width in bits
    parameter width = 16,
    parameter addr_len = $clog2(size / width)
)(
    input logic clk,

    //dual channel 
    input logic a_we,
    input logic [addr_len - 1:0] a_addr_in,
    input logic [width-1:0] a_data_in,
    output logic [width-1:0] a_data_out,

    input logic b_we,
    input logic [addr_len - 1:0] b_addr_in,
    input logic [width-1:0] b_data_in,
    output logic [width-1:0] b_data_out
);

localparam depth = size / width;

logic [width-1:0] memblock [depth];

always_ff @(posedge clk ) begin
    if (a_we) begin
        memblock[a_addr_in] <= a_data_in;
    end
    a_data_out <= memblock[a_addr_in];
end

always_ff @(posedge clk ) begin
    if (b_we) begin
        memblock[b_addr_in] <= b_data_in;
    end
    b_data_out <= memblock[b_addr_in];
end

endmodule