library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_textio.all;
use IEEE.math_real.all;
use IEEE.math_complex.all;

library std;
use std.textio.all;

package SornUtil is
	-- Math real package has no infinite so we cheat a little
	constant REAL_INF : real := 1.0E29;

	function last_bit_set(a: std_logic_vector) return integer;
	function first_bit_set(a: std_logic_vector) return integer;
	function middle_bit_set(a: std_logic_vector) return integer;
	function cmp_real(a: real; b: real) return boolean;
	function next_pow2(number: integer) return integer;
	function num_bits_set(a: std_logic_vector) return integer;
	function smallest(a: integer; b: integer) return integer;
	function largest(a: integer; b: integer) return integer;
	function atan2(y: real; x: real) return real;
end package;

package body SornUtil is
	function atan2(y: real; x: real) return real is
	begin
	if x > 0.0 then
		return arctan(y/x);
	elsif x < 0.0 and y >= 0.0 then
		return arctan(y/x) + math_pi;
	elsif x < 0.0 and y < 0.0 then
		return arctan(y/x) - math_pi;
	elsif x = 0.0 and y > 0.0 then
		return math_pi/2.0;
	elsif x = 0.0 and y < 0.0 then
		return -math_pi/2.0;
	else
		return 0.0; -- Nicht definiert https://en.wikipedia.org/wiki/Atan2#Definition_and_computation
	end if;
	end;

	function last_bit_set(a: std_logic_vector) return integer is
	begin
		for i in a'range loop
			if a(i) = '1' then
				return i;
			end if;
		end loop;

		return 0;
	end function;

	function first_bit_set(a: std_logic_vector) return integer is
	begin
		for i in a'reverse_range loop
			if a(i) = '1' then
				return i;
			end if;
		end loop;

		return 0;
	end function;

	function middle_bit_set(a: std_logic_vector) return integer is
	begin
		return (first_bit_set(a) + last_bit_set(a)) / 2;
	end function;

	function cmp_real(a: real; b: real) return boolean is
		constant TOLERANCE: real := 0.0005;
	begin
		if a > b-TOLERANCE and a < b+TOLERANCE then
			return true;
		end if;

		return false;
	end function;

	function next_pow2(number: integer) return integer is
		variable power: integer := 1;
	begin
		while power < number loop
			power := power*2;
		end loop;

		return power;
	end function;

	function num_bits_set(a: std_logic_vector) return integer is
		variable n: integer range 0 to a'length-1 := 0;
	begin
		for i in a'range loop
			if a(i) = '1' then
				n := n + 1;
			end if;
		end loop;

		return n;
	end function;

	function smallest(a: integer; b: integer) return integer is
	begin
		if a <= b then
			return a;
		else
			return b;
		end if;
	end function;

	function largest(a: integer; b: integer) return integer is
	begin
		if a >= b then
			return a;
		else
			return b;
		end if;
	end function;
	
end package body;