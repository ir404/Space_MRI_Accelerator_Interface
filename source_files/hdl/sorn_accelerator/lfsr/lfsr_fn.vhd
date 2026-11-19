library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package lfsr_fn is
    -- Advances an LFSR by N cycles only widths 3–32 supported
    function LFSR_ADVANCE(last: std_ulogic_vector; N: integer) return std_ulogic_vector;
end package;

package body lfsr_fn is
    
    function taps_for_width(n: integer) return integer_vector is
    begin
        case n is
            when 3  => return (3,2);
            when 4  => return (4,3);
            when 5  => return (5,3);
            when 6  => return (6,5);
            when 7  => return (7,6);
            when 8  => return (8,6,5,4);
            when 9  => return (9,5);
            when 10 => return (10,7);
            when 11 => return (11,9);
            when 12 => return (12,6,4,1);
            when 13 => return (13,4,3,1);
            when 14 => return (14,5,3,1);
            when 15 => return (15,14);
            when 16 => return (16,15,13,4);
            when 17 => return (17,14);
            when 18 => return (18,11);
            when 19 => return (19,6,2,1);
            when 20 => return (20,17);
            when 21 => return (21,19);
            when 22 => return (22,21);
            when 23 => return (23,18);
            when 24 => return (24,23,22,17);
            when 25 => return (25,22);
            when 26 => return (26,6,2,1);
            when 27 => return (27,5,2,1);
            when 28 => return (28,25);
            when 29 => return (29,27);
            when 30 => return (30,6,4,1);
            when 31 => return (31,28);
            when 32 => return (32,22,2,1);
            when others =>
                report "Unsupported LFSR width: " & integer'image(n) severity error;
                return (0, 0, 0); -- dummy
        end case;
    end function;

    function LFSR_NEXT(last: std_ulogic_vector; taps: integer_vector) return std_ulogic_vector is
        variable fb      : std_ulogic := '1';
        variable new_val : std_ulogic_vector(last'range);
    begin
        for i in taps'range loop
            fb := fb xnor last(taps(i));
        end loop;

        new_val := last(last'left-1 downto last'right) & fb;
        return new_val;
    end function;

    function LFSR_ADVANCE(last: std_ulogic_vector; N: integer) return std_ulogic_vector is
        variable new_val : std_ulogic_vector(last'range) := last;
    begin
        for i in 1 to N loop
            new_val := LFSR_NEXT(new_val, taps_for_width(last'length));
        end loop;
        return new_val;
    end function;

end package body;
