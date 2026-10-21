----------------------------------------------------------------------------------
-- Module Name:     space_mri_top
-- Author:          Imran
-- Last Modified:   21 October 2026
--
-- Description: Top-level structural wrapper for the Space MRI system.
--              It integrates the UART receiver subsystem, the Host Interface 
--              parser, the dummy hardware accelerator, and the UART transmitter,
--              wiring all data buses and hardware handshaking signals together.
----------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE work.space_mri_pkg.ALL;

ENTITY space_mri_top IS
    PORT (
        clk             : IN STD_LOGIC;
        rst_n           : IN STD_LOGIC;

        -- Serial Communication
        uart_rx_bit     : IN STD_LOGIC;
        uart_tx_bit     : OUT STD_LOGIC;

        -- Status & Diagnostic Flags
        baud_locked_out : OUT STD_LOGIC;
        frame_err_out   : OUT STD_LOGIC;
        header_err_out  : OUT STD_LOGIC;
        crc_error_out   : OUT STD_LOGIC;
        crc_valid_out   : OUT STD_LOGIC;
        acc_done_out    : OUT STD_LOGIC
    );
END space_mri_top;

ARCHITECTURE structural OF space_mri_top IS

    -- Signals between UART RX and Host Interface
    SIGNAL rx_data_s       : STD_LOGIC_VECTOR(UART_DATA_BITS-1 DOWNTO 0);
    SIGNAL rx_data_valid_s : STD_LOGIC;
    SIGNAL frame_err_s     : STD_LOGIC;
    SIGNAL baud_locked_s   : STD_LOGIC;
    
    -- Signals between Host Interface and UART TX
    SIGNAL tx_data_s       : STD_LOGIC_VECTOR(UART_DATA_BITS-1 DOWNTO 0);
    SIGNAL tx_en_s         : STD_LOGIC;
    SIGNAL tx_ready_s      : STD_LOGIC;

    -- Signals between Host Interface and Accelerator
    SIGNAL acc_data_in_s   : STD_LOGIC_VECTOR(PAYLOAD_BITS-1 DOWNTO 0);
    SIGNAL acc_data_out_s  : STD_LOGIC_VECTOR(PAYLOAD_BITS-1 DOWNTO 0);
    SIGNAL acc_en_s        : STD_LOGIC;
    SIGNAL acc_done_s      : STD_LOGIC;

BEGIN

    -- Route internal status signals to top-level pins for monitoring
    baud_locked_out <= baud_locked_s;
    frame_err_out   <= frame_err_s;
    acc_done_out    <= acc_done_s;

    -- 1. UART Receiver Subsystem
    uart_rx_inst : ENTITY work.uart_rx_top
        GENERIC MAP (
            DATA_WIDTH  => UART_DATA_BITS
        )
        PORT MAP (
            clk         => clk,
            rst_n       => rst_n,
            uart_rx_bit => uart_rx_bit,
            data        => rx_data_s,
            data_valid  => rx_data_valid_s,
            frame_err   => frame_err_s,
            baud_locked => baud_locked_s
        );

    -- 2. Host Interface / Packet Parser
    host_interface_inst : ENTITY work.host_interface
        PORT MAP (
            clk         => clk,
            rst_n       => rst_n,
            
            -- RX routing
            rx_data     => rx_data_s,
            rx_valid    => rx_data_valid_s,
            
            -- TX routing
            tx_ready    => tx_ready_s,
            tx_data     => tx_data_s,
            tx_en       => tx_en_s,
            
            -- Accelerator routing
            acc_data    => acc_data_in_s,
            acc_result  => acc_data_out_s,
            acc_en      => acc_en_s,
            acc_done    => acc_done_s,
            
            -- Diagnostics
            header_err  => header_err_out,
            crc_error   => crc_error_out,
            crc_valid   => crc_valid_out
        );

    -- 3. Dummy Hardware Accelerator (Caesar Cipher)
    dummy_acc_inst : ENTITY work.dummy_accelerator
        PORT MAP (
            clk         => clk,
            rst_n       => rst_n,
            acc_en      => acc_en_s,
            data_in     => acc_data_in_s,
            data_out    => acc_data_out_s,
            acc_done    => acc_done_s
        );
        
    -- 4. UART Transmitter
    uart_tx_inst : ENTITY work.uart_tx
        GENERIC MAP (
            CLK_FREQ   => SYS_CLK_FREQ,
            BAUD_RATE  => BAUD_RATE,
            DATA_WIDTH => UART_DATA_BITS,
            STOP_BITS  => UART_STOP_BITS
        )
        PORT MAP (
            clk        => clk,
            rst_n      => rst_n,
            data       => tx_data_s,
            tx_en      => tx_en_s,
            tx_rdy     => tx_ready_s,
            tx_bit     => uart_tx_bit
        );

END structural;