library ieee;
library ieee_proposed;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee_proposed.fixed_float_types.all;
use ieee_proposed.fixed_pkg.all;

entity fir_filter is
	generic(m : natural := 4; -- Qm.n
			  n : natural := 4; -- Qm.n
			  L : natural := 4); -- number of coefficients
	port(clk : IN STD_LOGIC;
	     resetn : IN STD_LOGIC;
		  input  : IN std_logic_vector(m+n-1 downto 0);
		  output : OUT std_logic_vector(m+n-1 downto 0));
end fir_filter;

architecture fixed of fir_filter is
	TYPE delay_line IS ARRAY(0 TO L-1) OF SFIXED(m-1 downto -n);
	TYPE coeff_line IS ARRAY(0 TO L-1) OF SFIXED(m-1 downto -n);
	signal x : delay_line;
	signal y : sfixed(2*m+L-2 downto -(2*n));
	signal b : coeff_line;
	signal y_vec : std_logic_vector(2*m+L+2*n-2 downto 0);
begin
	b(0) <= to_sfixed(0.5, m-1, -n);
	b(1) <= to_sfixed(0.25, m-1, -n);
	b(2) <= to_sfixed(0.125, m-1, -n);
	b(3) <= to_sfixed(0.125, m-1, -n);
	x(0) <= to_sfixed(input, m-1, -n);
process(x, resetn, clk)
	begin
	if resetn='0' then
		output <= (others => '0');
		x(1) <= (others => '0');
		x(2) <= (others => '0');
		x(3) <= (others => '0');
	elsif(clk'event and clk='1') then
		y <= x(0)*b(0) + x(1)*b(1) + x(2)*b(2) + x(3)*b(3);
		x(3) <= x(2); -- update delay line
		x(2) <= x(1); -- update delay line
		x(1) <= x(0); -- update delay line
		y_vec <= to_stdlogicvector(y);
		output <= y_vec(m+2*n-1 downto n);
	end if;
end process;
end architecture;