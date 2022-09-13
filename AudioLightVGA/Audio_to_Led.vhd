library ieee;
library ieee_proposed;
use ieee.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use ieee_proposed.fixed_float_types.all;
use ieee_proposed.fixed_pkg.all;

entity Audio_to_Led is
	generic(len_in		  : integer := 16;
			  len_out	  : integer := 8
			 );
		port(clk 	  : IN  std_logic;
			  rst		  : IN  std_logic;
			  SW4 	  : IN std_logic;
		
			  left_in  : IN std_logic_vector(15 downto 0);--ja nein vllt?
			  right_in : IN std_logic_vector(15 downto 0);
			  
			  output   : OUT std_logic_vector(7 downto 0)
			  );
end Audio_to_Led;

architecture behavioral of Audio_to_Led is
signal reg : std_logic_vector(7 downto 0);
BEGIN
	PROCESS(clk,rst)
		variable counter : integer;
		variable reg1	  : std_logic_vector(7 downto 0);
		variable reg2	  : std_logic_vector(7 downto 0);
		variable sum	  : std_logic_vector(7 downto 0);
		BEGIN
			IF(rst='0' OR SW4 = '0') THEN
				--reg  <= (others=>'0');
				output <= (others=>'0');
			ELSIF(clk'EVENT AND clk='1') THEN
				 IF(SW4 = '1') then
					for i in 0 to (len_out-1) loop
						reg1(i) := left_in(i*2);		--reg1 := left_in(0)+left_in(2)+left_in(4)+left_in(6)+left_in(8)+left_in(10)+left_in(12)+left_in(14);
						reg2(i) := left_in((i*2)+1);	--reg2 := left_in(1)+left_in(3)+left_in(5)+left_in(6)+left_in(8)+left_in(10)+left_in(12)+left_in(14);	
					end loop;
					--reg <= left_in(11 downto 4);
					for i in 0 to (len_out-1) loop
						sum(i) := reg1(i) XOR reg2(i);
					end loop;
					output <= sum;
				END IF; 
		  END IF;	
	END PROCESS;
--output <= reg;
END behavioral;
