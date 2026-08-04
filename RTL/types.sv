
typedef enum logic [3:0]
{
    NOP = 8'h00,
    ADD = 8'h01,
    SUB = 8'h02,
    MUL = 8'h03,
    DIV = 8'h04,
    STR = 8'h05,
    LDR = 8'h06,
    RET = 8'h07
} opcodes_t;