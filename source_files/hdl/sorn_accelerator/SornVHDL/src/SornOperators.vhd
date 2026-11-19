library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.math_real.all;

library work;
use work.SornDatatype.all;
use work.Sorn.all;
use work.SornGlobal.all;
use work.SornFixed.all;
use work.SornUtil.all;

library std;
use std.textio.all;

package SornOperators is
	function "+"(A: Sorn_t; B: Sorn_t) return Sorn_t;
	function "-"(A: Sorn_t; B: Sorn_t) return Sorn_t;
	function "*"(A: Sorn_t; B: Sorn_t) return Sorn_t;
	function pow2(A: Sorn_t) return Sorn_t;
	function sin(A: Sorn_t)  return Sorn_t;
	function cos(A: Sorn_t)  return Sorn_t;
	function "abs"(A: Sorn_t)  return Sorn_t;

	-- Next power of two in which SORN_NUM_BITS fits
	constant LIST_SIZE: integer range 0 to next_pow2(SORN_NUM_BITS) := next_pow2(SORN_NUM_BITS);

	type sorn_list_t is array (0 to LIST_SIZE-1) of SornVector_t;
	type sorn_table_t is array (0 to LIST_SIZE-1, 0 to LIST_SIZE-1) of SornVector_t;

	function add_table_generator return sorn_table_t;
	function sub_table_generator return sorn_table_t;
	function mul_table_generator return sorn_table_t;
	function pow2_list_generator return sorn_list_t;
	function sin_list_generator return sorn_list_t;
	function cos_list_generator return sorn_list_t;
	function abs_list_generator return sorn_list_t;
end package;

package body SornOperators is
	function add_table_generator return sorn_table_t is
		variable result: sorn_table_t;
		variable a: std_logic_vector(SORN_NUM_BITS-1 downto 0);
		variable b: std_logic_vector(SORN_NUM_BITS-1 downto 0);
		variable c: std_logic_vector(SORN_NUM_BITS-1 downto 0);
	begin
		for i in 0 to SORN_NUM_BITS-1 loop
			a := map_set_to_bits(datatype, get(datatype, i));
			for j in 0 to SORN_NUM_BITS-1 loop
				b := map_set_to_bits(datatype, get(datatype, j));
				c := addition(datatype, a, b);
				result(i, j) := c;
			end loop;
		end loop;

		return result;
	end function;

	function sub_table_generator return sorn_table_t is
		variable result: sorn_table_t;
		variable a: std_logic_vector(SORN_NUM_BITS-1 downto 0);
		variable b: std_logic_vector(SORN_NUM_BITS-1 downto 0);
		variable c: std_logic_vector(SORN_NUM_BITS-1 downto 0);
	begin
		for i in 0 to SORN_NUM_BITS-1 loop
			a := map_set_to_bits(datatype, get(datatype, i));
			for j in 0 to SORN_NUM_BITS-1 loop
				b := map_set_to_bits(datatype, get(datatype, j));
				c := subtraction(datatype, a, b);
				result(i, j) := c;
			end loop;
		end loop;

		return result;
	end function;

	function mul_table_generator return sorn_table_t is
		variable result: sorn_table_t;
		variable a: std_logic_vector(SORN_NUM_BITS-1 downto 0);
		variable b: std_logic_vector(SORN_NUM_BITS-1 downto 0);
		variable c: std_logic_vector(SORN_NUM_BITS-1 downto 0);
	begin
		for i in 0 to SORN_NUM_BITS-1 loop
			a := map_set_to_bits(datatype, get(datatype, i));
			for j in 0 to SORN_NUM_BITS-1 loop
				b := map_set_to_bits(datatype, get(datatype, j));
				c := multiplication(datatype, a, b);
				result(i, j) := c;
			end loop;
		end loop;

		return result;
	end function;

	function pow2_list_generator return sorn_list_t is
		variable result: sorn_list_t;
		variable a: std_logic_vector(SORN_NUM_BITS-1 downto 0);
		variable c: std_logic_vector(SORN_NUM_BITS-1 downto 0);
	begin
		for i in 0 to SORN_NUM_BITS-1 loop
			a := map_set_to_bits(datatype, get(datatype, i));
			c := pow(datatype, a, 2.0);
			result(i) := c;
		end loop;

		return result;
	end function;

	function sin_list_generator return sorn_list_t is
		variable result: sorn_list_t;
		variable a: std_logic_vector(SORN_NUM_BITS-1 downto 0);
		variable c: std_logic_vector(SORN_NUM_BITS-1 downto 0);
	begin
		for i in 0 to SORN_NUM_BITS-1 loop
			a := map_set_to_bits(datatype, get(datatype, i));
			c := sin(datatype, a);
			result(i) := c;
		end loop;

		return result;
	end function;

	function cos_list_generator return sorn_list_t is
		variable result: sorn_list_t;
		variable a: std_logic_vector(SORN_NUM_BITS-1 downto 0);
		variable c: std_logic_vector(SORN_NUM_BITS-1 downto 0);
	begin
		for i in 0 to SORN_NUM_BITS-1 loop
			a := map_set_to_bits(datatype, get(datatype, i));
			c := cos(datatype, a);
			result(i) := c;
		end loop;

		return result;
	end function;

	function abs_list_generator return sorn_list_t is
		variable result: sorn_list_t;
		variable a: std_logic_vector(SORN_NUM_BITS-1 downto 0);
		variable c: std_logic_vector(SORN_NUM_BITS-1 downto 0);
	begin
		for i in 0 to SORN_NUM_BITS-1 loop
			a := map_set_to_bits(datatype, get(datatype, i));
			c := absolute(datatype, a);
			result(i) := c;
		end loop;

		return result;
	end function;

	constant ADD_TABLE:  sorn_table_t := add_table_generator;
	constant SUB_TABLE:  sorn_table_t := sub_table_generator;
	constant MUL_TABLE:  sorn_table_t := mul_table_generator;
	constant POW2_TABLE: sorn_list_t  := pow2_list_generator;
	constant SIN_TABLE:  sorn_list_t  := sin_list_generator;
	constant COS_TABLE:  sorn_list_t  := cos_list_generator;
	constant ABS_TABLE:  sorn_list_t  := abs_list_generator;

	function "+"(A: Sorn_t; B: Sorn_t) return Sorn_t is
		variable result: Sorn_t := EMPTY_SORN;
	begin
		for i in 0 to A.bits'length-1 loop
			for j in 0 to B.bits'length-1 loop
				if A.bits(i) = '1' and B.bits(j) = '1' then
					result.bits := result.bits or ADD_TABLE(i, j);
				end if;
			end loop;
		end loop;

		return result;
	end function;

	function "-"(A: Sorn_t; B: Sorn_t) return Sorn_t is
		variable result: Sorn_t := EMPTY_SORN;
	begin
		for i in 0 to A.bits'length-1 loop
			for j in 0 to B.bits'length-1 loop
				if A.bits(i) = '1' and B.bits(j) = '1' then
					result.bits := result.bits or SUB_TABLE(i, j);
				end if;
			end loop;
		end loop;

		return result;
	end function;

	function "*"(A: Sorn_t; B: Sorn_t) return Sorn_t is
		variable result: Sorn_t := EMPTY_SORN;
	begin
		for i in 0 to A.bits'length-1 loop
			for j in 0 to B.bits'length-1 loop
				if A.bits(i) = '1' and B.bits(j) = '1' then
					result.bits := result.bits or MUL_TABLE(i, j);
				end if;
			end loop;
		end loop;

		return result;
	end function;

	function "abs"(A: Sorn_t) return Sorn_t is
		variable result: Sorn_t := EMPTY_SORN;
	begin
		result.bits := ABS_TABLE(first_bit_set(A.bits));
		result.bits := result.bits or ABS_TABLE(last_bit_set(A.bits));
		return result;
	end function;

	function pow2(A: Sorn_t) return Sorn_t is
		variable result: Sorn_t := EMPTY_SORN;
	begin
		for i in 0 to A.bits'length-1 loop
			if A.bits(i) = '1' then
				result.bits := result.bits or POW2_TABLE(i);
			end if;
		end loop;

		return result;
	end function;

	function sin(A: Sorn_t) return Sorn_t is
		variable result: Sorn_t := EMPTY_SORN;
	begin
		for i in 0 to A.bits'length-1 loop
			if A.bits(i) = '1' then
				result.bits := result.bits or SIN_TABLE(i);
			end if;
		end loop;

		return result;
	end function;

	function cos(A: Sorn_t) return Sorn_t is
		variable result: Sorn_t := EMPTY_SORN;
	begin
		for i in 0 to A.bits'length-1 loop
			if A.bits(i) = '1' then
				result.bits := result.bits or COS_TABLE(i);
			end if;
		end loop;

		return result;
	end function;

end package body;