import os
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, ClockCycles

#opcodes
NOP, ADD, SUB, MUL, DIV, STR, LDR, RET, MOV, BEQ, BNE, BLT, B = range(13)

#registers r29 = threadIdx, r30 = blockIdx, r31 = blockDim
(r0,  r1,  r2,  r3,  r4,  r5,  r6,  r7,
 r8,  r9,  r10, r11, r12, r13, r14, r15,
 r16, r17, r18, r19, r20, r21, r22, r23,
 r24, r25, r26, r27, r28, r29, r30, r31) = range(32)

NUM_WARPS = 2
WARP_SIZE = 8
NUM_BLOCKS = 16 # more blocks than warp slots, so the dispatcher reuses slots
IN_BASE = 256  # input array lives at mem[256 + gid]

# instr_t: [31:26] op  [25:21] rs  [20:16] rt  [15:0] imm (rd in [15:11])
def enc(op, rs=0, rt=0, imm=0):
    return (op << 26) | (rs << 21) | (rt << 16) | (imm & 0xFFFF)

def alu(op, rd, rs, rt):   return enc(op, rs, rt, rd << 11)
def mov(rd, imm):          return enc(MOV, rd, 0, imm)   # MOV keeps rd in the rs slot
def ldr(rd, raddr):        return enc(LDR, rd, raddr)    # rd = mem[raddr]
def strw(rdata, raddr):    return enc(STR, rdata, raddr) # mem[raddr] = rdata
def ret():                 return enc(RET)
def beq(rs, rt, target):   return enc(BEQ, rs, rt, target) # jmp if rs == rt
def bne(rs, rt, target):   return enc(BNE, rs, rt, target) # jmp if rs != rt
def blt(rs, rt, target):   return enc(BLT, rs, rt, target) # jmp if rs < rt (signed)
def b(target):             return enc(B, 0, 0, target)     # always jmp

#regular kernel
ADD_KERNEL = [
    mov(r1, 5),              # r1 = 5
    mov(r7, IN_BASE),        # r7 = 256
    alu(MUL, r3, r30, r31),  # r3 = blockIdx * blockDim
    alu(ADD, r4, r3, r29),   # r4 = blockIdx * blockDim + threadIdx = gid
    alu(ADD, r6, r4, r7),    # r6 = 256 + gid
    ldr(r5, r6),             # r5 = in[gid]
    alu(ADD, r2, r5, r1),    # r2 = in[gid] + 5
    strw(r2, r4),            # out[gid] = r2
    ret(),
]

#diverging kernel
DIVERGE_KERNEL = [
    alu(ADD, r1, r29, r0),   # r1 = threadIdx 
    mov(r2, 1),              # r2 = 1
    mov(r6, 0),              # r6 = 0
    beq(r1, r0, 7),          # if threadIdx == 0 skip loop
    alu(SUB, r1, r1, r2),    # r1 = r1 - 1
    alu(ADD, r6, r6, r2),    #r6 = r6 + 1
    bne(r1, r0, 4),          # JMP back to loop
    alu(MUL, r3, r30, r31),  # r3 = blockIdx * blockDim
    alu(ADD, r4, r3, r29),   # r4 = blockIdx * blockDim + threadIdx = gid
    strw(r6, r4),            # out[gid] = r6
    ret()
]

async def memory_model(clk, valid, we, addr, wdata, rdata, ready, mem, width_mask):
    ready.value = 0
    while True:
        await FallingEdge(clk)
        if int(ready.value):
            # controller is in DONE this cycle. dont serve twice
            ready.value = 0
            continue
        if int(valid.value):
            a = int(addr.value)
            if we is not None and int(we.value):
                mem[a] = int(wdata.value) & width_mask
            rdata.value = mem.get(a, 0)
            ready.value = 1


async def run_kernel(dut, kernel, dmem):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())

    imem = {pc: word for pc, word in enumerate(kernel)}

    cocotb.start_soon(memory_model(dut.clk, dut.imem_valid, None, dut.imem_addr, None, dut.imem_rdata, dut.imem_ready, imem, 0xFFFFFFFF))
    cocotb.start_soon(memory_model(dut.clk, dut.dmem_valid, dut.dmem_we, dut.dmem_addr, dut.dmem_wdata, dut.dmem_rdata, dut.dmem_ready, dmem, 0xFFFF))

    dut.reset.value = 1
    dut.start.value = 0
    dut.start_pc.value = 0
    dut.num_blocks.value = 0
    dut.blockDimx.value = 0
    await ClockCycles(dut.clk, 3)
    await FallingEdge(dut.clk)
    dut.reset.value = 0

    # describe the kernel, the dispatcher hands blocks to free warp slots
    await FallingEdge(dut.clk)
    dut.start_pc.value = 0
    dut.num_blocks.value = NUM_BLOCKS
    dut.blockDimx.value = WARP_SIZE
    dut.start.value = 1
    await FallingEdge(dut.clk)
    dut.start.value = 0

    for cycle in range(200000):
        await RisingEdge(dut.clk)
        if int(dut.kernel_done.value):
            break
    else:
        assert False, "kernel did not finish in 200000 cycles"
    return cycle

# one row per block, one column per thread. wrong outputs show as got!=expected
def check_outputs(dut, name, dmem, expected, cycles):
    total = NUM_BLOCKS * WARP_SIZE
    lines = [f"{name}: {NUM_BLOCKS} blocks x {WARP_SIZE} threads, finished in {cycles} cycles", ""]
    lines.append("| block | " + " | ".join(f"{'t' + str(t):>3}" for t in range(WARP_SIZE)) + " | result |")
    lines.append("|------:|" + "----:|" * WARP_SIZE + ":------:|")

    errors = []
    for block in range(NUM_BLOCKS):
        cells = []
        result = "PASS"
        for t in range(WARP_SIZE):
            gid = block * WARP_SIZE + t
            got = dmem.get(gid)
            exp = expected(gid) & 0xFFFF
            if got == exp:
                cells.append(f"{got:>3}")
            else:
                cells.append(f"{got}!={exp}")
                errors.append(f"out[{gid}] expected {exp}, got {got}")
                result = "FAIL"
        lines.append(f"| {block:>5} | " + " | ".join(cells) + f" |  {result}  |")

    lines += ["", f"{total - len(errors)}/{total} outputs correct"]
    #markdown table next to this file ready to paste in the readme
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), f"{name}_results.md")
    with open(path, "w") as f:
        f.write("\n".join(lines) + "\n")
    dut._log.info("\n".join(lines))
    dut._log.info(f"results written to {path}")
    assert not errors, f"{len(errors)} wrong outputs, first: " + "; ".join(errors[:5])


@cocotb.test()
async def add_kernel_test(dut):
    dmem = {}
    for gid in range(NUM_BLOCKS * WARP_SIZE):
        dmem[IN_BASE + gid] = gid * 3
    cycles = await run_kernel(dut, ADD_KERNEL, dmem)
    #out[gid] = in[gid] + 5
    check_outputs(dut, "add_const", dmem, lambda gid: gid * 3 + 5, cycles)


@cocotb.test()
async def diverge_kernel_test(dut):
    dmem = {}
    cycles = await run_kernel(dut, DIVERGE_KERNEL, dmem)
    #each thread loops threadIdx times
    check_outputs(dut, "diverge", dmem, lambda gid: gid % WARP_SIZE, cycles)
