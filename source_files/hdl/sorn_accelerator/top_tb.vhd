library ieee;
use ieee.std_logic_1164.all;
use ieee.fixed_pkg.all;
library work;
use work.AcceleratorPKG.all;

entity top_tb is
	generic
	(
		LFSR_SIZE: integer range 1 to 30 := 12;
		NUM_CORES: integer range 1 to integer'high := 1
	);
end entity top_tb;

architecture sim of top_tb is

	constant CLK_PERIOD: time := 10 ns;
	constant LF: character := character'val(10);

	signal clk: std_ulogic := '0';
	signal reset: std_ulogic := '1';

	signal target_x: SornFixed_t := (others => '0');
	signal target_y: SornFixed_t := (others => '0');
	signal target_z: SornFixed_t := (others => '0');
	signal start: std_ulogic := '0';

	signal j0_in_rad: SornFixed_t;
	signal j1_in_rad: SornFixed_t;
	signal j2_in_rad: SornFixed_t;
	signal j3_in_rad: SornFixed_t;
	signal j4_in_rad: SornFixed_t;
	signal j5_in_rad: SornFixed_t;
	signal valid: std_ulogic;
	signal time_in_compute: integer := 0;

begin

	dut: entity work.accelerator(rtl)
		generic map
		(
			LFSR_SIZE => LFSR_SIZE,
			NUM_CORES => NUM_CORES
		)
		port map
		(
			clk => clk,
			reset => reset,
			target_x => target_x,
			target_y => target_y,
			target_z => target_z,
			start => start,
			j0_in_rad => j0_in_rad,
			j1_in_rad => j1_in_rad,
			j2_in_rad => j2_in_rad,
			j3_in_rad => j3_in_rad,
			j4_in_rad => j4_in_rad,
			j5_in_rad => j5_in_rad,
			valid => valid,
			time_in_compute => time_in_compute
		);

	clk_gen: process
	begin
		loop
			clk <= '0';
			wait for CLK_PERIOD / 2;
			clk <= '1';
			wait for CLK_PERIOD / 2;
		end loop;
	end process;

	stimulus: process
	begin
		reset <= '1';
		for i in 1 to 3 loop
			wait until rising_edge(clk);
		end loop;
		reset <= '0';

		target_x <= to_sfixed(0.3125, target_x);
		target_y <= to_sfixed(0.25, target_y);
		target_z <= to_sfixed(0.375, target_z);
		start <= '1';
		wait until rising_edge(clk);
		start <= '0';

		wait until rising_edge(valid);

		report
			LF &
			LF &
			"============" &
			LF & "result:" &
			LF & "j0 = " & real'image(to_real(j0_in_rad)) &
			LF & "j1 = " & real'image(to_real(j1_in_rad)) &
			LF & "j2 = " & real'image(to_real(j2_in_rad)) &
			LF & "j3 = " & real'image(to_real(j3_in_rad)) &
			LF & "j4 = " & real'image(to_real(j4_in_rad)) &
			LF & "j5 = " & real'image(to_real(j5_in_rad)) &
			LF & "took " & integer'image(time_in_compute) & " clock cycles" &
			LF & "============" &
			LF &
			LF;

		std.env.finish;
	end process;

end architecture sim;
