LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY tb_space_mri_top IS
END tb_space_mri_top;

ARCHITECTURE behavioural OF tb_space_mri_top IS
    CONSTANT CLK_PERIOD  : TIME := 10 ns;      -- 100 MHz board input clock to clk_wiz_0
    CONSTANT BAUD_PERIOD : TIME := 8681 ns;    -- 115,200 baud (8N2)

    SIGNAL clk_s             : STD_LOGIC := '0';
    SIGNAL rst_n_s           : STD_LOGIC := '0';
    SIGNAL uart_rx_bit_s     : STD_LOGIC := '1';
    SIGNAL uart_tx_bit_s     : STD_LOGIC;
    SIGNAL baud_locked_out_s : STD_LOGIC;
    SIGNAL frame_err_out_s   : STD_LOGIC;
    SIGNAL header_err_out_s  : STD_LOGIC;
    SIGNAL crc_error_out_s   : STD_LOGIC;
    SIGNAL crc_valid_out_s   : STD_LOGIC;
    SIGNAL acc_done_out_s    : STD_LOGIC;
BEGIN
    dut : ENTITY work.space_mri_top
        PORT MAP (
            clk             => clk_s,
            rst_n           => rst_n_s,
            uart_rx_bit     => uart_rx_bit_s,
            uart_tx_bit     => uart_tx_bit_s,
            baud_locked_out => baud_locked_out_s,
            frame_err_out   => frame_err_out_s,
            header_err_out  => header_err_out_s,
            crc_error_out   => crc_error_out_s,
            crc_valid_out   => crc_valid_out_s,
            acc_done_out    => acc_done_out_s
        );

    clk_s <= NOT clk_s AFTER CLK_PERIOD / 2;

    -- Stimulus: send sync byte followed by (X=0.3125, Y=0.3125, Z=0.375)
    stim : PROCESS
        PROCEDURE send_byte(CONSTANT b : IN STD_LOGIC_VECTOR(7 DOWNTO 0)) IS
        BEGIN
            uart_rx_bit_s <= '0';              -- Start bit
            WAIT FOR BAUD_PERIOD;
            FOR i IN 0 TO 7 LOOP
                uart_rx_bit_s <= b(i);
                WAIT FOR BAUD_PERIOD;
            END LOOP;
            uart_rx_bit_s <= '1';              -- 2 stop bits (8N2)
            WAIT FOR 2 * BAUD_PERIOD;
        END PROCEDURE;
    BEGIN
        rst_n_s <= '0';
        WAIT FOR 100 ns;
        rst_n_s <= '1';
        WAIT FOR 5 us;                         -- Allow clk_wiz_0 MMCM to lock

        send_byte(x"55");                      -- For auto-baud sync
        WAIT FOR 20 us;

		-- Transmit test SORN coordinates with the correct CRC
        -- Send 0x08050506000000FE (X=0.3125, Y=0.3125, Z=0.375, CRC=0xFE)
        send_byte(x"08");
        send_byte(x"05");
        send_byte(x"05");
        send_byte(x"06");
        send_byte(x"00");
        send_byte(x"00");
        send_byte(x"00");
        send_byte(x"FE");

        WAIT FOR 2 ms;
        REPORT "Simulation finished";
        WAIT;
    END PROCESS;

    -- Monitor: decode and print the 8-byte response frame from uart_tx_bit_s
    rx_monitor : PROCESS
        VARIABLE rx_byte : STD_LOGIC_VECTOR(7 DOWNTO 0);
    BEGIN
        FOR byte_idx IN 0 TO 7 LOOP
            WAIT UNTIL falling_edge(uart_tx_bit_s);
            WAIT FOR BAUD_PERIOD / 2;          -- Sample at mid-bit
            FOR bit_idx IN 0 TO 7 LOOP
                WAIT FOR BAUD_PERIOD;
                rx_byte(bit_idx) := uart_tx_bit_s;
            END LOOP;
            REPORT "RX Byte " & INTEGER'image(byte_idx) &
                   " = 0x" & to_hstring(rx_byte);
            WAIT FOR BAUD_PERIOD;
        END LOOP;
        WAIT;
    END PROCESS;
END behavioural;