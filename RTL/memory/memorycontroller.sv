module memorycontroller #(
    parameter DATAMEM = 1,
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

always_ff @(posedge clk) begin
    if (reset) begin
        state <= IDLE;
        current <= 0;
    end else begin
        case (state)
            IDLE: begin
                for (int i = 0; i < NUM_CONSUMERS; i++) begin
                    if (consumers[i].valid) begin
                        current <= i;
                        mem_we <= consumers[i].we && DATAMEM;
                        mem_addr <= consumers[i].addr;
                        mem_wdata <= consumers[i].wdata;
                        mem_valid <= consumers[i].valid;
                        state <= WAIT;
                        break;
                    end
                end
            end

            WAIT: begin
                if (mem_ready) begin
                    consumers[current].rdata <= mem_rdata;
                    state <= DONE;
                end
            end

            DONE: begin
                current <= 0;
                mem_valid <= 0;
                mem_we <= 0;
                mem_addr <= '0;
                mem_wdata <= '0;
                state <= IDLE;
            end
            default: begin
                //corrupted state
            end
        endcase
    end
end

always_comb begin
    for (int i = 0; i < NUM_CONSUMERS; i++) begin
        consumers[i].done = 1'b0;
    end
    consumers[current].done = (state == DONE);
end

endmodule