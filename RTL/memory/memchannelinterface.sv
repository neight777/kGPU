interface memchannelinterface #(
    parameter ADDR_BITS = 16,
    parameter DATA_BITS = 16
)(
    logic valid,
    logic we,
    logic [ADDR_BITS-1:0] addr,
    logic [DATA_BITS-1:0] wdata,
    logic [DATA_BITS-1:0] rdata,
    logic done
);

modport requester (
    output valid, we, addr, wdata,
    input  rdata, done
);
modport consumer (
    input  valid, we, addr, wdata,
    output rdata, done
);

endinterface