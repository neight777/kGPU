module registerfile #(
   parameter blockDimx = 512,
   parameter threadIDx = 0,
   parameter blockIDx = 0
) (
    input logic clk,
    input logic reset,

    //control signals
    input logic [1:0] operation,
    input logic [15:0] data_from_lsu,
    output logic [15:0] addr_to_lsu,
    output logic [15:0] data_to_lsu,
    output logic lsu_op,
    output logic lsu_enable,

    //address signals
    input logic [4:0] rd_addr,
    input logic [4:0] rs_addr,
    input logic [4:0] rt_addr,
    input logic [15:0] imm16,

    //output signals
    output logic [15:0] rs,
    output logic [15:0] rt
);

logic [15:0] registers [32];

localparam MOV = 2'b01, STR = 2'b10, LDR = 2'b11;

initial begin
    registers[31] = blockDimx;
    registers[30] = blockIDx;
    registers[29] = threadIDx;
    for (int i = 0; i < 29; i++)
        registers[i] = 16'b0;
end

always_ff @(posedge clk) begin
    if (reset) begin
        for (int i = 0; i < 29; i++) begin
            registers[i] <= 16'b0;
        end
    end else begin
        case (operation)
            MOV:  
                if (rd_addr < 29) begin
                    registers[rd_addr] <= imm16;
                end
            STR: begin
                addr_to_lsu <= registers[rs_addr];
                data_to_lsu <= registers[rt_addr];
                lsu_op      <= 1'b1;   // STORE
                lsu_enable  <= 1'b1;
            end
            LDR: begin
                if (rd_addr < 29) begin
                    addr_to_lsu <= registers[rs_addr];
                    registers[rd_addr] <= data_from_lsu;
                    lsu_op      <= 1'b0;   // LOAD
                    lsu_enable  <= 1'b1;
                end
            end
            default: begin
                lsu_enable <= 1'b0;
                rs <= registers[rs_addr];
                rt <= registers[rt_addr]; 
            end
        endcase
    end
end

endmodule