import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

@cocotb.test()
async def RF_StoreAndRetrieve(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    dut.operation.value = 0b01
    dut.rd_addr.value = 0
    dut.imm16.value = 0b1010101010101010
    await Timer(10, unit="ns")
    dut.operation.value = 0b00
    await Timer(10, unit="ns")
    result = dut.rs.value

    assert result == 43690 & 0xFFFF, \
        f"SNR): expected {43690 & 0xFFFF}, got {result}"
    cocotb.log.info(f"PASS  SNR(2863311530) = {result}")
    