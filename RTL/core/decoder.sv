module decoder
import kpgu_pkg::*;
(
    input logic [31:0] instr_bits,

    //to lanes
    output logic [4:0] decoded_rd,
    output logic [4:0] decoded_rs,
    output logic [4:0] decoded_rt,
    output logic [1:0]decoded_alu_op,
    output logic [15:0] decoded_immediate,
    output logic decoded_reg_wb,
    output logic decoded_is_mov,
    output logic decoded_is_mem,
    output logic decoded_load,
    output logic [1:0] decoded_branch_cond,

    //to warps
    output logic decoded_is_branch,
    output logic decoded_is_ret,
    output logic [15:0] decoded_branch_target
);

instr_t instruction;
assign instruction = instr_bits;

always_comb begin
    //fixed fields
    decoded_rs = instruction.rs;
    decoded_rt = instruction.rt;
    decoded_rd = instruction.imm[15:11];
    decoded_immediate = instruction.imm;
    decoded_branch_target = instruction.imm;
    decoded_alu_op = 2'b00;
    decoded_reg_wb = 0;
    decoded_is_mov = 0;
    decoded_is_mem = 0;
    decoded_load = 0;
    decoded_branch_cond = 2'b00;
    decoded_is_branch = 0;
    decoded_is_ret = 0;

    //varying fields
    case (instruction.op)
        ADD: begin
            decoded_reg_wb = 1;
            decoded_alu_op = 2'b00;
        end
        SUB: begin
            decoded_reg_wb = 1;
            decoded_alu_op = 2'b01;
        end
        MUL: begin
            decoded_reg_wb = 1;
            decoded_alu_op = 2'b10;
        end
        DIV: begin
            decoded_reg_wb = 1;
            decoded_alu_op = 2'b11;
        end
        MOV: begin
            //MOV keeps rd in the rs slot so imm can be 16 bits
            decoded_reg_wb = 1;
            decoded_is_mov = 1;
            decoded_rd = instruction.rs;
        end
        LDR: begin
            decoded_is_mem = 1;
            decoded_load = 1;
        end
        STR: begin
            decoded_is_mem = 1;
        end
        BEQ: begin
            decoded_is_branch = 1;
            decoded_branch_cond = 2'b00;
        end
        BNE: begin
            decoded_is_branch = 1;
            decoded_branch_cond = 2'b01;
        end
        BLT: begin
            decoded_is_branch = 1;
            decoded_branch_cond = 2'b10;
        end
        B: begin
            decoded_is_branch = 1;
            decoded_branch_cond = 2'b11;
        end
        RET: begin
            decoded_is_ret = 1;
        end
        default: begin
            //NOP and unknown so do nothing
        end
    endcase
end

endmodule