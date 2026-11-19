library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.math_real.all;
use IEEE.fixed_pkg.all;

library work;
use work.SornDatatype.all;
use work.Sorn.all;
use work.SornGlobal.all;
use work.SornFixed.all;
use work.SornUtil.all;
use work.SornOperators.all;

package SornManipulatorLimits is
	type SinCosPair_t is record
		sin: Sorn_t;
		cos: Sorn_t;
	end record;
	constant EMPTY_SINCOS_PAIR: SinCosPair_t := (EMPTY_SORN, EMPTY_SORN);
	type SinCosArr_t is array (natural range <>) of SinCosPair_t;
	type AngleTable_t is array (0 to LIST_SIZE-1, 0 to LIST_SIZE-1) of SornFixed_t;

	function sincos_to_angle_real(s: std_logic_vector; c: std_logic_vector) return real;
	function sincos_to_angle(s: std_logic_vector; c: std_logic_vector) return SornFixed_t;
	function sincos_to_angle_table_gen return AngleTable_t;
	function rad_to_deg(rad: real) return real;
	function rad_to_deg(rad: sfixed) return sfixed;
	function is_valid_pair(pair: SinCosPair_t) return boolean;
	function get_num_valid_pairs(degl: real; degh: real) return integer;
	function fill_valid_pairs(degl: real; degh: real) return SinCosArr_t;

	constant VALID_PAIR_O1: SinCosArr_t(next_pow2(get_num_valid_pairs(-180.0, 180.0))-1 downto 0) := fill_valid_pairs(-180.0, 180.0);
	constant VALID_PAIR_O2: SinCosArr_t(next_pow2(get_num_valid_pairs(-180.0, 180.0))-1 downto 0) := fill_valid_pairs(-180.0, 180.0);
	constant VALID_PAIR_O3: SinCosArr_t(next_pow2(get_num_valid_pairs(-180.0, 180.0))-1 downto 0) := fill_valid_pairs(-180.0, 180.0);
	constant VALID_PAIR_O4: SinCosArr_t(next_pow2(get_num_valid_pairs(-180.0, 180.0))-1 downto 0) := fill_valid_pairs(-180.0, 180.0);
	constant VALID_PAIR_O5: SinCosArr_t(next_pow2(get_num_valid_pairs(-180.0, 180.0))-1 downto 0) := fill_valid_pairs(-180.0, 180.0);
	constant VALID_PAIR_O6: SinCosArr_t(next_pow2(get_num_valid_pairs(-180.0, 180.0))-1 downto 0) := fill_valid_pairs(-180.0, 180.0);

	--constant VALID_PAIR_O1: SinCosArr_t(63 downto 0) := (others =>  EMPTY_SINCOS_PAIR);
	--constant VALID_PAIR_O2: SinCosArr_t(31 downto 0) := (others =>  EMPTY_SINCOS_PAIR);
	--constant VALID_PAIR_O3: SinCosArr_t(63 downto 0) := (others =>  EMPTY_SINCOS_PAIR);
	--constant VALID_PAIR_O4: SinCosArr_t(63 downto 0) := (others =>  EMPTY_SINCOS_PAIR);
	--constant VALID_PAIR_O5: SinCosArr_t(3 downto 0)  := (others =>  EMPTY_SINCOS_PAIR);
	--constant VALID_PAIR_O6: SinCosArr_t(63 downto 0) := (others =>  EMPTY_SINCOS_PAIR);

	constant SINCOS_TO_ANGLE_TABLE: AngleTable_t := sincos_to_angle_table_gen;

	constant LOWER_D1: real := 0.0;
	constant HIGHER_D1: real := 0.0;

	constant LOWER_D2: real := 0.0;
	constant HIGHER_D2: real := 0.0;
	
	constant LOWER_D3: real := -1.0;
	constant HIGHER_D3: real := 2.0;
	
	constant LOWER_D4: real := 0.0;
	constant HIGHER_D4: real := 0.0;
	
	constant LOWER_D5: real := 0.0;
	constant HIGHER_D5: real := 0.0;
	
	constant LOWER_D6: real := 0.0;
	constant HIGHER_D6: real := 0.0;

end package;

package body SornManipulatorLimits is
	function sincos_to_angle_real(s: std_logic_vector; c: std_logic_vector) return real is
		variable sine: real := to_real_midpoint(datatype, s);
		variable cosine: real := to_real_midpoint(datatype, c);
	begin
		return atan2(sine, cosine);
	end function;

	function sincos_to_angle(s: std_logic_vector; c: std_logic_vector) return SornFixed_t is
	begin
		return SINCOS_TO_ANGLE_TABLE(first_bit_set(s), first_bit_set(c));
	end function;

	function sincos_to_angle_table_gen return AngleTable_t is
		variable result: AngleTable_t;
		variable a: std_logic_vector(SORN_NUM_BITS-1 downto 0);
		variable b: std_logic_vector(SORN_NUM_BITS-1 downto 0);
		variable angle: real;
	begin
		for i in 0 to SORN_NUM_BITS-1 loop
			a := map_set_to_bits(datatype, get(datatype, i));
			for j in 0 to SORN_NUM_BITS-1 loop
				b := map_set_to_bits(datatype, get(datatype, j));
				angle := sincos_to_angle_real(a, b);
				result(i, j) := to_sfixed(angle, SornFixed_t'high, SornFixed_t'low);
			end loop;
		end loop;

		return result;
	end function;

	function rad_to_deg(rad: real) return real is
	begin
		return rad * (180.0/MATH_PI);
	end function;

	constant RAD_TO_DEG_CONST: SornFixed_t := to_sfixed(180.0/MATH_PI, SornFixed_t'high, SornFixed_t'low);

	function rad_to_deg(rad: sfixed) return sfixed is
	begin
		return resize(rad * RAD_TO_DEG_CONST, rad'high, rad'low);
	end function;

	procedure set_bit(srn: inout Sorn_t; index: integer) is
	begin
		srn.bits := (others => '0');
		srn.bits(index) := '1';	
	end procedure;

	function is_valid_pair(pair: SinCosPair_t) return boolean is
		variable sin2: Sorn_t := pow2(pair.sin);
		variable cos2: Sorn_t := pow2(pair.cos);
		variable sum: Sorn_t := sin2 + cos2;
		variable one: Sorn_t := real_to_sorn(1.0);
	begin
		if (sum.bits and one.bits) /= EMPTY_SORN.bits then
			return true;
		end if;

		return false;
	end function;

	function get_num_valid_pairs(degl: real; degh: real) return integer is
		variable temp_sin: Sorn_t;
		variable temp_cos: Sorn_t;
		variable angle_max: real;
		variable angle_min: real;
		variable temp_angle: real;

		variable num:  integer := 0;
		variable high: integer := first_bit_set(real_to_sorn(1.0).bits);
		variable low:  integer := first_bit_set(real_to_sorn(-1.0).bits);
	begin
		for i in low to high loop
			set_bit(temp_sin, i);
			inner_loop: for j in low to high loop
				set_bit(temp_cos, j);
				if not is_valid_pair((temp_sin, temp_cos)) then next inner_loop; end if;
				angle_max := rad_to_deg(atan2(minimum(temp_sin), minimum(temp_cos)));
				angle_min := rad_to_deg(atan2(maximum(temp_sin), maximum(temp_cos)));

				if angle_min > angle_max then
					temp_angle := angle_max;
					angle_max := angle_min;
					angle_min := temp_angle;
				end if;

				if (angle_min >= degl and angle_max <= degh) then
					num := num + 1;
				end if;
			end loop inner_loop;
		end loop;

		return num;
	end function;

	function fill_valid_pairs(degl: real; degh: real) return SinCosArr_t is
		variable num_pairs: integer := next_pow2(get_num_valid_pairs(degl, degh));
		variable result: SinCosArr_t(num_pairs-1 downto 0);
		variable temp_sin: Sorn_t;
		variable temp_cos: Sorn_t;
		variable angle_max: real;
		variable angle_min: real;
		variable temp_angle: real;

		variable num:  integer := 0;
		variable high: integer := first_bit_set(real_to_sorn(1.0).bits);
		variable low:  integer := first_bit_set(real_to_sorn(-1.0).bits);
	begin
		for i in low to high loop
			set_bit(temp_sin, i);
			inner_loop: for j in low to high loop
				set_bit(temp_cos, j);
				if not is_valid_pair((temp_sin, temp_cos)) then next inner_loop; end if;
				angle_max := rad_to_deg(atan2(minimum(temp_sin), minimum(temp_cos)));
				angle_min := rad_to_deg(atan2(maximum(temp_sin), maximum(temp_cos)));

				if angle_min > angle_max then
					temp_angle := angle_max;
					angle_max := angle_min;
					angle_min := temp_angle;
				end if;

				if (angle_min >= degl and angle_max <= degh) then
					result(num) := (temp_sin, temp_cos);
					num := num + 1;
				end if;
			end loop inner_loop;
		end loop;

		-- Fill empty space
		for i in num to num_pairs-1 loop
			result(i) := result(0);
		end loop;

		return result;
	end function;
end package body;