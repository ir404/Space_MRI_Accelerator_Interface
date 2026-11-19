library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use ieee.math_real.all;

library work;
use work.lfsr_fn.all;

entity lfsr is
generic
(
	NUM_BITS: 		integer := 10;
	MAX_NUM: 		integer := 31;
	SKIPPED_CYCLES: integer := 0;
	REPEAT_AFTER: 	integer := (2**NUM_BITS)-1;   -- In Cycles
	DELAY: 			integer := 0	-- Delay of 0 = Change at each Tick. Delay of 1 = Change at every second tick. Delay of 2 = Change every 3 Ticks...
);
port
(
	clk : 		in std_ulogic;
	reset: 		in std_ulogic;

	enable: 	in std_ulogic;
	repeating: 	out std_ulogic; -- '1' if it started repeating for one cycle
	delay_cnt:	out integer; 	-- Reflects the current delay counter
	
	result_vec : out std_ulogic_vector(NUM_BITS-1 downto 0);
	result_int : out integer range 0 to (2 ** NUM_BITS)-1
);
end entity lfsr;

architecture rtl of lfsr is
	constant UNIQUE_VALUES: integer := REPEAT_AFTER;
	constant ZERO_VEC: std_ulogic_vector(NUM_BITS downto 1) := (others => '0');
	constant START_VALUE: std_logic_vector(NUM_BITS downto 1) := LFSR_ADVANCE(ZERO_VEC, SKIPPED_CYCLES);

	signal LFSR_R: std_ulogic_vector (NUM_BITS downto 1) := (others => '0');
	signal count: integer range 0 to 2**NUM_BITS;
	signal linear_feedback: std_ulogic;
	signal repeating_r: std_ulogic;

	signal delay_counter: integer;
begin
	process(clk)
	begin
		if rising_edge(clk) then
			if reset = '1' then
				LFSR_R 			<= START_VALUE;
				repeating_r 	<= '0';
				count 			<= 0;
				delay_counter 	<= 0;
			elsif enable = '1' then
				delay_counter <= delay_counter + 1;

				if delay_counter = DELAY then
					LFSR_R 			<= LFSR_ADVANCE(LFSR_R, 1);
					delay_counter 	<= 0;

					count <= count + 1;
				end if;

				if count = UNIQUE_VALUES then
					repeating_r <= '1';
					count 	<= 0;
					LFSR_R 	<= START_VALUE;
					delay_counter <= 0;
				end if;
			end if;
		end if;
	end process;

	delay_cnt  <= delay_counter;
	repeating  <= repeating_r;
	result_vec <= LFSR_R;
	result_int <= to_integer(unsigned(LFSR_R)) mod MAX_NUM; -- Using mod viable ???

end architecture;