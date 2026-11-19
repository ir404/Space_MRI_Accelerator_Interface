library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.fixed_pkg.all;

library work;
use work.AcceleratorPKG.all;
use work.Sorn.all;
use work.SornManipulatorLimits.all;
use work.global_pkg.all;

entity accelerator is
	generic
	(
		LFSR_SIZE: integer range 1 to 30           := 12; -- Forwarded to ik_evaluator and ik_core
		NUM_CORES: integer range 1 to integer'high := 1   -- Only NUM_CORES = 1 is validated
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

		valid: out std_ulogic;        -- High for two clock cycles when the computation is finished (as in the reference design)
		err  : out AcceleratorError_t; -- Indicates an error

		time_in_compute: out integer -- Clock cycles spent in the COMPUTING state
	);
end entity accelerator;

architecture rtl of accelerator is

	type state_t is (IDLE, COMPUTING);

	signal state     : state_t            := IDLE;
	signal start_prev: std_ulogic         := '0';
	signal valid_r   : std_ulogic         := '0';
	signal error_r   : AcceleratorError_t := ERR_NONE;

	-- For IK-Evaluator
	signal cur_sine, cur_cosine: SornArr_t(5 downto 0);
	signal fk_x, fk_y, fk_z                   : Sorn_t;
	signal ik_done                            : std_ulogic;

	-- Error calculation
	signal best_squared_error: Sorn_t := FULL_SORN;
	signal cur_squared_error : Sorn_t;
	signal output_valid      : std_ulogic;

	-- Signals for Joint Angles --------------------------------------
	signal fxp_arr: FxpArr_t(5 downto 0) := (others => (others => '0'));
	-----------------------------------------------------------------

	-- Signals for Target --------------------------------------------
	signal target_buffer: SornArr_t(2 downto 0) := (others => EMPTY_SORN);
	-----------------------------------------------------------------

	-- Performance Measurements
	signal timer1            : integer := 0;
	signal time_in_compute_r : integer := 0;
	-----------------------------------------------------------------

begin
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
				state   <= IDLE;
				error_r <= ERR_NONE;

				timer1            <= 0;
				time_in_compute_r <= 0;

				target_buffer <= (others => EMPTY_SORN);
				fxp_arr       <= (others => (others => '0'));

				best_squared_error <= FULL_SORN;

			else
				timer1 <= timer1 + 1;

				if busy = '1' and output_valid = '1' then
					if (cur_squared_error.bits < best_squared_error.bits and
					((fk_x.bits and target_buffer(X).bits) /= (SornVector_t'range => '0') and
					 (fk_y.bits and target_buffer(Y).bits) /= (SornVector_t'range => '0') and
					 (fk_z.bits and target_buffer(Z).bits) /= (SornVector_t'range => '0'))) then

						for i in O1 to O6 loop
							fxp_arr(i) <= sincos_to_angle(cur_sine(i).bits, cur_cosine(i).bits);
						end loop;

						-- Save best results
						best_squared_error <= cur_squared_error;
					end if;
				end if;

				-- Were done if the inverse kinematics cores are done
				if ik_done = '1' then
					if busy = '1' then
						time_in_compute_r <= timer1;
					end if;

					state   <= IDLE;
					valid_r <= '1';
				end if;

				if start = '1' and start_prev = '0' and state = IDLE then
					state             <= COMPUTING;
					timer1            <= 0;
					time_in_compute_r <= 0;
					target_buffer <= (work.SornFixed.to_sorn(target_x), work.SornFixed.to_sorn(target_y), work.SornFixed.to_sorn(target_z));

					best_squared_error <= FULL_SORN;
				end if;
			end if;
		end if;
	end process;

	ik_evaluator_inst: entity work.ik_evaluator
	generic map
	(
		NUM_IK_CORES => NUM_CORES,
		LFSR_SIZE    => LFSR_SIZE
	)
	port map
	(
		clk            => clk,
		rst            => reset or not busy,
		enable         => busy,
		output_valid   => output_valid,
		done           => ik_done,
		target         => target_buffer,
		best_deviation => cur_squared_error,
		best_ls        => cur_sine,
		best_lc        => cur_cosine,

		fk_x    => fk_x,
		fk_y    => fk_y,
		fk_z    => fk_z
	);

	j0_in_rad <= fxp_arr(0);
	j1_in_rad <= fxp_arr(1);
	j2_in_rad <= fxp_arr(2);
	j3_in_rad <= fxp_arr(3);
	j4_in_rad <= fxp_arr(4);
	j5_in_rad <= fxp_arr(5);

	busy  <= '1' when state = COMPUTING else '0';
	valid <= valid_r;
	err   <= error_r;

	time_in_compute <= time_in_compute_r;

end architecture;
