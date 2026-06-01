import cocotb
from cocotb.triggers import RisingEdge
from cocotb.clock import Clock

ADD = 0b00
SUB = 0b01
MUL = 0b10
DIV = 0b11

async def reset_dut(dut, cycles=2):
    dut.reset.value = 1
    dut.en.value = 0
    dut.operand_A.value = 0
    dut.operand_B.value = 0
    dut.operation.value = ADD
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.reset.value = 0

async def prep_inputs(dut, op, a, b, expected, name):
    dut.operation.value = op
    dut.operand_A.value = a
    dut.operand_B.value = b
    dut.en.value = 1
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    result = int(dut.ALU_out.value)
    assert result == expected & 0xFF, \
        f"{name}({a}, {b}): expected {expected & 0xFF}, got {result}"
    cocotb.log.info(f"PASS  {name}({a}, {b}) = {result}")

@cocotb.test()
async def ALU_testADD(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset_dut(dut)
    await prep_inputs(dut, ADD, 10, 5, 15, "ADD")
    await prep_inputs(dut, ADD, 200, 60, 260, "ADD overflow")

@cocotb.test()
async def ALU_testSUB(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset_dut(dut)
    await prep_inputs(dut, SUB, 10, 5, 5, "SUB")
    await prep_inputs(dut, SUB, 5, 6, 255, "SUB underflow")

@cocotb.test()
async def ALU_testDIV(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset_dut(dut)
    await prep_inputs(dut, DIV, 10, 5, 2, "DIV")
    await prep_inputs(dut, DIV, 10, 0, 0, "DIV by zero")
    await prep_inputs(dut, DIV, 11, 10, 1, "Floating point result not implemented")

@cocotb.test()
async def ALU_testMUL(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset_dut(dut)
    await prep_inputs(dut, MUL, 50, 2, 100, "MUL")
    await prep_inputs(dut, MUL, 150, 2, 44, "MUL overflow")
