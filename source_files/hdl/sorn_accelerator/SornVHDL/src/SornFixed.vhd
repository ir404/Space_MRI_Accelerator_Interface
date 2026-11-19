library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.fixed_pkg.all;

library work;
use work.SornDatatype.all;
use work.Sorn.all;
use work.SornGlobal.all;
use work.SornUtil.all;

package SornFixed is
	-- Precision used whenever a SORN is converted to/from fixed-point
	subtype SornFixed_t is sfixed(3 downto -4); -- 16 / 0.0625

	-- Next power of two in which SORN_NUM_BITS fits
	constant FIXED_LIST_SIZE: integer range 0 to next_pow2(SORN_NUM_BITS) := next_pow2(SORN_NUM_BITS);

	type sorn_fixed_list_t is array (0 to FIXED_LIST_SIZE-1) of SornFixed_t;

	-- Every bit pattern SornFixed_t can hold, mapped to a Sorn_t
	constant SORN_FROM_FIXED_SIZE: integer := 2**SornFixed_t'length;
	type sorn_from_fixed_table_t is array (0 to SORN_FROM_FIXED_SIZE-1) of Sorn_t;

	function to_real_midpoint(datatype: SornDatatype_t; a: std_logic_vector) return real;
	function to_fixed_midpoint(datatype: SornDatatype_t; a: std_logic_vector) return SornFixed_t;
	function to_fixed_midpoint(A: Sorn_t) return SornFixed_t;
	function to_sorn(A: SornFixed_t) return Sorn_t;

	function midpoint_list_generator return sorn_fixed_list_t;
	function sorn_from_fixed_table_generator return sorn_from_fixed_table_t;
end package;

package body SornFixed is
	function to_real_midpoint(datatype: SornDatatype_t; a: std_logic_vector) return real is
		variable low: real := get(datatype, first_bit_set(a)).low_bound;
		variable high: real := get(datatype, first_bit_set(a)).high_bound;
	begin
		return (low + high) / 2.0;
	end function;

	function to_fixed_midpoint(datatype: SornDatatype_t; a: std_logic_vector) return SornFixed_t is
		variable result: SornFixed_t;
	begin
		result := to_sfixed(to_real_midpoint(datatype, a), result'high, result'low);
		return result;
	end function;

	function midpoint_list_generator return sorn_fixed_list_t is
		variable result: sorn_fixed_list_t;
		variable a: std_logic_vector(SORN_NUM_BITS-1 downto 0);
	begin
		for i in 0 to SORN_NUM_BITS-1 loop
			a := map_set_to_bits(datatype, get(datatype, i));
			result(i) := to_fixed_midpoint(datatype, a);
		end loop;

		return result;
	end function;

	constant MIDPOINT_TABLE: sorn_fixed_list_t := midpoint_list_generator;

	function to_fixed_midpoint(A: Sorn_t) return SornFixed_t is
		variable lo:  SornFixed_t := MIDPOINT_TABLE(first_bit_set(A.bits));
		variable hi:  SornFixed_t := MIDPOINT_TABLE(last_bit_set(A.bits));
		-- Divide (lo + hi) by 2 for free: reinterpret the sum's bits with the
		-- binary point shifted one place to the right, instead of the extra
		-- integer bit the "+" operator grew the sum by.
		variable mid: sfixed(SornFixed_t'high downto SornFixed_t'low-1) := sfixed(lo + hi);
	begin
		return resize(mid, SornFixed_t'high, SornFixed_t'low);
	end function;

	function sorn_from_fixed_table_generator return sorn_from_fixed_table_t is
		variable result: sorn_from_fixed_table_t;
		variable val: SornFixed_t;
	begin
		for i in 0 to SORN_FROM_FIXED_SIZE-1 loop
			-- Reinterpret the raw bit pattern i as a SornFixed_t (free, no
			-- hardware): to_real is only ever evaluated here, at elaboration
			-- time while building this ROM, never on a runtime signal.
			val := sfixed(to_unsigned(i, SornFixed_t'length));
			result(i) := real_to_sorn(to_real(val));
		end loop;

		return result;
	end function;

	constant SORN_FROM_FIXED_TABLE: sorn_from_fixed_table_t := sorn_from_fixed_table_generator;

	function to_sorn(A: SornFixed_t) return Sorn_t is
	begin
		-- Pure ROM lookup at runtime: no floating point in hardware.
		return SORN_FROM_FIXED_TABLE(to_integer(unsigned(to_slv(A))));
	end function;
end package body;
