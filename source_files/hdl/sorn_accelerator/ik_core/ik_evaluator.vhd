library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.numeric_std.all;

library work;
use work.SornUtil.all;
use work.Sorn.all;
use work.SornOperators.all;
use work.global_pkg.all;

entity ik_evaluator is
generic
(
	NUM_IK_CORES: in integer;
	LFSR_SIZE:    in integer
);
port
(
	clk   : in std_ulogic;
	rst : in std_ulogic;

	enable: in std_ulogic;
	output_valid: out std_ulogic;
	done: out std_ulogic;

	target: in SornArr_t(2 downto 0);

	best_deviation: out Sorn_t;
	best_ls: out SornArr_t(5 downto 0);
	best_lc: out SornArr_t(5 downto 0);

	/* Debug */
	error_x: out Sorn_t;
	error_y: out Sorn_t;
	error_z: out Sorn_t;
	fk_x: out Sorn_t;
	fk_y: out Sorn_t;
	fk_z: out Sorn_t
);
end entity ik_evaluator;

architecture rtl of ik_evaluator is
	type array_of_sorn_arrays is array (0 to NUM_IK_CORES-1) of SornArr_t(5 downto 0);
	signal ls_arr, lc_arr: array_of_sorn_arrays;
	signal deviation_arr: SornArr_t(NUM_IK_CORES-1 downto 0);
	signal error_x_arr, error_y_arr, error_z_arr : SornArr_t(NUM_IK_CORES-1 downto 0);
	signal fk_x_arr, fk_y_arr, fk_z_arr : SornArr_t(NUM_IK_CORES-1 downto 0);
	signal done_arr : std_ulogic_vector(NUM_IK_CORES-1 downto 0);

	signal valid_signals: std_ulogic_vector(NUM_IK_CORES-1 downto 0);
	constant all_ones: std_ulogic_vector(NUM_IK_CORES-1 downto 0) := (others => '1');

	signal cores_valid: std_ulogic;
	signal output_valid_r: std_ulogic;
	signal output_valid_r_delay: std_ulogic;

	/* Returns index of ik_core with the least deviation */
	impure function fn_find_best return integer is
		variable cur_best: integer range 0 to NUM_IK_CORES := 0;
	begin
		for i in 0 to NUM_IK_CORES-1 loop
			if (deviation_arr(cur_best).bits > deviation_arr(i).bits and
				((fk_x_arr(i).bits and target(X).bits) /= (SornVector_t'range => '0') and 
				(fk_y_arr(i).bits and target(Y).bits) /= (SornVector_t'range => '0') and 
				(fk_z_arr(i).bits and target(Z).bits) /= (SornVector_t'range => '0'))) then

				cur_best := i;
			end if;
		end loop;

		return cur_best;
	end function;

begin
	
	IK_CORE_GEN: for i in 0 to NUM_IK_CORES-1 generate
		ik_core: entity work.ik_core
		generic map
		(
			CORE_NUM => i,
			NUM_CORES => NUM_IK_CORES,
			LFSR_SIZE => LFSR_SIZE
		)
		port map
		(
			clk => clk,
			rst => rst,
		
			/* Control */
			enable => enable,
			output_valid => valid_signals(i),
			done => done_arr(i),
		
			/* Data */
			target => target,
		
			deviation => deviation_arr(i),
			ls => ls_arr(i),
			lc => lc_arr(i),

			/* Debug */
			error_x => error_x_arr(i),
			error_y => error_y_arr(i),
			error_z => error_z_arr(i),
			fk_x => fk_x_arr(i),
			fk_y => fk_y_arr(i),
			fk_z => fk_z_arr(i)
		);
	end generate IK_CORE_GEN;

	process(clk)
		variable best_index: integer;
	begin
		if rising_edge(clk) then
			if rst = '1' then
				output_valid_r 	<= '0';
				best_deviation  <= EMPTY_SORN;
				best_lc			<= (others => EMPTY_SORN);
				best_ls			<= (others => EMPTY_SORN);

			elsif enable = '1' and cores_valid = '1' then
				best_index 		:= fn_find_best;
				output_valid_r 	<= '1';
				best_deviation 	<= deviation_arr(best_index);
				best_lc 		<= lc_arr(best_index);
				best_ls 		<= ls_arr(best_index);
				error_x			<= error_x_arr(best_index);
				error_y			<= error_y_arr(best_index);
				error_z			<= error_z_arr(best_index);
				fk_x			<= fk_x_arr(best_index);
				fk_y			<= fk_y_arr(best_index);
				fk_z			<= fk_z_arr(best_index);
			else
				output_valid_r <= '0';
			end if;

			output_valid_r_delay <= output_valid_r;
		end if;
	end process;

	cores_valid <= '1' when valid_signals = all_ones else '0';
	output_valid <= output_valid_r_delay;
	done <= '1' WHEN done_arr = all_ones else '0';
		
end architecture;
