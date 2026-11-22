library work;
use work.SornUtil.all;
use work.SornDatatype.all;

package SornGlobal is
    function init_sorn_datatype return SornDatatype_t;
    constant datatype : SornDatatype_t := init_sorn_datatype;
end package;

package body SornGlobal is
    function init_sorn_datatype return SornDatatype_t is
        variable dt : SornDatatype_t;
    begin
        dt.cur_size := 0;

        -- 23 SORN intervals matching the original specification
        append(dt, (low_bound => -REAL_INF, high_bound => -1.0,     low_bound_open => false, high_bound_open => true));
        append(dt, (low_bound => -1.0,      high_bound => -0.85381, low_bound_open => false, high_bound_open => true));
        append(dt, (low_bound => -0.85381,  high_bound => -0.71554, low_bound_open => false, high_bound_open => true));
        append(dt, (low_bound => -0.71554,  high_bound => -0.58566, low_bound_open => false, high_bound_open => true));
        append(dt, (low_bound => -0.58566,  high_bound => -0.46476, low_bound_open => false, high_bound_open => true));
        append(dt, (low_bound => -0.46476,  high_bound => -0.35355, low_bound_open => false, high_bound_open => true));
        append(dt, (low_bound => -0.35355,  high_bound => -0.25298, low_bound_open => false, high_bound_open => true));
        append(dt, (low_bound => -0.25298,  high_bound => -0.16432, low_bound_open => false, high_bound_open => true));
        append(dt, (low_bound => -0.16432,  high_bound => -0.08944, low_bound_open => false, high_bound_open => true));
        append(dt, (low_bound => -0.08944,  high_bound => -0.03162, low_bound_open => false, high_bound_open => true));
        append(dt, (low_bound => -0.03162,  high_bound =>  0.0,     low_bound_open => false, high_bound_open => true));
        append(dt, (low_bound =>  0.0,      high_bound =>  0.0,     low_bound_open => false, high_bound_open => false));
        append(dt, (low_bound =>  0.0,      high_bound =>  0.03162, low_bound_open => true,  high_bound_open => false));
        append(dt, (low_bound =>  0.03162,  high_bound =>  0.08944, low_bound_open => true,  high_bound_open => false));
        append(dt, (low_bound =>  0.08944,  high_bound =>  0.16432, low_bound_open => true,  high_bound_open => false));
        append(dt, (low_bound =>  0.16432,  high_bound =>  0.25298, low_bound_open => true,  high_bound_open => false));
        append(dt, (low_bound =>  0.25298,  high_bound =>  0.35355, low_bound_open => true,  high_bound_open => false));
        append(dt, (low_bound =>  0.35355,  high_bound =>  0.46476, low_bound_open => true,  high_bound_open => false));
        append(dt, (low_bound =>  0.46476,  high_bound =>  0.58566, low_bound_open => true,  high_bound_open => false));
        append(dt, (low_bound =>  0.58566,  high_bound =>  0.71554, low_bound_open => true,  high_bound_open => false));
        append(dt, (low_bound =>  0.71554,  high_bound =>  0.85381, low_bound_open => true,  high_bound_open => false));
        append(dt, (low_bound =>  0.85381,  high_bound =>  1.0,     low_bound_open => true,  high_bound_open => false));
        append(dt, (low_bound =>  1.0,      high_bound =>  REAL_INF,low_bound_open => true,  high_bound_open => false));

        return dt;
    end function;
end package body;