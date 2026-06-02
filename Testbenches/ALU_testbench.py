import cocotb
from cocotb.triggers import Timer

ADD = 0b00
SUB = 0b01
MUL = 0b10
DIV = 0b11

async def reset_dut(dut, cycles=2):
    dut.reset.value = 1
    dut.operand_A.value = 0
    dut.operand_B.value = 0
    dut.operation.value = ADD
    dut.reset.value = 0

async def prep_inputs(dut, op, a, b, expected, name):
    dut.operation.value = op
    dut.operand_A.value = a
    dut.operand_B.value = b
    await Timer(5, units="ns")
    result = int(dut.ALU_out.value)
    assert result == expected & 0xFFFFFFFF, \
        f"{name}({a}, {b}): expected {expected & 0xFFFFFFFF}, got {result}"
    cocotb.log.info(f"PASS  {name}({a}, {b}) = {result}")

@cocotb.test()
async def ALU_testADD(dut):
    await reset_dut(dut)
    await prep_inputs(dut, ADD, 10, 5, 15, "ADD")
    await prep_inputs(dut, ADD, 0xFFFFFFFF, 1, 0, "ADD overflow")

@cocotb.test()
async def ALU_testSUB(dut):
    await reset_dut(dut)
    await prep_inputs(dut, SUB, 10, 5, 5, "SUB")
    await prep_inputs(dut, SUB, 0, 1, 0xFFFFFFFF, "SUB underflow")

@cocotb.test()
async def ALU_testDIV(dut):
    await reset_dut(dut)
    await prep_inputs(dut, DIV, 10, 5, 2, "DIV")
    await prep_inputs(dut, DIV, 10, 0, 0, "DIV by zero")
    await prep_inputs(dut, DIV, 11, 10, 1, "Floating point result not implemented")

@cocotb.test()
async def ALU_testMUL(dut):
    await reset_dut(dut)
    await prep_inputs(dut, MUL, 50, 2, 100, "MUL")
    await prep_inputs(dut, MUL, 3000000000, 2, 1705032704, "MUL overflow")

@cocotb.test()
async def ALU_testRESET(dut):
    dut.reset.value = 1
    await Timer(5, unit="ns")
    result = int(dut.ALU_out.value)
    assert result == 0x00000000 & 0xFFFFFFFF, \
        f"RESET(NA, NA): expected {0x00000000 & 0xFFFFFFFF}, got {result}"
    cocotb.log.info(f"PASS  RESET(NA, NA) = {result}")
