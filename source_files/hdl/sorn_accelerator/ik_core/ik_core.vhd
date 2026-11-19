library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.numeric_std.all;

library work;
use work.SornUtil.all;
use work.Sorn.all;
use work.SornOperators.all;
use work.SornManipulatorLimits.all;
use work.global_pkg.all;

entity ik_core is
generic
(
	/* These 2 are just used to calculate a good seed for the lfsr */
	CORE_NUM: integer;
	NUM_CORES: integer;
	LFSR_SIZE: integer
);
port 
(
	clk: in std_ulogic;
	rst: in std_ulogic;

	/* Control */
	enable: in std_ulogic;
	output_valid: out std_ulogic;
	done: 	out std_ulogic; 				-- LFSR has been exhausted

	/* Data */
	target: in SornArr_t(2 downto 0); 		-- Target X, Y, Z

	deviation: out Sorn_t;					-- Resulting Deviation using the ls and lc values
	ls: 	out SornArr_t(5 downto 0); 	    -- Last Sine   Values which produced the current result
	lc: 	out SornArr_t(5 downto 0);	 	-- Last Cosine Values which produced the current result

	/* Debug */
	error_x: out Sorn_t;
	error_y: out Sorn_t;
	error_z: out Sorn_t;

	fk_x: out Sorn_t;
	fk_y: out Sorn_t;
	fk_z: out Sorn_t
);
end entity ik_core;

architecture rtl of ik_core is
	type int_arr is array (integer range <>) of integer;
	
	/* Range of Arm */

	-- Signals for LFSR ---------------------------------------------
	constant LFSR_MAX_NUM: 	int_arr(0 to 5) := (VALID_PAIR_O1'length, VALID_PAIR_O2'length, VALID_PAIR_O3'length,
	VALID_PAIR_O4'length, VALID_PAIR_O5'length, VALID_PAIR_O6'length);

	constant LFSR_WIDTH: 	integer := LFSR_SIZE;
	constant LFSR_INT_SIZE: integer := (2**LFSR_WIDTH)-1;
	
	type lfsr_result is array(0 to 5) of integer range 0 to LFSR_INT_SIZE;
	signal rand_arr: lfsr_result;


	signal repeats: std_ulogic_vector(rand_arr'length-1 downto 0);
	constant all_ones: std_ulogic_vector(rand_arr'length-1 downto 0) := (others => '1');
	-----------------------------------------------------------------

	constant num_predefined: integer := LFSR_SIZE;
	signal at_num_predefined: integer;

	-- Signals for Sorn core ----------------------------------------
	signal sin: SornArr_t(5 downto 0);
	signal cos: SornArr_t(5 downto 0);
	-----------------------------------------------------------------

	constant ZERO: Sorn_t := real_to_sorn(0.0);
	constant ZEROPOINTFIVE: Sorn_t := real_to_sorn(0.75);
	constant ONE: Sorn_t := real_to_sorn(1.0);

begin
	LFSR_GEN: for i in 0 to rand_arr'length-1 generate
		lfsr_inst: entity work.lfsr
		generic map
		(
			NUM_BITS		=> LFSR_WIDTH,
			MAX_NUM 		=> LFSR_MAX_NUM(i),
			DELAY 			=> 0,
			REPEAT_AFTER 	=> LFSR_INT_SIZE / NUM_CORES,
			SKIPPED_CYCLES 	=> (i * 17) + ((LFSR_INT_SIZE / (integer(Real(NUM_CORES) * 1.1))) * CORE_NUM)
		)
		port map
		(
			clk 		=> clk,
			reset 		=> rst,
			enable 		=> enable,
			repeating 	=> repeats(i),
			result_vec 	=> open,
			result_int 	=> rand_arr(i)
		);
	end generate LFSR_GEN;

	sorn_core_inst: entity work.sorn_core(comb)
	port map
	(
		clk 	=> clk,
		rst 	=> rst,
		input_valid => enable,
		s 		=> sin,
		c 		=> cos,
		target 	=> target,
		squared_norm => deviation,
		output_valid => output_valid,
		ls 		=> ls,
		lc 		=> lc,

		-- Debug
		error_xx => error_x,
		error_yy => error_y,
		error_zz => error_z,
		fk_x 	 => fk_x,
		fk_y 	 => fk_y,
		fk_z 	 => fk_z
	);

	process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				for i in 0 to sin'length-1 loop
					sin(i) <= ZERO_SORN;
					cos(i) <= ZERO_SORN;
				end loop;
					
				at_num_predefined <= 0;
			elsif enable = '1' then
				
				if at_num_predefined < num_predefined then
					sin(O1) <= ZERO;
					cos(O1) <= ONE;

					sin(O2) <= ZERO;
					cos(O2) <= ONE;

					sin(O3) <= ZERO;
					cos(O3) <= ONE;

					sin(O4) <= ZERO;
					cos(O4) <= ONE;

					sin(O5) <= ZERO;
					cos(O5) <= ONE;

					sin(O6) <= ZERO;
					cos(O6) <= ONE;

					at_num_predefined <= at_num_predefined + 1;
				else
					------- Handle Iterating through the Pairs ---------
					sin(O1) <= VALID_PAIR_O1(rand_arr(0)).sin;
					cos(O1) <= VALID_PAIR_O1(rand_arr(0)).cos;

					sin(O2) <= VALID_PAIR_O2(rand_arr(1)).sin;
					cos(O2) <= VALID_PAIR_O2(rand_arr(1)).cos;

					sin(O3) <= VALID_PAIR_O3(rand_arr(2)).sin;
					cos(O3) <= VALID_PAIR_O3(rand_arr(2)).cos;

					sin(O4) <= VALID_PAIR_O4(rand_arr(3)).sin;
					cos(O4) <= VALID_PAIR_O4(rand_arr(3)).cos;

					sin(O5) <= VALID_PAIR_O5(rand_arr(4)).sin;
					cos(O5) <= VALID_PAIR_O5(rand_arr(4)).cos;

					sin(O6) <= VALID_PAIR_O6(rand_arr(5)).sin;
					cos(O6) <= VALID_PAIR_O6(rand_arr(5)).cos;

				end if;

				-- Debug
				--sin(O1).bits(11)	<= '1';
				--sin(O2).bits(11)	<= '1';
				--sin(O4).bits(11)	<= '1';
				--sin(O5).bits(15)	<= '1';
				--sin(O6).bits(12) 	<= '1';
				--cos(O1).bits(15) 	<= '1';
				--cos(O2).bits(15) 	<= '1';
				--cos(O4).bits(9) 	<= '1';
				--cos(O5).bits(11) 	<= '1';
				--cos(O6).bits(16) 	<= '1';
			end if;
		end if;
	end process;

	done <= '1' when repeats = all_ones else '0';
end architecture;