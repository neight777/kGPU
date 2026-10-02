module memorycontroller #(
    parameter NUM_CONSUMERS = 4,
    parameter DATA_WIDTH = 16,
    parameter ADDR_BITS = 16
)(
    input logic clk,
    input logic reset,
    memchannelinterface.consumer consumers [NUM_CONSUMERS],

    output logic mem_valid,
    output logic mem_we,
    output logic [ADDR_BITS-1:0]  mem_addr,
    output logic [DATA_WIDTH-1:0] mem_wdata,
    input logic [DATA_WIDTH-1:0] mem_rdata,
    input logic mem_ready
);

typedef enum logic [1:0] {IDLE, WAIT, DONE} state_t;
state_t state;
logic [$clog2(NUM_CONSUMERS)-1:0] current;
logic [DATA_WIDTH-1:0] rdata;

logic [NUM_CONSUMERS-1:0] c_valid;
logic [NUM_CONSUMERS-1:0] c_we;
logic [ADDR_BITS-1:0] c_addr [NUM_CONSUMERS];
logic [DATA_WIDTH-1:0] c_wdata [NUM_CONSUMERS];

for (genvar i = 0; i < NUM_CONSUMERS; i++) begin : flatten
    assign c_valid[i] = consumers[i].valid;
    assign c_we[i] = consumers[i].we;
    assign c_addr[i] = consumers[i].addr;
    assign c_wdata[i] = consumers[i].wdata;
    assign consumers[i].rdata = rdata;
    assign consumers[i].done = (state == DONE) && (current == i);
end

always_ff @(posedge clk) begin
    if (reset) begin
        state <= IDLE;
        current <= 0;
        rdata <= '0;
        mem_valid <= 0;
        mem_we <= 0;
        mem_addr <= '0;
        mem_wdata <= '0;
    end else begin
        case (state)
            IDLE: begin
                for (int i = NUM_CONSUMERS-1; i >= 0; i--) begin
                    if (c_valid[i]) begin
                        current <= i[$clog2(NUM_CONSUMERS)-1:0];
                        mem_we <= c_we[i];
                        mem_addr <= c_addr[i];
                        mem_wdata <= c_wdata[i];
                        mem_valid <= 1;
                        state <= WAIT;
                    end
                end
            end

            WAIT: begin
                if (mem_ready) begin
                    rdata <= mem_rdata;
                    state <= DONE;
                end
            end

            DONE: begin
                mem_valid <= 0;
                state <= IDLE;
            end
            default: begin
                //corrupted state
                state <= IDLE;
            end
        endcase
    end
end

endmodule
