library ieee;
use ieee.std_logic_1164.all;
use ieee.fixed_pkg.all;

use work.AcceleratorPKG.all;

entity accelerator is
	generic
	(
		LFSR_SIZE: integer range 1 to 30           := 12;
		NUM_CORES: integer range 1 to integer'high := 1
	);
	port
	(
		clk  : in std_ulogic;
		reset: in std_ulogic; -- Active high

		target_x: in SornFixed_t; -- Target x in (meters?)
		target_y: in SornFixed_t; -- Target y in (meters?)
		target_z: in SornFixed_t; -- Target z in (meters?)
		start   : in std_ulogic;  -- Rising edge starts the Accelerator

		j0_in_rad: out SornFixed_t; -- Joint0 in radians
		j1_in_rad: out SornFixed_t; -- Joint1 in radians
		j2_in_rad: out SornFixed_t; -- Joint2 in radians
		j3_in_rad: out SornFixed_t; -- Joint3 in radians
		j4_in_rad: out SornFixed_t; -- Joint4 in radians
		j5_in_rad: out SornFixed_t; -- Joint5 in radians
		busy     : out std_ulogic;  -- '1' if currently busy else '0'

		valid: out std_ulogic;        -- High for exactly one clock cycle when the computation is finished
		err : out AcceleratorError_t -- Indicates an error

	);
end entity accelerator;

architecture rtl of accelerator is

	type state_t is
	(
		IDLE,
		COMPUTING
	);

	signal state     : state_t            := IDLE;
	signal start_prev: std_ulogic         := '0';
	signal valid_r    : std_ulogic         := '0';
	signal error_r   : AcceleratorError_t := ERR_NONE;

	-- Random values, they never change
	constant J0_MOCK: SornFixed_t := to_sfixed(1.375, SornFixed_t'left, SornFixed_t'right);
	constant J1_MOCK: SornFixed_t := to_sfixed(-2.0625, SornFixed_t'left, SornFixed_t'right);
	constant J2_MOCK: SornFixed_t := to_sfixed(0.8125, SornFixed_t'left, SornFixed_t'right);
	constant J3_MOCK: SornFixed_t := to_sfixed(-3.25, SornFixed_t'left, SornFixed_t'right);
	constant J4_MOCK: SornFixed_t := to_sfixed(2.5, SornFixed_t'left, SornFixed_t'right);
	constant J5_MOCK: SornFixed_t := to_sfixed(-0.4375, SornFixed_t'left, SornFixed_t'right);

	constant COMPUTE_CYCLES: integer := 2 ** LFSR_SIZE / NUM_CORES;

	signal cycle_cnt: integer range 0 to COMPUTE_CYCLES := 0;
begin
	-- rising edge triggers start
	start_edge: process(clk)
	begin
		if rising_edge(clk) then
			start_prev <= start;
		end if;
	end process;

	fsm: process(clk)
	begin
		if rising_edge(clk) then
			valid_r <= '0';

			if reset = '1' then
				state     <= IDLE;
				error_r   <= ERR_NONE;
				cycle_cnt <= 0;
			else
				case state is

					when IDLE =>
						if start = '1' and start_prev = '0' then
							state     <= COMPUTING;
							cycle_cnt <= 0;
							error_r   <= ERR_NONE;
						end if;

					when COMPUTING =>
						-- wait 2**LFSR_SIZE / NUM_CORES cycles
						if cycle_cnt = COMPUTE_CYCLES - 1 then
							state  <= IDLE;
							valid_r <= '1';
						else
							cycle_cnt <= cycle_cnt + 1;
						end if;

				end case;
			end if;
		end if;
	end process;

	busy <= '1' when state = COMPUTING else '0';
	valid <= valid_r;
	err  <= error_r;

	j0_in_rad <= J0_MOCK;
	j1_in_rad <= J1_MOCK;
	j2_in_rad <= J2_MOCK;
	j3_in_rad <= J3_MOCK;
	j4_in_rad <= J4_MOCK;
	j5_in_rad <= J5_MOCK;

end architecture;
