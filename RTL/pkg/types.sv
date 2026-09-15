package kpgu_pkg;
    typedef enum logic [7:0]
    {
        NOP = 8'h00,
        ADD = 8'h01,
        SUB = 8'h02,
        MUL = 8'h03,
        DIV = 8'h04,
        STR = 8'h05,
        LDR = 8'h06,
        RET = 8'h07,
        MOV = 8'h08
    } opcodes_t;

endpackage