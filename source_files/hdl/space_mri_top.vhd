----------------------------------------------------------------------------------
-- Module Name:     space_mri_top
-- Author:          Imran
-- Last Modified:   13 November 2026
--
-- Description: Top-level structural wrapper for the Space MRI system.
--              It integrates the UART receiver subsystem, the Host Interface 
--              parser, the SORN hardware accelerator, and the UART transmitter,
--              wiring all data buses and hardware handshaking signals together.
----------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE IEEE.FIXED_PKG.ALL;           -- Required for sfixed and to_slv/to_sfixed
USE work.space_mri_pkg.ALL;
USE work.AcceleratorPKG.ALL;      -- Required for SornFixed_t and AcceleratorError_t

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
    
    -- Dedicated SORN Accelerator Signals (Type Casting & Translation)
    SIGNAL acc_reset_s     : STD_LOGIC;
    SIGNAL acc_err_s       : STD_LOGIC;
    SIGNAL sorn_err_s      : AcceleratorError_t;
    
    SIGNAL target_x_s      : SornFixed_t;
    SIGNAL target_y_s      : SornFixed_t;
    SIGNAL target_z_s      : SornFixed_t;
    
    SIGNAL j0_s            : SornFixed_t;
    SIGNAL j1_s            : SornFixed_t;
    SIGNAL j2_s            : SornFixed_t;
    SIGNAL j3_s            : SornFixed_t;
    SIGNAL j4_s            : SornFixed_t;
    SIGNAL j5_s            : SornFixed_t;

    -- Dynamic Payload Slice Indices for Target Coordinates (MSB-first Big-Endian)
    CONSTANT COORD_WIDTH : NATURAL := SornFixed_t'length;

    CONSTANT X_MSB : NATURAL := PAYLOAD_BITS - 1;
    CONSTANT X_LSB : NATURAL := PAYLOAD_BITS - COORD_WIDTH;
    
    CONSTANT Y_MSB : NATURAL := X_LSB - 1;
    CONSTANT Y_LSB : NATURAL := Y_MSB - COORD_WIDTH + 1;
    
    CONSTANT Z_MSB : NATURAL := Y_LSB - 1;
    CONSTANT Z_LSB : NATURAL := Z_MSB - COORD_WIDTH + 1;

BEGIN

    -- Route internal status signals to top-level pins for monitoring
    baud_locked_out <= baud_locked_s;
    frame_err_out   <= frame_err_s;
    acc_done_out    <= acc_done_s;

    -- Hardware Translation Logic for SORN Integration
    acc_reset_s <= NOT rst_n; -- Translate Active-Low to Active-High for the accelerator
    
    -- Convert AcceleratorError_t enum to a single STD_LOGIC bit for the host interface
    acc_err_s <= '1' WHEN sorn_err_s /= ERR_NONE ELSE '0';

    -- Reinterpret STD_LOGIC_VECTOR slices directly as SornFixed_t (3 downto -4)
    target_x_s <= sfixed(acc_data_in_s(X_MSB DOWNTO X_LSB));
    target_y_s <= sfixed(acc_data_in_s(Y_MSB DOWNTO Y_LSB));
    target_z_s <= sfixed(acc_data_in_s(Z_MSB DOWNTO Z_LSB));

    -- Concatenate the 6 computed joint angles back into a single 48-bit STD_LOGIC_VECTOR payload
    acc_data_out_s <= to_slv(j0_s) & to_slv(j1_s) & to_slv(j2_s) & to_slv(j3_s) & to_slv(j4_s) & to_slv(j5_s);

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
            acc_err     => acc_err_s,
            
            -- Diagnostics
            header_err  => header_err_out,
            crc_error   => crc_error_out,
            crc_valid   => crc_valid_out
        );

    -- 3. SORN Hardware Accelerator
    sorn_acc_inst : ENTITY work.accelerator
        GENERIC MAP (
            LFSR_SIZE => 12,
            NUM_CORES => 1
        )
        PORT MAP (
            clk       => clk,
            reset     => acc_reset_s,
            
            -- Incoming Coordinates
            target_x  => target_x_s,
            target_y  => target_y_s,
            target_z  => target_z_s,
            start     => acc_en_s,
            
            -- Outgoing Joint Angles
            j0_in_rad => j0_s,
            j1_in_rad => j1_s,
            j2_in_rad => j2_s,
            j3_in_rad => j3_s,
            j4_in_rad => j4_s,
            j5_in_rad => j5_s,
            
            -- Handshaking and Status
            busy      => OPEN,          -- Busy flag not required by host_interface
            valid     => acc_done_s,
            err       => sorn_err_s
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
