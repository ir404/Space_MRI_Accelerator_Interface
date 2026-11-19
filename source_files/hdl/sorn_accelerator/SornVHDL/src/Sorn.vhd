library IEEE;
use IEEE.std_logic_1164.all;

library work;
use work.SornDatatype.all;
use work.SornGlobal.all;
use work.SornSet.all;
use work.SornUtil.all;

library std;
use std.textio.all;

package Sorn is
	constant SORN_NUM_BITS: integer := size(datatype);

	subtype SornVector_t is std_ulogic_vector(SORN_NUM_BITS-1 downto 0);
	type Sorn_t is record
		bits: SornVector_t;
	end record;

	type SornArr_t is array (natural range <>) of Sorn_t;

	constant EMPTY_SORN : Sorn_t :=
	(
		bits => (others => '0')
	);

	constant FULL_SORN : Sorn_t :=
	(
		bits => (others => '1')
	);

	-- generic bit-vector interface, mirrors the firstlast branch
	function from_bits(vec: SornVector_t) return Sorn_t;
	function to_bits(A: Sorn_t) return SornVector_t;

	function real_to_sorn(value: real) return Sorn_t;
	constant ZERO_SORN : Sorn_t := real_to_sorn(0.0);

	function to_string(A: Sorn_t) return string;
	function minimum(A: Sorn_t) return real;
	function maximum(A: Sorn_t) return real;
end package;

package body Sorn is
	function from_bits(vec: SornVector_t) return Sorn_t is
		variable result: Sorn_t := EMPTY_SORN;
	begin
		result.bits := vec;
		return result;
	end function;

	function to_bits(A: Sorn_t) return SornVector_t is
	begin
		return A.bits;
	end function;

	function real_to_sorn(value: real) return Sorn_t is
		variable result: Sorn_t := EMPTY_SORN;
		variable temp_set: RealSet_t;
	begin
		temp_set.low_bound := value;
		temp_set.high_bound := value;
		temp_set.low_bound_open := false;
		temp_set.high_bound_open := false;
		result.bits := map_set_to_bits(datatype, temp_set);
		return result;
	end function;

	function to_string(A: Sorn_t) return string is
		variable result: LINE;
		variable space: string(1 to 1) := " ";
	begin
		for i in 0 to SORN_NUM_BITS-1 loop
			if A.bits(i) = '1' then
				write(result, to_string(get(datatype, i)));
			end if;
		end loop;

		return result.all;
	end function;

	function minimum(A: Sorn_t) return real is
	begin
		return get(datatype, first_bit_set(A.bits)).low_bound;
	end function;

	function maximum(A: Sorn_t) return real is
	begin
		return get(datatype, last_bit_set(A.bits)).high_bound;
	end function;

end package body;