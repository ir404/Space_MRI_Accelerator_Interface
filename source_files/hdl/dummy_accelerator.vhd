----------------------------------------------------------------------------------
-- Module Name:     dummy_accelerator
-- Author:          Imran
-- Last Modified:   21 September 2026
--
-- Description: A dummy hardware accelerator for testing the Host Interface. 
--              It applies a basic Caesar cipher (+3 shift) to each of the 6 
--              bytes in the 48-bit payload. It implements a full handshaking 
--              protocol (en/done) to communicate with the host controller.
--
-- Ports:
--   clk      : System clock input.
--   rst_n    : Asynchronous active-low reset.
--   acc_en   : Enable flag; HIGH to trigger the cipher processing.
--   data_in  : 48-bit raw payload from the Host Interface.
--   data_out : 48-bit encoded payload.
--   acc_done : Done flag; held HIGH until the host de-asserts acc_en.
----------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE work.space_mri_pkg.ALL;

ENTITY dummy_accelerator IS
    PORT (
        clk      : IN STD_LOGIC;
        rst_n    : IN STD_LOGIC;
        acc_en   : IN STD_LOGIC;
        data_in  : IN STD_LOGIC_VECTOR(PAYLOAD_BITS-1 DOWNTO 0);
        data_out : OUT STD_LOGIC_VECTOR(PAYLOAD_BITS-1 DOWNTO 0);
        acc_done : OUT STD_LOGIC
    );
END dummy_accelerator;

ARCHITECTURE behavioural OF dummy_accelerator IS 

    TYPE state_type IS (IDLE, ENCODE, DONE);
    SIGNAL state_s : state_type := IDLE;

BEGIN 

    PROCESS (clk, rst_n)
        VARIABLE temp_byte : UNSIGNED(7 DOWNTO 0);
    BEGIN
        IF rst_n = '0' THEN 
            state_s  <= IDLE;
            data_out <= (OTHERS => '0');
            acc_done <= '0';
            
        ELSIF rising_edge(clk) THEN 
            CASE state_s IS 
                WHEN IDLE =>
                    acc_done <= '0';
                    -- Wait for the Host Interface to wake up the module
                    IF acc_en = '1' THEN
                        state_s <= ENCODE;
                    END IF;

                WHEN ENCODE =>
                    -- Loop through the payload, dynamically calculating the number of bytes
                    FOR i IN 0 TO (PAYLOAD_BITS / 8) - 1 LOOP
                        temp_byte := unsigned(data_in((i*8)+7 DOWNTO i*8)) + CAESAR_SHIFT_VAL;
                        data_out((i*8)+7 DOWNTO i*8) <= std_logic_vector(temp_byte);
                    END LOOP;
                    
                    state_s <= DONE;

                WHEN DONE =>
                    acc_done <= '1';
                    
                    -- Handshake: Wait for the Host Interface to acknowledge and drop acc_en
                    IF acc_en = '0' THEN
                        state_s <= IDLE;
                    END IF;
                    
            END CASE;
        END IF;
    END PROCESS;

END behavioural;
