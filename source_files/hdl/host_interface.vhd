---------------------------------------------------------------------------------------
-- Module Name:     host_interface
-- Author:          Imran
-- Last Modified:   21 October 2026
--
-- Description:     A Host Interface Controller and packet parser. It enforces a 
--                  strict 8-byte fixed-length frame for all commands. It receives 
--                  the full packet, verifies the CRC-8-ATM integrity, and then 
--                  decodes the header to manage hardware routing.
--
-- Byte Order:      Big-Endian (Most Significant Byte received and transmitted first)
--
-- Command Codes:
--      CMD_ACC :   0xA5 (8-byte packet: Header + 6 Payload + 1 CRC)
--      CMD_HK  :   0x5A (8-byte packet: Header + 6 Dummy + 1 CRC)
---------------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE work.space_mri_pkg.ALL;

ENTITY host_interface IS
    PORT (
        clk        : IN STD_LOGIC;
        rst_n      : IN STD_LOGIC;
        
        -- UART RX Interface
        rx_data    : IN STD_LOGIC_VECTOR(UART_DATA_BITS-1 DOWNTO 0);
        rx_valid   : IN STD_LOGIC;

        -- UART TX Interface
        tx_ready   : IN STD_LOGIC;
        tx_data    : OUT STD_LOGIC_VECTOR(UART_DATA_BITS-1 DOWNTO 0);
        tx_en      : OUT STD_LOGIC;
        
        -- Hardware Accelerator Interface
        acc_data   : OUT STD_LOGIC_VECTOR(PAYLOAD_BITS-1 DOWNTO 0);         -- payload data sent to acc
        acc_result : IN STD_LOGIC_VECTOR(PAYLOAD_BITS-1 DOWNTO 0);          -- calculated result from the acc
        acc_en     : OUT STD_LOGIC;
        acc_done   : IN STD_LOGIC;
        
        -- Diagnostic Outputs
        header_err : OUT STD_LOGIC;
        crc_error  : OUT STD_LOGIC;
        crc_valid  : OUT STD_LOGIC
    );
END host_interface;

ARCHITECTURE behavioural OF host_interface IS 

    CONSTANT TOTAL_BYTES : INTEGER := (HEADER_BITS + PAYLOAD_BITS + FCS_BITS) / 8;          -- in a packet

    -- State Sequence
    TYPE state_type IS (IDLE, GET_PACKET, VERIFY_CRC, PROCESS_HEADER, ACC, HOUSEKEEPING, TX_RESULT, WAIT_TX_BUSY);
    SIGNAL state_s : state_type := IDLE;

    -- Internal Registers
    SIGNAL header_reg       : STD_LOGIC_VECTOR(HEADER_BITS-1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL payload_reg      : STD_LOGIC_VECTOR(PAYLOAD_BITS-1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL lfs_reg          : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL acc_result_reg   : STD_LOGIC_VECTOR(PAYLOAD_BITS-1 DOWNTO 0) := (OTHERS => '0');
    
    -- Dual-purpose counter: counts 8 bytes during RX, then counts 64 bits for CRC
    SIGNAL counter_reg : INTEGER RANGE 0 TO HEADER_BITS + PAYLOAD_BITS + FCS_BITS := 0;
    
    -- 64-bit Shift Register for serialising the entire packet into the LFSR
    SIGNAL crc_shift_s : STD_LOGIC_VECTOR(HEADER_BITS + PAYLOAD_BITS + FCS_BITS - 1 DOWNTO 0) := (OTHERS => '0');
    
    -- Internal Signals for combinational CRC logic
    SIGNAL current_bit_s : STD_LOGIC;
    SIGNAL feedback_s    : STD_LOGIC;
    
    -- Output Register Signals
    SIGNAL acc_en_s      : STD_LOGIC := '0';
    SIGNAL header_err_s  : STD_LOGIC := '0';
    SIGNAL crc_error_s   : STD_LOGIC := '0';
    SIGNAL crc_valid_s   : STD_LOGIC := '0';
    SIGNAL tx_data_s     : STD_LOGIC_VECTOR(UART_DATA_BITS-1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL tx_en_s       : STD_LOGIC := '0';

BEGIN 

    -- Concurrent assignments for LFSR feedback logic (CRC-8-ATM: x^8 + x^2 + x + 1)
    current_bit_s <= crc_shift_s(crc_shift_s'high);
    feedback_s    <= lfs_reg(7) XOR current_bit_s;

    PROCESS (clk, rst_n)
    BEGIN
        IF rst_n = '0' THEN 
            state_s         <= IDLE;
            header_reg      <= (OTHERS => '0');
            payload_reg     <= (OTHERS => '0');
            counter_reg     <= 0;
            lfs_reg         <= (OTHERS => '0');
            crc_shift_s     <= (OTHERS => '0');
            acc_en_s        <= '0';
            header_err_s    <= '0';
            crc_error_s     <= '0';
            crc_valid_s     <= '0';
            acc_result_reg  <= (OTHERS => '0');
            tx_data_s       <= (OTHERS => '0');
            tx_en_s         <= '0';
            
        ELSIF rising_edge(clk) THEN 
            
            -- Default assignments guarantee mutually exclusive, 1-cycle pulses
            acc_en_s     <= '0';
            header_err_s <= '0';
            crc_error_s  <= '0';
            crc_valid_s  <= '0';
            tx_en_s      <= '0';

            CASE state_s IS 
                WHEN IDLE =>
                    IF rx_valid = '1' THEN
                        -- Byte 1: Capture the Header
                        header_reg  <= rx_data;
                        counter_reg <= 1; 
                        state_s     <= GET_PACKET;
                    END IF;

                WHEN GET_PACKET =>
                    IF rx_valid = '1' THEN
                        IF counter_reg < TOTAL_BYTES - 1 THEN
                            -- Bytes 2 to 7: Shift into the 48-bit Payload register
                            payload_reg <= payload_reg(PAYLOAD_BITS - 9 DOWNTO 0) & rx_data;
                            counter_reg <= counter_reg + 1;
                            
                        ELSIF counter_reg = TOTAL_BYTES - 1 THEN
                            -- Byte 8: Capture FCS, load shift register, and prepare for CRC
                            crc_shift_s <= header_reg & payload_reg & rx_data;
                            
                            counter_reg <=  HEADER_BITS + PAYLOAD_BITS + FCS_BITS;          -- total of 64 bits in packet
                            lfs_reg     <= (OTHERS => '0');
                            state_s     <= VERIFY_CRC;
                        END IF;
                    END IF;

                WHEN VERIFY_CRC =>
                    IF counter_reg > 0 THEN
                        -- Shift the 64-bit packet left by 1 bit
                        crc_shift_s <= crc_shift_s(crc_shift_s'high - 1 DOWNTO 0) & '0';
                        
                        -- Apply LFSR XOR taps for CRC-8-ATM: 100000111
                        lfs_reg(0)          <= feedback_s;
                        lfs_reg(1)          <= lfs_reg(0) XOR feedback_s;
                        lfs_reg(2)          <= lfs_reg(1) XOR feedback_s;
                        lfs_reg(7 DOWNTO 3) <= lfs_reg(6 DOWNTO 2);
                        
                        counter_reg <= counter_reg - 1;
                    ELSE
                        -- LFSR mathematically zeroes out if the frame is error-free
                        IF lfs_reg = x"00" THEN
                            crc_valid_s <= '1';
                            state_s     <= PROCESS_HEADER;
                        ELSE
                            crc_error_s <= '1';
                            state_s     <= IDLE;
                        END IF;
                    END IF;

                WHEN PROCESS_HEADER =>
                    IF header_reg = CMD_ACC THEN
                        state_s <= ACC;
                    ELSIF header_reg = CMD_HK THEN
                        state_s <= HOUSEKEEPING;
                    ELSE
                        -- unknown header received
                        header_err_s <= '1';
                        state_s      <= IDLE;
                    END IF;

                WHEN ACC =>
                    acc_en_s <= '1'; 
                    
                    IF acc_done = '1' THEN
                        acc_en_s        <= '0';
                        acc_result_reg  <= acc_result;
                        counter_reg     <= 0;               -- Reset counter to bit 0 for the TX loop
                        state_s         <= TX_RESULT;
                    END IF;

                WHEN HOUSEKEEPING =>
                    -- TODO: Trigger housekeeping logic here
                    state_s <= IDLE;
                    
                WHEN TX_RESULT =>
                    IF tx_ready = '1' THEN
                        -- Extract the MSB dynamically
                        tx_data_s <= acc_result_reg(acc_result_reg'high DOWNTO acc_result_reg'high - 7);
                        tx_en_s   <= '1';
                        
                        -- Shift remaining bytes left to queue up the next transmission
                        acc_result_reg <= acc_result_reg(acc_result_reg'high - 8 DOWNTO 0) & x"00";
                        state_s        <= WAIT_TX_BUSY;
                    END IF;

                WHEN WAIT_TX_BUSY =>
                    -- Wait for uart_tx module to register the enable pulse and drop its ready flag
                    IF tx_ready = '0' THEN
                        IF counter_reg = (PAYLOAD_BITS / 8) - 1 THEN
                            state_s <= IDLE;          -- All bytes sent
                        ELSE
                            counter_reg <= counter_reg + 1;
                            state_s     <= TX_RESULT; -- Send next byte
                        END IF;
                    END IF;

            END CASE;
        END IF;
    END PROCESS;

    -- Output assignments
    acc_data   <= payload_reg;
    acc_en     <= acc_en_s;
    header_err <= header_err_s;
    crc_error  <= crc_error_s;
    crc_valid  <= crc_valid_s;
    tx_data    <= tx_data_s;
    tx_en      <= tx_en_s;

END behavioural;
