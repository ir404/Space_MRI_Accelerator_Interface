----------------------------------------------------------------------------------
-- Package Name:    space_mri_pkg
-- Author:          Imran
-- Last Modified:   13 November 2026

-- Description:  Global constants and types for the Space MRI Hardware Accelerator.
--               Includes the 5-bit/3-bit structured command and error header.
----------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

PACKAGE space_mri_pkg IS

    -- 1. System Constants
    CONSTANT SYS_CLK_FREQ : NATURAL := 100_000_000;                 -- 100 MHz Basys 3 Clock
    CONSTANT BAUD_RATE    : NATURAL := 115200;                      -- used in uart_tx

    -- 2. Communication Protocol Codes (Header Bits 7:3)
    -- Base opcodes are shifted left by 3 bits to leave room for error flags.
    -- ACC Base: 00001 -> Shifted: 0000 1000 (0x08)
    -- HK  Base: 00010 -> Shifted: 0001 0000 (0x10)
    CONSTANT CMD_ACC : STD_LOGIC_VECTOR(7 DOWNTO 0) := x"08";
    CONSTANT CMD_HK  : STD_LOGIC_VECTOR(7 DOWNTO 0) := x"10";

    -- 3. Error Flags (Header Bits 2:0)
    -- These masks are injected into the lower 3 bits of a command echo during failures.
    CONSTANT FLAG_ERR_CMD  : STD_LOGIC_VECTOR(7 DOWNTO 0) := x"04"; -- Bit 2: Invalid CMD
    CONSTANT FLAG_ERR_CRC  : STD_LOGIC_VECTOR(7 DOWNTO 0) := x"02"; -- Bit 1: CRC fail
    CONSTANT FLAG_ERR_ACC  : STD_LOGIC_VECTOR(7 DOWNTO 0) := x"01"; -- Bit 0: Accelerator Fault

    -- 4. Data Integrity (CRC)
    -- CRC-8-ATM Polynomial: x^8 + x^2 + x + 1
    CONSTANT CRC8_POLY : STD_LOGIC_VECTOR(8 DOWNTO 0) := "100000111";

    -- 5. Application Parameters
    CONSTANT HEADER_BITS    : INTEGER := 8;
    CONSTANT PAYLOAD_BITS   : INTEGER := 48;
    CONSTANT FCS_BITS       : INTEGER := 8;
    CONSTANT UART_DATA_BITS : INTEGER := 8;
    CONSTANT UART_STOP_BITS : INTEGER := 2;
    CONSTANT RX_TIMEOUT_MAX : INTEGER := 500_000;                   -- 5 ms timeout at 100 MHz
    
    -- 6. Dummy Accelerator Parameters
    CONSTANT CAESAR_SHIFT_VAL : UNSIGNED(7 DOWNTO 0) := to_unsigned(3, 8);

END PACKAGE space_mri_pkg;