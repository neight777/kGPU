module ALU (
    input logic [1:0] operation,
    input logic [15:0] operand_A,
    input logic [15:0] operand_B,

    output logic [15:0] ALU_out
);

localparam ADD = 2'b00, SUB = 2'b01, MUL = 2'b10, DIV = 2'b11;

always_comb begin
    case (operation)
        ADD: begin
            ALU_out = operand_A + operand_B;
        end
        SUB: begin
            ALU_out = operand_A - operand_B;
        end
        MUL: begin
            ALU_out = operand_A * operand_B;
        end
        DIV: begin
            ALU_out = '0;
        end
        default: begin
            ALU_out = '0;
        end
    endcase
end
endmodule
