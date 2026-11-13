library ieee;
use ieee.fixed_pkg.all;

package AcceleratorPKG is
	subtype SornFixed_t is sfixed(3 downto -4); -- 16 / 0.0625

	type AcceleratorError_t is
	(
		ERR_NONE, -- No error
		ERR_DUMMY -- Just to test
	);
end package;

package body AcceleratorPKG is

end package body;