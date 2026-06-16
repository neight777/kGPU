import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

@cocotb.test()
async def RF_StoreAndRetrieve(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    dut.we.value = 1
    dut.addr.value = 0
    dut.dataIn.value = 0b10101010101010101010101010101010
    await Timer(10, unit="ns")
    dut.we.value = 0
    dut.addr.value = 0
    await Timer(10, unit="ns")
    result = dut.data.value

    assert result == 2863311530 & 0xFFFFFFFF, \
        f"SNR): expected {2863311530 & 0xFFFFFFFF}, got {result}"
    cocotb.log.info(f"PASS  SNR(2863311530) = {result}")
    