typedef enum logic [1:0] {  
    ADD = 2'b00,
    SUB = 2'b01,
    MUL = 2'b10,
    DIV = 2'b11
} operation_t;

module ALU (
    input wire reset,
    input wire clk,
    input wire en,

    input operation_t operation,
    input logic [7:0] operand_A,
    input logic [7:0] operand_B,

    output logic [7:0] ALU_out
);

logic [7:0] output_register;
assign ALU_out = output_register;

always @(posedge clk) begin
    if (reset) begin
        output_register <= 8'b0;
    end else if (en) begin
        case (operation)
            ADD: begin
                output_register <= operand_A + operand_B;
            end 
            SUB: begin
                output_register <= operand_A - operand_B;
            end
            MUL: begin
                output_register <= operand_A * operand_B;
            end  
            DIV: begin
                output_register <= operand_A / operand_B;
            end 
            default: begin
                output_register <= 8'b0;
            end
        endcase
    end
end
endmodule