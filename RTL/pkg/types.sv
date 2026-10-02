package kpgu_pkg;
    typedef enum logic [5:0]
    {
        NOP,
        ADD,
        SUB,
        MUL,
        DIV,
        STR,
        LDR,
        RET,
        MOV,
        BEQ,
        BNE,
        BLT,
        B
    } opcodes_t;

    typedef struct packed {
        opcodes_t    op;    //[31:26]
        logic [4:0]  rs;    //[25:21]
        logic [4:0]  rt;    //[20:16]
        logic [15:0] imm;   //[15:0]    Rd is [15:11] when imm isnt used
    } instr_t;

endpackage
