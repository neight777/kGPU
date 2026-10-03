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

NUM_WARPS = 4
WARP_SIZE = 32
IN_BASE = 256  # input array lives at mem[256 + gid]

# instr_t: [31:26] op  [25:21] rs  [20:16] rt  [15:0] imm (rd in [15:11])
def enc(op, rs=0, rt=0, imm=0):
    return (op << 26) | (rs << 21) | (rt << 16) | (imm & 0xFFFF)

def alu(op, rd, rs, rt):   return enc(op, rs, rt, rd << 11)
def mov(rd, imm):          return enc(MOV, rd, 0, imm)   # MOV keeps rd in the rs slot
def ldr(rd, raddr):        return enc(LDR, rd, raddr)    # rd = mem[raddr]
def strw(rdata, raddr):    return enc(STR, rdata, raddr) # mem[raddr] = rdata
def ret():                 return enc(RET)

KERNEL = [
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


@cocotb.test()
async def sm_first_kernel(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())

    imem = {pc: word for pc, word in enumerate(KERNEL)}
    dmem = {}
    for gid in range(NUM_WARPS * WARP_SIZE):
        dmem[IN_BASE + gid] = gid * 3

    cocotb.start_soon(memory_model(dut.clk, dut.imem_valid, None, dut.imem_addr, None, dut.imem_rdata, dut.imem_ready, imem, 0xFFFFFFFF))
    cocotb.start_soon(memory_model(dut.clk, dut.dmem_valid, dut.dmem_we, dut.dmem_addr, dut.dmem_wdata, dut.dmem_rdata, dut.dmem_ready, dmem, 0xFFFF))

    dut.reset.value = 1
    dut.launch.value = 0
    dut.launch_warp.value = 0
    dut.start_pc.value = 0
    dut.thread_enable.value = 0
    dut.blockDimx.value = 0
    dut.blockIDx.value = 0
    await ClockCycles(dut.clk, 3)
    await FallingEdge(dut.clk)
    dut.reset.value = 0

    # one block per warp slot
    for w in range(NUM_WARPS):
        await FallingEdge(dut.clk)
        dut.launch.value = 1
        dut.launch_warp.value = w
        dut.start_pc.value = 0
        dut.thread_enable.value = (1 << WARP_SIZE) - 1
        dut.blockDimx.value = WARP_SIZE
        dut.blockIDx.value = w
    await FallingEdge(dut.clk)
    dut.launch.value = 0

    for cycle in range(50000):
        await RisingEdge(dut.clk)
        if int(dut.done.value):
            break
    else:
        assert False, "kernel did not finish in 50000 cycles"
    dut._log.info(f"kernel finished after {cycle} cycles")

    errors = []
    for gid in range(NUM_WARPS * WARP_SIZE):
        expected = (gid * 3 + 5) & 0xFFFF
        got = dmem.get(gid)
        if got != expected:
            errors.append(f"out[{gid}] expected {expected}, got {got}")
    assert not errors, f"{len(errors)} wrong outputs, first: " + "; ".join(errors[:5])
