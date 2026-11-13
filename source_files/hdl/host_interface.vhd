---------------------------------------------------------------------------------------
-- Module Name:     host_interface
-- Author:          Imran
-- Last Modified:   13 November 2026
--
-- Description:     A Host Interface Controller and packet parser. It enforces a 
--                  strict 8-byte fixed-length frame for all commands. It receives 
--                  the full packet, verifies the CRC-8-ATM integrity, and then 
--                  decodes the structured header (5-bit opcode, 3-bit error flag).
--                  It calculates and appends a new CRC-8-ATM to the outgoing response.
--                  Includes an RX Watchdog to recover from mid-packet link failures.
--
-- Byte Order:      Big-Endian (Most Significant Byte received and transmitted first)
--
-- Command Codes (Shifted to upper 5 bits):
--      CMD_ACC :   0x08 (8-byte packet: Header + 6 Payload + 1 CRC)
--      CMD_HK  :   0x10 (8-byte packet: Header + 6 Dummy + 1 CRC)
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
        acc_data   : OUT STD_LOGIC_VECTOR(PAYLOAD_BITS-1 DOWNTO 0);        -- payload data sent to acc
        acc_result : IN STD_LOGIC_VECTOR(PAYLOAD_BITS-1 DOWNTO 0);         -- calculated result from the acc
        acc_en     : OUT STD_LOGIC;
        acc_done   : IN STD_LOGIC;
        acc_err    : IN STD_LOGIC;                                         -- HIGH if accelerator internal fault occurs
        
        -- Diagnostic Outputs
        header_err : OUT STD_LOGIC;
        crc_error  : OUT STD_LOGIC;
        crc_valid  : OUT STD_LOGIC
    );
END host_interface;

ARCHITECTURE behavioural OF host_interface IS 

    CONSTANT TOTAL_BYTES : INTEGER := (HEADER_BITS + PAYLOAD_BITS + FCS_BITS) / 8;          -- in a packet
    CONSTANT ZERO_PAYLOAD : STD_LOGIC_VECTOR(PAYLOAD_BITS-1 DOWNTO 0) := (OTHERS => '0');

    -- Component Declaration for the new standalone CRC core
    COMPONENT crc8_atm_core
        PORT (
            clk      : IN STD_LOGIC;
            rst_n    : IN STD_LOGIC;
            crc_rst  : IN STD_LOGIC;
            en       : IN STD_LOGIC;
            inp_bit  : IN STD_LOGIC;
            crc_out  : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
        );
    END COMPONENT;

    -- State Sequence
    TYPE state_type IS (IDLE, GET_PACKET, VERIFY_CRC, PROCESS_HEADER, ACC, HOUSEKEEPING, TX_ERROR, CALC_TX_CRC, TX_RESULT, WAIT_TX_BUSY);
    SIGNAL state_s : state_type := IDLE;

    -- Internal Registers
    SIGNAL header_reg       : STD_LOGIC_VECTOR(HEADER_BITS-1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL payload_reg      : STD_LOGIC_VECTOR(PAYLOAD_BITS-1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL acc_result_reg   : STD_LOGIC_VECTOR(PAYLOAD_BITS-1 DOWNTO 0) := (OTHERS => '0');
    
    -- Dual-purpose counter: counts 8 bytes during RX, then counts 64/56 bits for CRC and TX
    SIGNAL counter_reg : INTEGER RANGE 0 TO HEADER_BITS + PAYLOAD_BITS + FCS_BITS := 0;
    
    -- RX Watchdog Timer: Protects against FSM hangs during incomplete frame reception
    SIGNAL rx_timer_reg : INTEGER RANGE 0 TO RX_TIMEOUT_MAX := 0;
    
    -- 64-bit Shift Register for serialising the entire packet into the LFSR and out to TX
    SIGNAL crc_shift_reg : STD_LOGIC_VECTOR(HEADER_BITS + PAYLOAD_BITS + FCS_BITS - 1 DOWNTO 0) := (OTHERS => '0');
    
    -- CRC Core Control Signals
    SIGNAL crc_en_s      : STD_LOGIC;
    SIGNAL crc_rst_s     : STD_LOGIC;
    SIGNAL crc_inp_bit_s : STD_LOGIC;
    SIGNAL crc_result_s  : STD_LOGIC_VECTOR(7 DOWNTO 0);
    
    -- Output Register Signals
    SIGNAL acc_en_s      : STD_LOGIC := '0';
    SIGNAL header_err_s  : STD_LOGIC := '0';
    SIGNAL crc_error_s   : STD_LOGIC := '0';
    SIGNAL crc_valid_s   : STD_LOGIC := '0';
    SIGNAL tx_data_s     : STD_LOGIC_VECTOR(UART_DATA_BITS-1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL tx_en_s       : STD_LOGIC := '0';

BEGIN 

    -- Instantiate the CRC core
    crc_inst : crc8_atm_core
    PORT MAP (
        clk      => clk,
        rst_n    => rst_n,
        crc_rst  => crc_rst_s,
        en       => crc_en_s,
        inp_bit  => crc_inp_bit_s,
        crc_out  => crc_result_s
    );

    -- Combinatorial logic routing the FSM timing strictly to the CRC core
    crc_inp_bit_s <= crc_shift_reg(crc_shift_reg'high);
    crc_en_s  <= '1' 
                 WHEN ((state_s = VERIFY_CRC OR state_s = CALC_TX_CRC) AND counter_reg > 0) 
                 ELSE '0';
    crc_rst_s <= '1' 
                 WHEN (state_s = GET_PACKET AND rx_valid = '1' AND counter_reg = TOTAL_BYTES - 1) 
                     OR (state_s = ACC AND acc_done = '1') 
                     OR (state_s = TX_ERROR)
                 ELSE '0';


    PROCESS (clk, rst_n)
    BEGIN
        IF rst_n = '0' THEN 
            state_s         <= IDLE;
            header_reg      <= (OTHERS => '0');
            payload_reg     <= (OTHERS => '0');
            counter_reg     <= 0;
            rx_timer_reg    <= 0;
            crc_shift_reg   <= (OTHERS => '0');
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
                    rx_timer_reg <= 0;          -- Keep watchdog asleep
                    
                    IF rx_valid = '1' THEN
                        -- Byte 1: Capture the Header
                        header_reg  <= rx_data;
                        counter_reg <= 1; 
                        state_s     <= GET_PACKET;
                    END IF;

                WHEN GET_PACKET =>
                    IF rx_valid = '1' THEN
                        rx_timer_reg <= 0;      -- Feed the watchdog (byte arrived in time)
                        
                        IF counter_reg < TOTAL_BYTES - 1 THEN
                            -- Bytes 2 to 7: Shift into the 48-bit Payload register
                            payload_reg <= payload_reg(PAYLOAD_BITS - 9 DOWNTO 0) & rx_data;
                            counter_reg <= counter_reg + 1;
                            
                        ELSIF counter_reg = TOTAL_BYTES - 1 THEN
                            -- Byte 8: Capture FCS, load shift register, and prepare for CRC
                            -- crc_rst_s goes HIGH combinationally here to clear the core
                            crc_shift_reg <= header_reg & payload_reg & rx_data;
                            counter_reg   <= HEADER_BITS + PAYLOAD_BITS + FCS_BITS; -- 64 bits total
                            state_s       <= VERIFY_CRC;
                        END IF;
                        
                    ELSE
                        IF rx_timer_reg = RX_TIMEOUT_MAX THEN
                            -- WATCHDOG TRIPPED: The host stopped sending mid-packet
                            counter_reg  <= 0;
                            rx_timer_reg <= 0;
                            state_s      <= IDLE;   -- Flush everything and abort
                        ELSE
                            -- No byte received this clk cycle, increment the watchdog timer
                            rx_timer_reg <= rx_timer_reg + 1;
                        END IF;
                    END IF;

                WHEN VERIFY_CRC =>
                    IF counter_reg > 0 THEN
                        -- Shift the 64-bit packet left by 1 bit to feed into the external LFSR
                        crc_shift_reg <= crc_shift_reg(crc_shift_reg'high - 1 DOWNTO 0) & '0';
                        counter_reg   <= counter_reg - 1;
                    ELSE
                        -- LFSR mathematically zeroes out if the frame is error-free
                        IF crc_result_s = x"00" THEN
                            crc_valid_s <= '1';
                            state_s     <= PROCESS_HEADER;
                        ELSE
                            crc_error_s <= '1';
                            -- Inject CRC error flag into the received header and send it back
                            header_reg  <= header_reg OR FLAG_ERR_CRC;
                            state_s     <= TX_ERROR;
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
                        -- Keep the unknown opcode but inject the invalid command flag and send it back
                        header_reg   <= header_reg OR FLAG_ERR_CMD;
                        state_s      <= TX_ERROR;
                    END IF;

                WHEN ACC =>
                    acc_en_s <= '1'; 
                    
                    IF acc_done = '1' THEN
                        acc_en_s <= '0';
                        
                        IF acc_err = '1' THEN
                            -- Accelerator flagged an internal fault
                            header_reg <= header_reg OR FLAG_ERR_ACC;
                            state_s    <= TX_ERROR;
                        ELSE
                            acc_result_reg  <= acc_result;
                            -- Load 56 bits (Header + Result) into the top of the shift register
                            -- crc_rst_s goes HIGH combinationally here to clear the core
                            crc_shift_reg   <= header_reg & acc_result & x"00";
                            counter_reg     <= HEADER_BITS + PAYLOAD_BITS; -- 56 bits to evaluate
                            state_s         <= CALC_TX_CRC;
                        END IF;
                    END IF;

                WHEN HOUSEKEEPING =>
                    -- TODO: Trigger housekeeping logic here
                    state_s <= IDLE;
                    
                WHEN TX_ERROR =>
                    -- Zero out the payload since the command failed, load the error header
                    acc_result_reg  <= ZERO_PAYLOAD;
                    -- Load the 56 bits (Error Header + 48-bit Zero Payload) into the shift register
                    crc_shift_reg   <= header_reg & ZERO_PAYLOAD & x"00";
                    counter_reg     <= HEADER_BITS + PAYLOAD_BITS; 
                    state_s         <= CALC_TX_CRC;
                    
                WHEN CALC_TX_CRC =>
                    IF counter_reg > 0 THEN
                        -- Shift the packet left by 1 bit to feed into the external LFSR
                        crc_shift_reg <= crc_shift_reg(crc_shift_reg'high - 1 DOWNTO 0) & '0';
                        counter_reg   <= counter_reg - 1;
                    ELSE
                        -- Reconstruct the full 64-bit frame: Header + Result + New FCS
                        crc_shift_reg <= header_reg & acc_result_reg & crc_result_s;
                        counter_reg   <= 0;
                        state_s       <= TX_RESULT;
                    END IF;

                WHEN TX_RESULT =>
                    IF tx_ready = '1' THEN
                        -- Extract the MSB dynamically from the 64-bit shift register
                        tx_data_s <= crc_shift_reg(crc_shift_reg'high DOWNTO crc_shift_reg'high - 7);
                        tx_en_s   <= '1';
                        
                        -- Shift remaining bytes left to queue up the next transmission
                        crc_shift_reg <= crc_shift_reg(crc_shift_reg'high - 8 DOWNTO 0) & x"00";
                        state_s       <= WAIT_TX_BUSY;
                    END IF;

                WHEN WAIT_TX_BUSY =>
                    -- Wait for uart_tx module to register the enable pulse and drop its ready flag
                    IF tx_ready = '0' THEN
                        IF counter_reg = TOTAL_BYTES - 1 THEN
                            state_s <= IDLE;          -- All 8 bytes sent
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