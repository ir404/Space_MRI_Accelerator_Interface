library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_textio.all;
use IEEE.math_real.all;
use IEEE.math_complex.all;

library std;
use std.textio.all;

library work;
use work.SornSet.all;
use work.SornUtil.all;
use work.SornDatatype.all;
use work.SornGlobal.all;

package SignedSornDatatype is
	type RealSetArr_t is array(0 to 512) of RealSet_t; -- Reserve enough space for big datatypes
	type SignedSornDatatype_t is record
		internal_arr: RealSetArr_t;
		cur_size: integer;
	end record SignedSornDatatype_t;

	-- Divides the results from the Addition/Subtraction by this number
	-- Just a heuristic, needs to be tested in the real world still.
	constant addsub_clip: real := 1.0;

	procedure clear(datatype: inout SignedSornDatatype_t);
	procedure append(datatype: inout SignedSornDatatype_t; set: RealSet_t);
	function size(datatype: SignedSornDatatype_t) return integer;
	function get(datatype: SignedSornDatatype_t; index: integer) return RealSet_t;
	function from_sorndatatype(datatype: SornDataype_t) return SignedSornDatatype_t;
	function to_string(datatype: SignedSornDatatype_t) return string;
	function addition(datatype: SignedSornDatatype_t; a: std_logic_vector; b: std_logic_vector) return std_logic_vector;
	function subtraction(datatype: SignedSornDatatype_t; a: std_logic_vector; b: std_logic_vector) return std_logic_vector;
	function multiplication(datatype: SignedSornDatatype_t; a: std_logic_vector; b: std_logic_vector) return std_logic_vector;
	function division(datatype: SignedSornDatatype_t; a: std_logic_vector; b: std_logic_vector) return std_logic_vector;
	function pow(datatype: SignedSornDatatype_t; a: std_logic_vector; exponent: real) return std_logic_vector;
	function sin(datatype: SignedSornDatatype_t; a: std_logic_vector) return std_logic_vector;
	function cos(datatype: SignedSornDatatype_t; a: std_logic_vector) return std_logic_vector;
	function absolute(datatype: SignedSornDatatype_t; a: std_logic_vector) return std_logic_vector;
	function map_set_to_bits(datatype: SignedSornDatatype_t; param: RealSet_t) return std_logic_vector;
	function from_string(s: string) return SignedSornDatatype_t;

end package;

package body SignedSornDatatype is
	procedure clear(datatype: inout SignedSornDatatype_t) is
	begin
		datatype.cur_size := 0;
	end procedure;

	procedure append(datatype: inout SignedSornDatatype_t; set: RealSet_t) is
	begin
		datatype.internal_arr(datatype.cur_size) := set;
		datatype.cur_size := datatype.cur_size + 1;
	end procedure;

	function size(datatype: SignedSornDatatype_t) return integer is
	begin
		return datatype.cur_size;
	end function;

	function get(datatype: SignedSornDatatype_t; index: integer) return RealSet_t is
	begin
		return datatype.internal_arr(index);
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

	function to_string(datatype: SignedSornDatatype_t) return string is
		variable result: LINE;
		variable space: string(1 to 1) := " ";
	begin
		for i in 0 to datatype.cur_size-1 loop
			write(result, to_string(get(datatype, i)));
			write(result, space);
		end loop;

		return result.all;
	end function;

	function most_dense_interval(datatype: SignedSornDatatype_t) return RealSet_t is
		variable best: RealSet_t := INF_REALSET;
		variable bestd: real     := best.high_bound - best.low_bound;

		variable cur: RealSet_t;
		variable curd: real;
	begin
		for i in 0 to datatype.cur_size-1 loop
			cur  := get(datatype, i);
			curd := cur.high_bound - cur.low_bound;
			if curd < bestd then
				best  := cur;
				bestd := curd;
			end if;
		end loop;

		return best;
	end function;

	function map_set_to_bits(datatype: SignedSornDatatype_t; param: RealSet_t) return std_logic_vector is
		variable dt_set: RealSet_t;
		variable set: RealSet_t := param;
		variable result: std_logic_vector(datatype.cur_size-1 downto 0);
	begin
		for i in 0 to datatype.cur_size-1 loop
			dt_set := get(datatype, i);

			if cmp_real(set.low_bound, set.high_bound) then
				set.low_bound_open := false;
				set.high_bound_open := false;
			end if;

			if not((set.high_bound < dt_set.low_bound)  or
					(cmp_real(set.high_bound, dt_set.low_bound) and (set.high_bound_open or dt_set.low_bound_open))  or
					(set.low_bound  > dt_set.high_bound) or
					(cmp_real(set.low_bound, dt_set.high_bound) and (set.low_bound_open or dt_set.high_bound_open))) then
				result(i) := '1';
			else
				result(i) := '0';
			end if;
		end loop;

		return result;
	end function;

	function addition(datatype: SignedSornDatatype_t; a: std_logic_vector; b: std_logic_vector) return std_logic_vector is
		variable al: RealSet_t := get(datatype, first_bit_set(a));
		variable ah: RealSet_t := get(datatype, last_bit_set(a));
		variable bl: RealSet_t := get(datatype, first_bit_set(b));
		variable bh: RealSet_t := get(datatype, last_bit_set(b));
		variable resulting_set: RealSet_t;
	begin
		resulting_set.low_bound       := (al.low_bound + bl.low_bound) / addsub_clip;
		resulting_set.high_bound      := (ah.high_bound + bh.high_bound) / addsub_clip;
		resulting_set.low_bound_open  := al.low_bound_open or bl.low_bound_open;
		resulting_set.high_bound_open := ah.high_bound_open or bh.high_bound_open;

		return map_set_to_bits(datatype, resulting_set);
	end function;

	function subtraction(datatype: SignedSornDatatype_t; a: std_logic_vector; b: std_logic_vector) return std_logic_vector is
		variable al:  RealSet_t := get(datatype, first_bit_set(a));
		variable ah: RealSet_t  := get(datatype, last_bit_set(a));
		variable bl:  RealSet_t := get(datatype, first_bit_set(b));
		variable bh: RealSet_t  := get(datatype, last_bit_set(b));
		variable resulting_set: RealSet_t;
	begin
		resulting_set.low_bound       := (al.low_bound - bh.high_bound) / addsub_clip;
		resulting_set.high_bound      := (ah.high_bound - bl.low_bound) / addsub_clip;
		resulting_set.low_bound_open  := al.low_bound_open or bh.high_bound_open;
		resulting_set.high_bound_open := ah.high_bound_open or bl.low_bound_open;

		return map_set_to_bits(datatype, resulting_set);
	end function;

	function multiplication(datatype: SignedSornDatatype_t; a: std_logic_vector; b: std_logic_vector) return std_logic_vector is
		variable al: RealSet_t := get(datatype, first_bit_set(a));
		variable ah: RealSet_t := get(datatype, last_bit_set(a));
		variable bl: RealSet_t := get(datatype, first_bit_set(b));
		variable bh: RealSet_t := get(datatype, last_bit_set(b));

		variable x: real;
		variable y: real;
		variable z: real;
		variable w: real;
		variable smallest: real;
		variable biggest:  real;
		variable left_open:  boolean := false;
		variable right_open: boolean := false;
		variable resulting_set: RealSet_t;
	begin
		x := al.low_bound  * bl.low_bound;
		y := ah.high_bound * bh.high_bound;
		z := al.low_bound  * bh.high_bound;
		w := ah.high_bound * bl.low_bound;

		smallest := minimum(minimum(x, y), minimum(z, w));
		biggest  := maximum(maximum(x, y), maximum(z, w));

		if cmp_real(smallest, x) then
			left_open := al.low_bound_open or bl.low_bound_open;
		elsif cmp_real(smallest, y) then
			left_open := ah.high_bound_open or bh.high_bound_open;
		elsif cmp_real(smallest, z) then
			left_open := al.low_bound_open or bh.high_bound_open;
		elsif cmp_real(smallest, w) then
			left_open := ah.high_bound_open or bl.low_bound_open;
		end if;

		if cmp_real(biggest, x) then
			right_open := al.low_bound_open or bl.low_bound_open;
		elsif cmp_real(biggest, y) then
			right_open := ah.high_bound_open or bl.high_bound_open;
		elsif cmp_real(biggest, z) then
			right_open := al.low_bound_open or bh.high_bound_open;
		elsif cmp_real(biggest, w) then
			right_open := ah.high_bound_open or bl.low_bound_open;
		end if;

		resulting_set.low_bound  := minimum(minimum(x, y), minimum(z, w));
		resulting_set.high_bound := maximum(maximum(x, y), maximum(z, w));
		resulting_set.low_bound_open  := left_open;
		resulting_set.high_bound_open := right_open;
		
		return map_set_to_bits(datatype, resulting_set);
	end function;

	function division(datatype: SignedSornDatatype_t; a: std_logic_vector; b: std_logic_vector) return std_logic_vector is
		variable al: RealSet_t := get(datatype, first_bit_set(a));
		variable ah: RealSet_t := get(datatype, last_bit_set(a));
		variable bl: RealSet_t := get(datatype, first_bit_set(b));
		variable bh: RealSet_t := get(datatype, last_bit_set(b));

		variable x: real;
		variable y: real;
		variable z: real;
		variable w: real;
		variable smallest: real;
		variable biggest:  real;
		variable left_open:  boolean := false;
		variable right_open: boolean := false;
		variable resulting_set: RealSet_t;
	begin
		-- TODO: Division durch null beachten
		x := al.low_bound  / bl.low_bound;
		y := ah.high_bound / bh.high_bound;
		z := al.low_bound  / bh.high_bound;
		w := ah.high_bound / bl.low_bound;

		smallest := minimum(minimum(x, y), minimum(z, w));
		biggest  := maximum(maximum(x, y), maximum(z, w));

		if cmp_real(smallest, x) then
			left_open := al.low_bound_open or bl.low_bound_open;
		elsif cmp_real(smallest, y) then
			left_open := ah.high_bound_open or bl.high_bound_open;
		elsif cmp_real(smallest, z) then
			left_open := al.low_bound_open or bh.high_bound_open;
		elsif cmp_real(smallest, w) then
			left_open := ah.high_bound_open or bl.low_bound_open;
		end if;

		if cmp_real(biggest, x) then
			right_open := al.low_bound_open or bl.low_bound_open;
		elsif cmp_real(biggest, y) then
			right_open := ah.high_bound_open or bl.high_bound_open;
		elsif cmp_real(biggest, z) then
			right_open := al.low_bound_open or bh.high_bound_open;
		elsif cmp_real(biggest, w) then
			right_open := ah.high_bound_open or bl.low_bound_open;
		end if;

		resulting_set.low_bound  := minimum(minimum(x, y), minimum(z, w));
		resulting_set.high_bound := maximum(maximum(x, y), maximum(z, w));
		resulting_set.low_bound_open  := left_open;
		resulting_set.high_bound_open := right_open;

		return map_set_to_bits(datatype, resulting_set);
	end function;

	function pow(datatype: SignedSornDatatype_t; a: std_logic_vector; exponent: real) return std_logic_vector is
		variable al: RealSet_t := get(datatype, first_bit_set(a));
		variable ah: RealSet_t := get(datatype, last_bit_set(a));
		variable x: real;
		variable y: real;
		variable x_sign: boolean := true;
		variable y_sign: boolean := true;
		variable resulting_set: RealSet_t;
	begin
		-- VHDL Does not like the condition X < 0.0 and Y /= 0.0 in X**Y
		-- So we need to work around it
		x_sign := (not cmp_real(exponent mod 2.0, 0.0) and al.low_bound  < 0.0);
		y_sign := (not cmp_real(exponent mod 2.0, 0.0) and ah.high_bound < 0.0);
		x := (abs(al.low_bound))  ** exponent;
		y := (abs(ah.high_bound)) ** exponent;

		if x_sign then
			x := -x;
		end if;

		if y_sign then
			y := -y;
		end if;

		if y >= x then
			resulting_set.low_bound  := x;
			resulting_set.high_bound := y;
			resulting_set.low_bound_open  := al.low_bound_open;
			resulting_set.high_bound_open := ah.high_bound_open;
		else
			resulting_set.low_bound  := y;
			resulting_set.high_bound := x;
			resulting_set.low_bound_open  := ah.high_bound_open;
			resulting_set.high_bound_open := al.low_bound_open;
		end if;
		
		return map_set_to_bits(datatype, resulting_set);
	end function;

	function absolute(datatype: SignedSornDatatype_t; a: std_logic_vector) return std_logic_vector is
		variable al: RealSet_t := get(datatype, first_bit_set(a));
		variable ah: RealSet_t := get(datatype, last_bit_set(a));
		variable x: real;
		variable y: real;
		variable resulting_set: RealSet_t;
	begin
		x := abs(al.low_bound);
		y := abs(ah.high_bound);

		if y >= x then
			resulting_set.low_bound  := x;
			resulting_set.high_bound := y;
			resulting_set.low_bound_open  := al.low_bound_open;
			resulting_set.high_bound_open := ah.high_bound_open;
		else
			resulting_set.low_bound  := y;
			resulting_set.high_bound := x;
			resulting_set.low_bound_open  := ah.high_bound_open;
			resulting_set.high_bound_open := al.low_bound_open;
		end if;
		
		return map_set_to_bits(datatype, resulting_set);
	end function;

	function sin(datatype: SignedSornDatatype_t; a: std_logic_vector) return std_logic_vector is
		variable al: RealSet_t := get(datatype, first_bit_set(a));
		variable ah: RealSet_t := get(datatype, last_bit_set(a));
		variable x: real;
		variable y: real;
		variable resulting_set: RealSet_t;
	begin
		x := sin(al.low_bound);
		y := sin(ah.high_bound);

		if y >= x then
			resulting_set.low_bound  := x;
			resulting_set.high_bound := y;
			resulting_set.low_bound_open  := al.low_bound_open;
			resulting_set.high_bound_open := ah.high_bound_open;
		else
			resulting_set.low_bound  := y;
			resulting_set.high_bound := x;
			resulting_set.low_bound_open  := ah.high_bound_open;
			resulting_set.high_bound_open := al.low_bound_open;
		end if;
		
		return map_set_to_bits(datatype, resulting_set);
	end function;

	function cos(datatype: SignedSornDatatype_t; a: std_logic_vector) return std_logic_vector is
	variable al: RealSet_t := get(datatype, first_bit_set(a));
		variable ah: RealSet_t := get(datatype, last_bit_set(a));
		variable x: real;
		variable y: real;
		variable resulting_set: RealSet_t;
	begin
		x := cos(al.low_bound);
		y := cos(ah.high_bound);

		if y >= x then
			resulting_set.low_bound  := x;
			resulting_set.high_bound := y;
			resulting_set.low_bound_open  := al.low_bound_open;
			resulting_set.high_bound_open := ah.high_bound_open;
		else
			resulting_set.low_bound  := y;
			resulting_set.high_bound := x;
			resulting_set.low_bound_open  := ah.high_bound_open;
			resulting_set.high_bound_open := al.low_bound_open;
		end if;
		
		return map_set_to_bits(datatype, resulting_set);
	end function;

	function from_string(s: string) return SignedSornDatatype_t is
		variable datatype: SignedSornDatatype_t;
		variable cur_set: RealSet_t;
		variable cur_low_bound_str: line;
		variable cur_high_bound_str: line;
		variable at_low_bound: boolean := true;
		variable left_open: boolean := false;
		variable right_open: boolean := false;
	begin
		datatype.cur_size := 0;
		for i in s'range loop
			if (s(i) >= '0' and s(i) <= '9') or s(i) = '.' or s(i) = '-' or s(i) = 'i' or s(i) = 'n' or s(i) = 'f' then
				if at_low_bound then
					write(cur_low_bound_str, s(i));
				else
					write(cur_high_bound_str, s(i));
				end if;
			elsif s(i) = '(' then
				left_open := true;
			elsif s(i) = ',' then
				cur_high_bound_str := null;
				at_low_bound := false;
			elsif s(i) = ']' or s(i) = ')' then

				-- Check if high bound is open
				if s(i) = ')' then
					right_open := true;
				end if;

				-- Check if low bound is infinite
				if cur_low_bound_str.all = "inf" then
					cur_set.low_bound := REAL_INF;
				elsif cur_low_bound_str.all = "-inf" then
					cur_set.low_bound := -REAL_INF;
				else
					cur_set.low_bound := real'value(cur_low_bound_str.all);
				end if;

				-- Check if high bound is infinite
				if cur_high_bound_str.all = "inf" then
					cur_set.high_bound := REAL_INF;
				elsif cur_high_bound_str.all = "-inf" then
					cur_set.high_bound := -REAL_INF;
				else
					cur_set.high_bound := real'value(cur_high_bound_str.all);
				end if;

				cur_set.low_bound_open := left_open;
				cur_set.high_bound_open := right_open;

				append(datatype, cur_set);
				cur_low_bound_str := null;
				at_low_bound := true;
				left_open := false;
				right_open := false;
			end if;
		end loop;

		return datatype;
	end function;

end package body;