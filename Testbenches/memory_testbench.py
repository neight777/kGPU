import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

@cocotb.test()
async def mem_StoreAndRetrieve(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    dut.a_we.value = 1
    dut.a_addr_in.value = 0
    dut.a_data_in.value = 0b1010101010101010
    await Timer(10, unit="ns")
    dut.a_we.value = 0
    dut.a_addr_in.value = 0
    await Timer(10, unit="ns")
    result = dut.a_data_out.value

    assert result == 43690 & 0xFFFF, \
        f"SNR): expected {43690 & 0xFFFF}, got {result}"
    cocotb.log.info(f"PASS  SNR(2863311530) = {result}")

@cocotb.test()
async def mem_StoreAndRetrieve_DualChannel(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    dut.a_we.value = 1
    dut.a_addr_in.value = 0
    dut.a_data_in.value = 0b1010101010101010
    dut.b_we.value = 1
    dut.b_addr_in.value = 1
    dut.b_data_in.value = 0b0101010101010101
    await Timer(10, unit="ns")
    dut.a_we.value = 0
    dut.b_we.value = 0
    dut.a_addr_in.value = 0
    dut.b_addr_in.value = 1
    await Timer(10, unit="ns")
    result = dut.a_data_out.value & dut.b_data_out.value

    assert result == 0 & 0xFFFF, \
        f"SNR): expected {0 & 0xFFFF}, got {result}"
    cocotb.log.info(f"PASS = {result}")
    