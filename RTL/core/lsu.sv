module lsu(
    input logic clk,
    memchannelinterface.requester requester
);

typedef enum [1:0] {IDLE, WAIT, DONE};
endmodule