----------------------------------------------------------------------------------
-- Package Name:    space_mri_pkg
-- Author:          Imran
-- Last Modified:   21 September 2026

-- Description:  Global constants and types for the Space MRI Hardware Accelerator.
----------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

PACKAGE space_mri_pkg IS

    -- 1. System Constants
    CONSTANT SYS_CLK_FREQ : NATURAL := 100_000_000;                 -- 100 MHz Basys 3 Clock
    CONSTANT BAUD_RATE    : NATURAL := 115200;

    -- 2. Communication Protocol Codes
    CONSTANT CMD_ACC : STD_LOGIC_VECTOR(7 DOWNTO 0) := x"A5";
    CONSTANT CMD_HK  : STD_LOGIC_VECTOR(7 DOWNTO 0) := x"5A";

    -- 3. Data Integrity (CRC)
    -- CRC-8-ATM Polynomial: x^8 + x^2 + x + 1
    CONSTANT CRC8_POLY : STD_LOGIC_VECTOR(8 DOWNTO 0) := "100000111";

    -- 4. Application Parameters
    CONSTANT HEADER_BITS    : INTEGER := 8;
    CONSTANT PAYLOAD_BITS   : INTEGER := 48;
    CONSTANT FCS_BITS       : INTEGER := 8;
    CONSTANT UART_DATA_BITS : INTEGER := 8;
    CONSTANT UART_STOP_BITS : INTEGER := 2;
    
    -- 5. Dummy Accelerator Parameters
    CONSTANT CAESAR_SHIFT_VAL : UNSIGNED(7 DOWNTO 0) := to_unsigned(3, 8);

END PACKAGE space_mri_pkg;