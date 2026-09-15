module lsu(
    input logic clk,
    input logic enable,

    //control signals
    input logic operation,

    //global memory address of interest
    input logic [15:0] addr_to_mem_from_registerfile,
    
    //store signals
    input logic [15:0] data_to_mem_from_registerfile,

    //load signal
    output logic [15:0] data_to_registerfile_from_mem,

    input logic [15:0] data_from_mem,
    output logic [15:0] to_mem_addr,
    output logic [15:0] to_mem_data,
    output logic we
);

localparam LOAD = 1'b0, STORE = 1'b1;

always_comb begin
    to_mem_addr = addr_to_mem_from_registerfile;
    to_mem_data = data_to_mem_from_registerfile;
    data_to_registerfile_from_mem = data_from_mem;
    we = enable && (operation == STORE);
end

endmodule