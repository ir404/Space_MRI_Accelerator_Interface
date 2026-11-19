library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.numeric_std.all;

library work;
use work.SornUtil.all;
use work.Sorn.all;
use work.SornOperators.all;
use work.global_pkg.all;

entity sorn_core is
port
(
	clk: in std_ulogic;
	rst: in std_ulogic;

	input_valid: in std_ulogic;

	s: in SornArr_t(5 downto 0); 	-- Sine Values
	c: in SornArr_t(5 downto 0); 	-- Cosine Values

	target: in SornArr_t(2 downto 0); -- Target X, Y, Z

	/* Result */
	squared_norm: out Sorn_t;
	ls: out SornArr_t(5 downto 0); 	-- Last Sine Values which produced the current result
	lc: out SornArr_t(5 downto 0); 	-- Last Cosine Values which produced the current result
	output_valid: out std_ulogic;

	/* Debug */
	error_xx: out Sorn_t;
	error_yy: out Sorn_t;
	error_zz: out Sorn_t;

	fk_x: out Sorn_t;
	fk_y: out Sorn_t;
	fk_z: out Sorn_t
);
end entity sorn_core;



architecture comb of sorn_core is
	signal x0:  Sorn_t;
    signal x1:  Sorn_t;
    signal x2:  Sorn_t;
    signal x3:  Sorn_t;
    signal x4:  Sorn_t;
    signal x5:  Sorn_t;
    signal x6:  Sorn_t;
    signal x7:  Sorn_t;
    signal x8:  Sorn_t;
    signal x9:  Sorn_t;
    signal x10: Sorn_t;
    signal x11: Sorn_t;

	-- Intermediate values
    signal x12: Sorn_t;
    signal x13: Sorn_t;
    signal x14: Sorn_t;
    signal x15: Sorn_t;
    signal x16: Sorn_t;
    signal x17: Sorn_t;
    signal x18: Sorn_t;
    signal x19: Sorn_t;
    signal x20: Sorn_t;
    signal x21: Sorn_t;
    signal x22: Sorn_t;
    signal x23: Sorn_t;
    signal x24: Sorn_t;
    signal x25: Sorn_t;
    signal x26: Sorn_t;
    signal x27: Sorn_t;
    signal x28: Sorn_t;
    signal x29: Sorn_t;
    signal x30: Sorn_t;
    signal x31: Sorn_t;
    signal x32: Sorn_t;
    signal x33: Sorn_t;
    signal x34: Sorn_t;
    signal x35: Sorn_t;
    signal x36: Sorn_t;
    signal x37: Sorn_t;
    signal x38: Sorn_t;
    signal x39: Sorn_t;
    signal x40: Sorn_t;
    signal x41: Sorn_t;
    signal x42: Sorn_t;
    signal x43: Sorn_t;
    signal x44: Sorn_t;
    signal x45: Sorn_t;
    signal x46: Sorn_t;
    signal x47: Sorn_t;
    signal x48: Sorn_t;
    signal x49: Sorn_t;
	signal x50: Sorn_t;

    signal part1:  Sorn_t;
    signal part2:  Sorn_t;
    signal part3:  Sorn_t;
    signal part4:  Sorn_t;
    signal part5:  Sorn_t;
    signal part6:  Sorn_t;
    signal part7:  Sorn_t;
    signal part8:  Sorn_t;
    signal fk_x_r: Sorn_t;

    signal p1_1:   Sorn_t;
    signal p1_2:   Sorn_t;
    signal p1_3:   Sorn_t;
    signal p1_4:   Sorn_t;
    signal p1_5:   Sorn_t;
    signal p1_6:   Sorn_t;
    signal p1_7:   Sorn_t;
    signal p1_8:   Sorn_t;
    signal fk_y_r: Sorn_t;

    signal p2_1:   Sorn_t;
    signal p2_2:   Sorn_t;
    signal p2_3:   Sorn_t;
    signal p2_4:   Sorn_t;
    signal p2_5:   Sorn_t;
    signal p2_6:   Sorn_t;
    signal p2_7:   Sorn_t;
    signal p2_8:   Sorn_t;
    signal p2_9:   Sorn_t;
    signal fk_z_r: Sorn_t;

	-- Rotation Matrix
    signal eerot0: Sorn_t;
    signal eerot1: Sorn_t;
    signal eerot2: Sorn_t;
    signal eerot3: Sorn_t;
    signal eerot4: Sorn_t;
    signal eerot5: Sorn_t;
    signal eerot6: Sorn_t;
    signal inner7: Sorn_t;
    signal eerot7: Sorn_t;
    signal eerot8: Sorn_t;

	/* Error calculation */
	signal error_x, error_y, error_z : Sorn_t;
begin

	output_valid <= input_valid;

	x0  <= c(1);
	x1  <= s(2);
	x2  <= s(3);
	x3  <= c(3);
	x4  <= s(1);
	x5  <= s(5);
	x6  <= c(4);
	x7  <= c(2);
	x8  <= s(4);
	x9  <= c(5);
	x10 <= s(0);
	x11 <= c(0);

	x12 <= (real_to_sorn(1.0) * x2);
	x13 <= (real_to_sorn(1.0) * x6);
	x14 <= (real_to_sorn(0.2992) * x0);
	x15 <= (real_to_sorn(1.0) * x1);
	x16 <= (real_to_sorn(0.14) * x3);
	x17 <= (real_to_sorn(0.254) * x1);
	x18 <= (x0 * x3);
	x19 <= (x10 * x7);
	x20 <= (real_to_sorn(-0.02) * x6);
	x21 <= (x1 * x11);
	x22 <= (x11 * x7);
	x23 <= (real_to_sorn(-1.0) * x2);
	x24 <= (x2 * x4);
	x25 <= (real_to_sorn(-0.14) * x6);
	x26 <= (x10 * x4);
	x27 <= (x0 * x11 * x2);
	x28 <= (x0 * x7 * x8);
	x29 <= (x0 * x10 * x2);
	x30 <= (real_to_sorn(1.0) * x10 * x18);
	x31 <= (real_to_sorn(1.0) * x11 * x18);
	x32 <= ((real_to_sorn(-1.0) * x15 * x26) + x22);
	x33 <= ((x19 * x4) + x21);
	x34 <= ((x22 * x4) + (real_to_sorn(-1.0) * x10 * x15));
	x35 <= ((x0 * x1 * x12) + (real_to_sorn(-1.0) * x3 * x4));
	x36 <= ((x12 * x4) + (x15 * x18));
	x37 <= ((real_to_sorn(-1.0) * x19) + (real_to_sorn(-1.0) * x11 * x15 * x4));
	x38 <= (x33 * x8);
	x39 <= (x2 * x32);
	x40 <= (x34 * x8);
	x41 <= (x3 * x32);
	x42 <= (x35 * x6);
	x43 <= (x3 * x37);
	x44 <= (x41 + x29);
	x45 <= ((real_to_sorn(-1.0) * x12 * x32) + x30);
	x46 <= ((x23 * x32) + x30);
	x47 <= (x43 + x27);
	x48 <= ((x23 * x37) + x31);
	x49 <= (x48 * x6);
	x50 <= real_to_sorn(1.0) * x11;

	part1 <= real_to_sorn(0.149);
	part2 <= x9 * ((real_to_sorn(0.14) * x24) + (x0 * x1 * x16));
	part3 <= x9 * ((real_to_sorn(0.02) * x42) + (real_to_sorn(0.02) * x28));
	part4 <= real_to_sorn(-0.2992) * x4;
	part5 <= x17 * x18;
	part6 <= real_to_sorn(0.254) * x24;
	part7 <= x5 * ((real_to_sorn(0.14) * x28) + (real_to_sorn(0.14) * x42));
	part8 <= x5 * ((real_to_sorn(-0.02) * x1 * x18) + (real_to_sorn(-0.02) * x24));
	fk_x_r <= part1 + part2 + part3 + part4 + part5 + part6 + part7 + part8;

	p1_1 <= x3 * ((real_to_sorn(-1.0) * x17 * x26) + (real_to_sorn(0.254) * x22));
	p1_2 <= x5 * ((real_to_sorn(-0.14) * x38) + (x25 * x46));
	p1_3 <= real_to_sorn(0.033) * x11;
	p1_4 <= x5 * ((real_to_sorn(-0.02) * x41) + (real_to_sorn(-0.02) * x29));
	p1_5 <= x9 * ((x16 * x32) + (real_to_sorn(0.14) * x29));
	p1_6 <= real_to_sorn(-1.0) * x10 * x14;
	p1_7 <= real_to_sorn(0.254) * x29;
	p1_8 <= x9 * ((x20 * x46) + (real_to_sorn(-0.02) * x38));
	fk_y_r <= p1_1 + p1_2 + p1_3 + p1_4 + p1_5 + p1_6 + p1_7 + p1_8;

	p2_1 <= real_to_sorn(0.5712);
	p2_2 <= x9 * ((x20 * x48) + (real_to_sorn(-0.02) * x40));
	p2_3 <= real_to_sorn(-1.0) * x14 * x50;
	p2_4 <= x5 * ((real_to_sorn(-0.14) * x40) + (x25 * x48));
	p2_5 <= x3 * ((real_to_sorn(-1.0) * x17 * x4 * x50) + (real_to_sorn(-0.254) * x19));
	p2_6 <= real_to_sorn(0.254) * x27;
	p2_7 <= x9 * ((x16 * x37) + (real_to_sorn(0.14) * x27));
	p2_8 <= x5 * ((real_to_sorn(-0.02) * x43) + (real_to_sorn(-0.02) * x27));
	p2_9 <= real_to_sorn(-0.033) * x10;
	fk_z_r <= p2_1 + p2_2 + p2_3 + p2_4 + p2_5 + p2_6 + p2_7 + p2_8 + p2_9;

	--eerot0 <= (x36 * x5) + (x9 * ((real_to_sorn(-1.0) * x28) + (real_to_sorn(-1.0) * x13 * x35)));
	--eerot1 <= (x5 * (x42 + x28)) + (x36 * x9);
	--eerot2 <= (x35 * x8) + (real_to_sorn(-1.0) * x0 * x13 * x7);
	--eerot3 <= (x9 * (x38 + (x45 * x6))) + (x44 * x5);
	--eerot4 <= (x44 * x9) + (x5 * ((real_to_sorn(-1.0) * x38) + (real_to_sorn(-1.0) * x13 * x45)));
	--eerot5 <= (x8 * ((real_to_sorn(-1.0) * x30) + x39)) + (x33 * x6);
	--eerot6 <= (x9 * (x49 + x40)) + (x47 * x5);
	--inner7 <= (x13 * ((real_to_sorn(-1.0) * x12 * x37) + x31)) + x40;
	--eerot7 <= (x47 * x9) + (real_to_sorn(-1.0) * x5 * inner7);
	--eerot8 <= (x8 * ((real_to_sorn(-1.0) * x31) + (x2 * x37))) + (x34 * x6);

	error_x <= fk_x_r - target(X);
	error_y <= fk_y_r - target(Y);
	error_z <= fk_z_r - target(Z);

	/* ------------------------- Stage 9 ------------------------- */
	squared_norm <= pow2(error_x) + pow2(error_y) + pow2(error_z);

	ls <= s;
	lc <= c;

	fk_x <= fk_x_r;
	fk_y <= fk_y_r;
	fk_z <= fk_z_r;

	error_xx <= error_x;
	error_yy <= error_y;
	error_zz <= error_z;

end architecture;

architecture comb2 of sorn_core is
	signal x0:  Sorn_t;
    signal x1:  Sorn_t;
    signal x2:  Sorn_t;
    signal x3:  Sorn_t;
    signal x4:  Sorn_t;
    signal x5:  Sorn_t;
    signal x6:  Sorn_t;
    signal x7:  Sorn_t;
    signal x8:  Sorn_t;
    signal x9:  Sorn_t;
    signal x10: Sorn_t;
    signal x11: Sorn_t;

	-- Intermediate values
    signal x12: Sorn_t;
    signal x13: Sorn_t;
    signal x14: Sorn_t;
    signal x15: Sorn_t;
    signal x16: Sorn_t;
    signal x17: Sorn_t;
    signal x18: Sorn_t;
    signal x19: Sorn_t;
    signal x20: Sorn_t;
    signal x21: Sorn_t;
    signal x22: Sorn_t;
    signal x23: Sorn_t;
    signal x24: Sorn_t;
    signal x25: Sorn_t;
    signal x26: Sorn_t;
    signal x27: Sorn_t;
    signal x28: Sorn_t;
    signal x29: Sorn_t;
    signal x30: Sorn_t;
    signal x31: Sorn_t;
    signal x32: Sorn_t;
    signal x33: Sorn_t;
    signal x34: Sorn_t;
    signal x35: Sorn_t;
    signal x36: Sorn_t;
    signal x37: Sorn_t;
    signal x38: Sorn_t;
    signal x39: Sorn_t;
    signal x40: Sorn_t;
    signal x41: Sorn_t;
    signal x42: Sorn_t;
    signal x43: Sorn_t;
    signal x44: Sorn_t;
    signal x45: Sorn_t;
    signal x46: Sorn_t;
    signal x47: Sorn_t;
    signal x48: Sorn_t;
    signal x49: Sorn_t;
	signal x50: Sorn_t;

    signal part1:  Sorn_t;
    signal part2:  Sorn_t;
    signal part3:  Sorn_t;
    signal part4:  Sorn_t;
    signal part5:  Sorn_t;
    signal part6:  Sorn_t;
    signal part7:  Sorn_t;
    signal part8:  Sorn_t;
    signal fk_x_r: Sorn_t;

    signal p1_1:   Sorn_t;
    signal p1_2:   Sorn_t;
    signal p1_3:   Sorn_t;
    signal p1_4:   Sorn_t;
    signal p1_5:   Sorn_t;
    signal p1_6:   Sorn_t;
    signal p1_7:   Sorn_t;
    signal p1_8:   Sorn_t;
    signal fk_y_r: Sorn_t;

    signal p2_1:   Sorn_t;
    signal p2_2:   Sorn_t;
    signal p2_3:   Sorn_t;
    signal p2_4:   Sorn_t;
    signal p2_5:   Sorn_t;
    signal p2_6:   Sorn_t;
    signal p2_7:   Sorn_t;
    signal p2_8:   Sorn_t;
    signal p2_9:   Sorn_t;
    signal fk_z_r: Sorn_t;

	-- Rotation Matrix
    signal eerot0: Sorn_t;
    signal eerot1: Sorn_t;
    signal eerot2: Sorn_t;
    signal eerot3: Sorn_t;
    signal eerot4: Sorn_t;
    signal eerot5: Sorn_t;
    signal eerot6: Sorn_t;
    signal inner7: Sorn_t;
    signal eerot7: Sorn_t;
    signal eerot8: Sorn_t;

	/* Error calculation */
	signal error_x, error_y, error_z : Sorn_t;
begin

	output_valid <= input_valid;

	x0  <= c(1);
	x1  <= s(2);
	x2  <= s(3);
	x3  <= c(3);
	x4  <= s(1);
	x5  <= s(5);
	x6  <= c(4);
	x7  <= c(2);
	x8  <= s(4);
	x9  <= c(5);
	x10 <= s(0);
	x11 <= c(0);

	x12 <= (x2);
	x13 <= (x6);
	x14 <= (real_to_sorn(0.2992) * x0);
	x15 <= (x1);
	x16 <= (real_to_sorn(0.14) * x3);
	x17 <= (real_to_sorn(0.254) * x1);
	x18 <= (x0 * x3);
	x19 <= (x10 * x7);
	x20 <= (real_to_sorn(-0.02) * x6);
	x21 <= (x1 * x11);
	x22 <= (x11 * x7);
	x23 <= (real_to_sorn(-1.0) * x2);
	x24 <= (x2 * x4);
	x25 <= (real_to_sorn(-0.14) * x6);
	x26 <= (x10 * x4);
	x27 <= (x0 * x11 * x2);
	x28 <= (x0 * x7 * x8);
	x29 <= (x0 * x10 * x2);
	x30 <= (x10 * x18);
	x31 <= (x11 * x18);
	x32 <= ((real_to_sorn(-1.0) * x15 * x26) + x22);
	x33 <= ((x19 * x4) + x21);
	x34 <= ((x22 * x4) + (real_to_sorn(-1.0) * x10 * x15));
	x35 <= ((x0 * x1 * x12) + (real_to_sorn(-1.0) * x3 * x4));
	x36 <= ((x12 * x4) + (x15 * x18));
	x37 <= ((real_to_sorn(-1.0) * x19) + (real_to_sorn(-1.0) * x11 * x15 * x4));
	x38 <= (x33 * x8);
	x39 <= (x2 * x32);
	x40 <= (x34 * x8);
	x41 <= (x3 * x32);
	x42 <= (x35 * x6);
	x43 <= (x3 * x37);
	x44 <= (x41 + x29);
	x45 <= ((real_to_sorn(-1.0) * x12 * x32) + x30);
	x46 <= ((x23 * x32) + x30);
	x47 <= (x43 + x27);
	x48 <= ((x23 * x37) + x31);
	x49 <= (x48 * x6);
	x50 <= x11;

	part1 <= real_to_sorn(0.149);
	part2 <= x9 * ((real_to_sorn(0.14) * x24) + (x0 * x1 * x16));
	part3 <= x9 * ((real_to_sorn(0.02) * x42) + (real_to_sorn(0.02) * x28));
	part4 <= real_to_sorn(-0.2992) * x4;
	part5 <= x17 * x18;
	part6 <= real_to_sorn(0.254) * x24;
	part7 <= x5 * ((real_to_sorn(0.14) * x28) + (real_to_sorn(0.14) * x42));
	part8 <= x5 * ((real_to_sorn(-0.02) * x1 * x18) + (real_to_sorn(-0.02) * x24));
	fk_x_r <= part1 + part2 + part3 + part4 + part5 + part6 + part7 + part8;

	p1_1 <= x3 * ((real_to_sorn(-1.0) * x17 * x26) + (real_to_sorn(0.254) * x22));
	p1_2 <= x5 * ((real_to_sorn(-0.14) * x38) + (x25 * x46));
	p1_3 <= real_to_sorn(0.033) * x11;
	p1_4 <= x5 * ((real_to_sorn(-0.02) * x41) + (real_to_sorn(-0.02) * x29));
	p1_5 <= x9 * ((x16 * x32) + (real_to_sorn(0.14) * x29));
	p1_6 <= real_to_sorn(-1.0) * x10 * x14;
	p1_7 <= real_to_sorn(0.254) * x29;
	p1_8 <= x9 * ((x20 * x46) + (real_to_sorn(-0.02) * x38));
	fk_y_r <= p1_1 + p1_2 + p1_3 + p1_4 + p1_5 + p1_6 + p1_7 + p1_8;

	p2_1 <= real_to_sorn(0.5712);
	p2_2 <= x9 * ((x20 * x48) + (real_to_sorn(-0.02) * x40));
	p2_3 <= real_to_sorn(-1.0) * x14 * x50;
	p2_4 <= x5 * ((real_to_sorn(-0.14) * x40) + (x25 * x48));
	p2_5 <= x3 * ((real_to_sorn(-1.0) * x17 * x4 * x50) + (real_to_sorn(-0.254) * x19));
	p2_6 <= real_to_sorn(0.254) * x27;
	p2_7 <= x9 * ((x16 * x37) + (real_to_sorn(0.14) * x27));
	p2_8 <= x5 * ((real_to_sorn(-0.02) * x43) + (real_to_sorn(-0.02) * x27));
	p2_9 <= real_to_sorn(-0.033) * x10;
	fk_z_r <= p2_1 + p2_2 + p2_3 + p2_4 + p2_5 + p2_6 + p2_7 + p2_8 + p2_9;

	--eerot0 <= (x36 * x5) + (x9 * ((real_to_sorn(-1.0) * x28) + (real_to_sorn(-1.0) * x13 * x35)));
	--eerot1 <= (x5 * (x42 + x28)) + (x36 * x9);
	--eerot2 <= (x35 * x8) + (real_to_sorn(-1.0) * x0 * x13 * x7);
	--eerot3 <= (x9 * (x38 + (x45 * x6))) + (x44 * x5);
	--eerot4 <= (x44 * x9) + (x5 * ((real_to_sorn(-1.0) * x38) + (real_to_sorn(-1.0) * x13 * x45)));
	--eerot5 <= (x8 * ((real_to_sorn(-1.0) * x30) + x39)) + (x33 * x6);
	--eerot6 <= (x9 * (x49 + x40)) + (x47 * x5);
	--inner7 <= (x13 * ((real_to_sorn(-1.0) * x12 * x37) + x31)) + x40;
	--eerot7 <= (x47 * x9) + (real_to_sorn(-1.0) * x5 * inner7);
	--eerot8 <= (x8 * ((real_to_sorn(-1.0) * x31) + (x2 * x37))) + (x34 * x6);

	error_x <= fk_x_r - target(X);
	error_y <= fk_y_r - target(Y);
	error_z <= fk_z_r - target(Z);

	/* ------------------------- Stage 9 ------------------------- */
	squared_norm <= pow2(error_x) + pow2(error_y) + pow2(error_z);

	ls <= s;
	lc <= c;

	fk_x <= fk_x_r;
	fk_y <= fk_y_r;
	fk_z <= fk_z_r;

	error_xx <= error_x;
	error_yy <= error_y;
	error_zz <= error_z;

end architecture;