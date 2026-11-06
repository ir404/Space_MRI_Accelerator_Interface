----------------------------------------------------------------------------------
-- Module Name:    crc8_atm_core
-- Author:          Imran
-- Last Modified:   6 November 2026
--
-- Description:    A standalone Direct Computation (Galois) LFSR for CRC-8-ATM.
--                 Polynomial: x^8 + x^2 + x + 1 (0x07)
--                 Calculates the remainder on-the-fly without zero-padding.
----------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

ENTITY crc8_atm_core IS
    PORT (
        clk      : IN STD_LOGIC;
        rst_n    : IN STD_LOGIC;                     -- Asynchronous system reset
        crc_rst  : IN STD_LOGIC;                     -- Synchronous clear for new calculation
        en       : IN STD_LOGIC;                     -- Enable processing of incoming bit
        inp_bit  : IN STD_LOGIC;                     -- Serial data input
        crc_out  : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)  -- Current CRC remainder
    );
END crc8_atm_core;

ARCHITECTURE behavioural OF crc8_atm_core IS
    SIGNAL lfs_reg    : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL feedback_s : STD_LOGIC;
BEGIN

    -- The 'Combined_In' quotient bit (F = Q7 XOR input)
    feedback_s <= lfs_reg(7) XOR inp_bit;

    PROCESS (clk, rst_n)
    BEGIN
        IF rst_n = '0' THEN
            lfs_reg <= (OTHERS => '0');
            
        ELSIF rising_edge(clk) THEN
            -- Synchronous reset - clear the registers before a new frame
            IF crc_rst = '1' THEN
                lfs_reg <= (OTHERS => '0');
                
            ELSIF en = '1' THEN
                -- LFSR Next State Logic mapping directly to the circuit taps
                lfs_reg(0)          <= feedback_s;
                lfs_reg(1)          <= lfs_reg(0) XOR feedback_s;
                lfs_reg(2)          <= lfs_reg(1) XOR feedback_s;
                -- standard left shifts for the remaining registers
                lfs_reg(7 DOWNTO 3) <= lfs_reg(6 DOWNTO 2);
            END IF;
        END IF;
    END PROCESS;

    -- Continuous assignment of the current remainder
    crc_out <= lfs_reg;

END behavioural;