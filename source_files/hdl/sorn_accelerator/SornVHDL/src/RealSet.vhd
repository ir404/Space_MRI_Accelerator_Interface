library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_textio.all;
use IEEE.math_real.all;
use IEEE.math_complex.all;

library std;
use std.textio.all;

package SornSet is
	type RealSet_t is record
		low_bound:  real;
		low_bound_open: boolean;

		high_bound: real;
		high_bound_open: boolean;
	end record;

	constant INF_REALSET: RealSet_t :=
	(
		low_bound => 1.0E29,
		low_bound_open => false,
		high_bound => 1.0E29,
		high_bound_open => false
	);
	
	function to_string(set: RealSet_t) return string;
	function is_closed(set: RealSet_t) return boolean;
	function is_open(set: RealSet_t) return boolean;
	function is_leftopen(set: RealSet_t) return boolean;
	function is_rightopen(set: RealSet_t) return boolean;
	function is_exact(set: RealSet_t) return boolean;
end package;

package body SornSet is
	function to_string(set: RealSet_t) return string is
		variable left_bracket: string(1 to 1) := "[";
		variable right_bracket: string(1 to 1) := "]";
	begin
		if set.low_bound_open then
			left_bracket := "(";
		end if;

		if set.high_bound_open then
			right_bracket := ")";
		end if;

		return left_bracket & to_string(set.low_bound, "%.5f") & ", " & to_string(set.high_bound, "%.5f") & right_bracket & " ";
	end function;

	function is_closed(set: RealSet_t) return boolean is
	begin
		return not set.low_bound_open and not set.high_bound_open;
	end function;

	function is_open(set: RealSet_t) return boolean is
	begin
		return set.low_bound_open or set.high_bound_open;
	end function;

	function is_leftopen(set: RealSet_t) return boolean is
	begin
		return set.low_bound_open;
	end function;

	function is_rightopen(set: RealSet_t) return boolean is
	begin
		return set.high_bound_open;
	end function;

	function is_exact(set: RealSet_t) return boolean is
	begin
		return (set.low_bound = set.high_bound) and (set.low_bound_open = set.high_bound_open);
	end function;
end package body;