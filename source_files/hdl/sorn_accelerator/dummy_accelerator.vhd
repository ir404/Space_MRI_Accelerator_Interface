----------------------------------------------------------------------------------
-- Module Name:     accelerator (Dummy Caesar Shift Implementation)
-- File name:       dummy_accelerator.vhd
-- Author:          Imran
-- Last Modified:   22 November 2026
--
-- Description:     Drop-in hardware accelerator stub matching the SORN top-level
--                  interface. Captures (target_x, target_y, target_z) on a rising
--                  edge of start, simulates a short compute latency, and outputs
--                  six unique Caesar-shifted joint values derived from the inputs.
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.fixed_pkg.all;

library work;
use work.AcceleratorPKG.all;
use work.space_mri_pkg.all;

entity accelerator is
	generic
	(
		LFSR_SIZE: integer range 1 to 30           := 12; -- Kept for top-level compatibility
		NUM_CORES: integer range 1 to integer'high := 1   -- Kept for top-level compatibility
	);
	port
	(
		clk  : in std_ulogic;
		reset: in std_ulogic; -- Active high

		target_x: in SornFixed_t;
		target_y: in SornFixed_t;
		target_z: in SornFixed_t;
		start   : in std_ulogic; -- Rising edge starts computation

		j0_in_rad: out SornFixed_t;
		j1_in_rad: out SornFixed_t;
		j2_in_rad: out SornFixed_t;
		j3_in_rad: out SornFixed_t;
		j4_in_rad: out SornFixed_t;
		j5_in_rad: out SornFixed_t;
		busy     : out std_ulogic;

		valid: out std_ulogic;        -- Pulses high for 1 cycle when finished
		err  : out AcceleratorError_t;

		time_in_compute: out integer
	);
end entity accelerator;

architecture rtl of accelerator is

	type state_t is (IDLE, COMPUTING);
	constant COMPUTE_CYCLES : integer := 16; -- Simulated processing latency

	signal state      : state_t            := IDLE;
	signal start_prev : std_ulogic         := '0';
	signal valid_r    : std_ulogic         := '0';
	signal error_r    : AcceleratorError_t := ERR_NONE;

	-- Latched fixed-point inputs and outputs
	signal x_buf, y_buf, z_buf : SornFixed_t := (others => '0');
	signal j0_r, j1_r, j2_r    : SornFixed_t := (others => '0');
	signal j3_r, j4_r, j5_r    : SornFixed_t := (others => '0');

	-- Cycle counters
	signal timer1            : integer := 0;
	signal time_in_compute_r : integer := 0;

begin

	-- Edge detector for start pulse
	start_edge: process(clk)
	begin
		if rising_edge(clk) then
			start_prev <= start;
		end if;
	end process;

	fsm: process(clk)
		variable x_u, y_u, z_u : unsigned(7 downto 0);
		variable s1, s2, s3    : unsigned(7 downto 0);
		variable s4, s5, s6    : unsigned(7 downto 0);
	begin
		if rising_edge(clk) then
			valid_r <= '0';

			if reset = '1' then
				state             <= IDLE;
				error_r           <= ERR_NONE;
				timer1            <= 0;
				time_in_compute_r <= 0;
				x_buf             <= (others => '0');
				y_buf             <= (others => '0');
				z_buf             <= (others => '0');
				j0_r              <= (others => '0');
				j1_r              <= (others => '0');
				j2_r              <= (others => '0');
				j3_r              <= (others => '0');
				j4_r              <= (others => '0');
				j5_r              <= (others => '0');

			else
				case state is
					when IDLE =>
						if start = '1' and start_prev = '0' then
							x_buf  <= target_x;
							y_buf  <= target_y;
							z_buf  <= target_z;
							timer1 <= 0;
							state  <= COMPUTING;
						end if;

					when COMPUTING =>
						if timer1 < COMPUTE_CYCLES - 1 then
							timer1 <= timer1 + 1;
						else
							-- Reinterpret 8-bit sfixed inputs as unsigned bytes for modulo-256 shifts
							x_u := unsigned(to_slv(x_buf));
							y_u := unsigned(to_slv(y_buf));
							z_u := unsigned(to_slv(z_buf));

							-- Distinct multiples of CAESAR_SHIFT_VAL (3, 6, 9, 12, 15, 18)
							s1 := CAESAR_SHIFT_VAL;
							s2 := resize(CAESAR_SHIFT_VAL * 2, 8);
							s3 := resize(CAESAR_SHIFT_VAL * 3, 8);
							s4 := resize(CAESAR_SHIFT_VAL * 4, 8);
							s5 := resize(CAESAR_SHIFT_VAL * 5, 8);
							s6 := resize(CAESAR_SHIFT_VAL * 6, 8);

							-- Generate 6 unique outputs tied to x, y, and z
							j0_r <= sfixed(std_logic_vector(x_u + s1));
							j1_r <= sfixed(std_logic_vector(y_u + s2));
							j2_r <= sfixed(std_logic_vector(z_u + s3));
							j3_r <= sfixed(std_logic_vector(x_u + y_u + s4));
							j4_r <= sfixed(std_logic_vector(y_u + z_u + s5));
							j5_r <= sfixed(std_logic_vector(x_u + y_u + z_u + s6));

							time_in_compute_r <= timer1 + 1;
							valid_r           <= '1';
							state             <= IDLE;
						end if;
				end case;
			end if;
		end if;
	end process;

	j0_in_rad <= j0_r;
	j1_in_rad <= j1_r;
	j2_in_rad <= j2_r;
	j3_in_rad <= j3_r;
	j4_in_rad <= j4_r;
	j5_in_rad <= j5_r;

	busy            <= '1' when state = COMPUTING else '0';
	valid           <= valid_r;
	err             <= error_r;
	time_in_compute <= time_in_compute_r;

end architecture rtl;