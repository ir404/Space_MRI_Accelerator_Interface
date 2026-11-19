library IEEE;
use IEEE.std_logic_1164.all;

use work.SornDatatype.all;
use work.SornGlobal.all;
use work.SornSet.all;
use work.SornUtil.all;
use work.Sorn.all;

library std;
use std.textio.all;

package SignedSorn is
	constant SORN_NUM_BITS: integer := size(datatype);
	subtype SignedSornVector_t is std_ulogic_vector(SORN_NUM_BITS/2 downto 0);
	subtype SignedSornVectorWithSign_t is std_ulogic_vector(SORN_NUM_BITS/2 + 1 downto 0);

	type SignedSorn_t is record
		sign_bit: std_ulogic;
		bits: SignedSornVector_t;
	end record;

	constant EMPTY_SIGNEDSORN : SignedSorn_t :=
	(
		sign_bit => '0',
		bits => (others => '0')
	);

	constant FULL_SIGNEDSORN : SignedSorn_t :=
	(
		sign_bit => '0',
		bits => (others => '1')
	);

	-- generic bit-vector interface, mirrors the firstlast branch
	function from_bits(vec: SignedSornVectorWithSign_t) return SignedSorn_t;
	function to_bits(A: SignedSorn_t) return SignedSornVector_t;
	function as_bits(sorn: SignedSorn_t) return SignedSornVectorWithSign_t;

	function real_to_sorn(value: real) return SignedSorn_t;
	constant ZERO_SIGNEDSORN : SignedSorn_t := real_to_sorn(0.0);

	function to_string(A: SignedSorn_t) return string;
	function minimum(A: SignedSorn_t) return real;
	function maximum(A: SignedSorn_t) return real;
	function from_sorndatatype(datatype: SornDataype_t) return SignedSornDatatype_t;
end package;

package body SignedSorn is
	function from_bits(vec: SignedSornVectorWithSign_t) return SignedSorn_t is
		variable result: SignedSorn_t := EMPTY_SIGNEDSORN;
	begin
		result.sign_bit := vec(vec'high);
		result.bits := vec(vec'high-1 downto 0);
		return result;
	end function;

	function to_bits(A: SignedSorn_t) return SignedSornVector_t is
	begin
		return A.bits;
	end function;

	function as_bits(sorn: SignedSorn_t) return SignedSornVectorWithSign_t is
		variable result: SignedSornVectorWithSign_t;
	begin
		result := sorn.sign_bit & sorn.bits;
		return result;
	end function;

	function real_to_sorn(value: real) return SignedSorn_t is
		variable result: SignedSorn_t := EMPTY_SIGNEDSORN;
		variable temp_sorn: Sorn_t;
	begin
		temp_sorn := real_to_sorn(value);

		if value < 0.0 then
			result.sign_bit := '1';
			for i in 0 to SORN_NUM_BITS/2 loop
				result.bits(i) := temp_sorn.bits(SORN_NUM_BITS/2 - i);
			end loop;
		else
			result.sign_bit := '0';
			for i in 0 to SORN_NUM_BITS/2 loop
				result.bits(i) := temp_sorn.bits(SORN_NUM_BITS/2 + i);
			end loop;
		end if;

		return result;
	end function;

	function to_string(A: SignedSorn_t) return string is
		variable result: LINE;
		variable space: string(1 to 1) := " ";
		variable idx: integer;
	begin
		for i in 0 to SORN_NUM_BITS/2 loop
			if A.bits(i) = '1' then
				if A.sign_bit = '0' then
					idx := SORN_NUM_BITS/2 + i;
				else
					idx := SORN_NUM_BITS/2 - i;
				end if;
				write(result, to_string(get(datatype, idx)));
			end if;
		end loop;

		return result.all;
	end function;

	function minimum(A: SignedSorn_t) return real is
		variable idx: integer;
	begin
		if A.sign_bit = '0' then
			idx := SORN_NUM_BITS/2 + first_bit_set(A.bits);
		else
			idx := SORN_NUM_BITS/2 - last_bit_set(A.bits);
		end if;
		return get(datatype, idx).low_bound;
	end function;

	function maximum(A: SignedSorn_t) return real is
		variable idx: integer;
	begin
		if A.sign_bit = '0' then
			idx := SORN_NUM_BITS/2 + last_bit_set(A.bits);
		else
			idx := SORN_NUM_BITS/2 - first_bit_set(A.bits);
		end if;
		return get(datatype, idx).high_bound;
	end function;

	function from_sorndatatype(datatype: SornDataype_t) return SignedSornDatatype_t is
		variable result: SignedSornDatatype_t;
	begin
		for i in 0 to size(datatype) loop
			if get(datatype, i).low_bound > 0.0 then 
				result.append(result, get(datatype, i));
			end if;
		end loop;
	end function;

end package body;
