module ALU (
    input wire reset,

    input logic [1:0] operation,
    input logic [15:0] operand_A,
    input logic [15:0] operand_B,

    output logic [15:0] ALU_out
);

localparam ADD = 2'b00, SUB = 2'b01, MUL = 2'b10, DIV = 2'b11;

logic [15:0] output_register;
assign ALU_out = output_register;

always_comb begin
    if (reset) begin
        output_register = 16'b0;
    end else begin
        case (operation)
            ADD: begin
                output_register = operand_A + operand_B;
            end 
            SUB: begin
                output_register = operand_A - operand_B;
            end
            MUL: begin
                output_register = operand_A * operand_B;
            end  
            DIV: begin
                output_register = operand_A / operand_B;
            end 
            default: begin
                output_register = 16'b0;
            end
        endcase
    end
end
endmodule