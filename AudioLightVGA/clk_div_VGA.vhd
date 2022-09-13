ENTITY clk_div_VGA IS
	GENERIC(N : natural := 1);
	PORT (clk_in , rst : IN BIT ;
					clk_out: OUT BIT);
END clk_div_VGA;

ARCHITECTURE behavioral OF clk_div_VGA IS
	SIGNAL divided_clk :BIT ;
	BEGIN
		PROCESS (clk_in , rst)
			VARIABLE count : INTEGER RANGE 0 to N;
		BEGIN
			IF (rst = '0') THEN
				count := 0;
			divided_clk <= '0';
			ELSIF(clk_in'EVENT AND clk_in ='1') THEN
				IF (count=N-1) THEN
					count := 0;
					divided_clk <= NOT divided_clk;
				ELSE
					count := count + 1;
				END IF;
			END IF;
		END PROCESS;
	clk_out <= divided_clk;
END behavioral;