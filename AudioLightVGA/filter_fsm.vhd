-- add necessary libraries and packages
library ieee;
library ieee_proposed;

use ieee.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use ieee_proposed.fixed_float_types.all;
use ieee_proposed.fixed_pkg.all;

entity filter_fsm is
	generic (m: natural := 4;
				n: natural := 12);
	port(-- input
		  rst 		 : IN  std_logic;
		  clk 		 : IN  std_logic;
		  SW0	 		 : IN  std_logic; -- enhancement on/off
		  left_right : IN  std_logic;
		  codec_idle : IN  std_logic;
		  left_in 	 : IN  std_logic_vector(15 downto 0); 
		  right_in 	 : IN  std_logic_vector(15 downto 0);
		  -- input filter typ select 
		  SW1			 : IN  std_logic; -- treble
		  SW2			 : IN  std_logic; -- bass
		  SW3			 : IN  std_logic; -- moving average filter
		  -- output data&reg
		  codec_start: OUT std_logic;
		  reg_addr	 : OUT std_logic_vector(6  downto 0);
		  reg_data	 : OUT std_logic_vector(8  downto 0);
		  left_out	 : OUT std_logic_vector(15 downto 0);
		  right_out  : OUT std_logic_vector(15 downto 0);
		  -- output led for selected filter 
		  data_led_red : OUT std_logic_vector(9 downto 0)		  
		  );
end filter_fsm;

architecture behavioral of filter_fsm is
	type TState is (idle,config0,wait0,wait1,config1,filter_select,filter0,filter1,filter2);
	signal state 		  : TState;
	signal left_right_1 : std_logic;
	constant ROM_SIZE   : natural := 9;
	type memory is array (NATURAL range 0 to ROM_SIZE-1) of std_logic_vector(15 downto 0);
	constant config_rom : memory := ("0001111000000000", 
												"0000111000000010", 
												"0000101000010001", 
												"0001000000100011", 
												"0001001000000001", 
												"0000100000010000", 
												"0000110000000000", 
												"0000000000011000", 
												"0000001000011000");
												
	------------------------------high-pass filter coeff----------------											
	TYPE delay_line IS ARRAY(0 TO 2) OF SFIXED(m-1 downto -n);
	TYPE coeff_line IS ARRAY(0 TO 2) OF SFIXED(m-1 downto -n);
	constant a_treble : coeff_line := ( TO_SFIXED( 1.000000000000000 , m-1, -n), 
													TO_SFIXED(-1.601092394183619 , m-1, -n),
													TO_SFIXED( 0.668368994611848 , m-1, -n)
												 );
	constant b_treble: coeff_line := ( TO_SFIXED( 3.269461388795467 , m-1, -n), 
												  TO_SFIXED(-6.538922777590933 , m-1, -n),
												  TO_SFIXED( 3.269461388795467 , m-1, -n)
												 );
	
	----------IIR--------------------low-pass  filter coeff---bass enhancement---										  
	constant a_bass : coeff_line := (TO_SFIXED( 1.000000000000000 , m-1, -n), 
												TO_SFIXED(-1.799096409484668 , m-1, -n),
												TO_SFIXED( 0.817512403384758 , m-1, -n)
												);
	constant b_bass : coeff_line := (TO_SFIXED( 0.018415993900090 , m-1, -n), 
												TO_SFIXED( 0.036831987800180 , m-1, -n),
												TO_SFIXED( 0.018415993900090 , m-1, -n)
												);									  							  
	-----------FIR-------------------moving average filter coeff------		
	constant b_move : coeff_line := (TO_SFIXED( 0.5   , m-1, -n), 
										      TO_SFIXED( 0.25  , m-1, -n),
										      TO_SFIXED( 0.125 , m-1, -n)
										      );									  
										  
										  
	signal z_left, z_right : SFIXED(m downto -n);			   
	signal left_out_int    : std_logic_vector(m+n downto 0);
	signal right_out_int   : std_logic_vector(m+n downto 0); 
	
   signal data_reg_states : std_logic_vector(3 downto 0);
	
BEGIN
	PROCESS(clk, rst)
			variable rom_ptr  : natural range 0 to ROM_SIZE;
			variable data_reg : std_logic_vector(15 downto 0);
			
			variable x_left, x_right : delay_line;             
			variable y_left, y_right : delay_line;              
			variable acc_left : SFIXED(2*m-1+4 downto -(2*n)); 
			variable acc_right: SFIXED(2*m-1+4 downto -(2*n)); 
		BEGIN
		IF(rst='0') THEN
			state 		 <= idle;
			left_right_1 <= '0';
			data_reg 	 := config_rom(0);
			rom_ptr 		 := 0;
			reg_addr 	 <= (others => '0');
			reg_data 	 <= (others => '0');
			codec_start  <= '0';
			data_reg_states <= (others=>'0'); --  Schaaltung auf ruecksetzeten 
		ELSIF(clk'EVENT AND clk='1') THEN
			CASE State IS
				---------------------------------------------------------------------
				WHEN idle =>

					data_reg_states <= "1111"; -- Schaltung im state "idle"
					
					if (SW0='1') then
						state <= config0;
					else
						state <= idle;
					end if;
				---------------------------------------------------------------------	
				WHEN config0 =>				-- read codec configuration info from ROM
					data_reg    := config_rom(rom_ptr);
					reg_addr    <= data_reg(15 downto 9);
					reg_data    <= data_reg(8 downto 0);
					codec_start <= '1';
					state       <= wait0;
				---------------------------------------------------------------------
				WHEN wait0 =>			 	 -- wait until i2c_codec starts transmission
					if(codec_idle='1') then
						state <= wait0;
					else
						state <= wait1;
					end if;
				---------------------------------------------------------------------	
				WHEN wait1 => 				-- wait for i2c_codec to finish transmission
					if(codec_idle='0') then
						state <= wait1;
						codec_start <= '0';
					else
						state <= config1;
					end if;
				---------------------------------------------------------------------
				WHEN config1 => 						-- check if ROM has been fully read
					rom_ptr := rom_ptr + 1; 
					if rom_ptr = ROM_SIZE then
						state <= filter_select;
					else
						state <= config0;
					end if;
				---------------------------------------------------------------------
				WHEN filter_select =>
				
					data_reg_states <= "0001";   --Schaltung im state "filter select"
									
				
					if	  (SW1 = '1' AND SW2 = '0' AND SW3 = '0')then
						state <= filter0;
					elsif(SW1 = '0' AND SW2 = '1' AND SW3 = '0')then
						state <= filter1;
					elsif(SW1 = '0' AND SW2 = '0' AND SW3 = '1')then
						state <= filter2;
					else
						state <= filter_select;
					end if;
				---------------------------------------------------------------------
				WHEN filter0 =>	

					data_reg_states <= "0010"; -- Schaltung im state "filter 0 - treble"
					
					if SW0='1' then  
						z_left  <= y_left(0)  + x_left(0); 
						z_right <= y_right(0) + x_right(0); 
					else						
						z_left  <= x_left(0)(m-1)  & x_left(0); 
						z_right <= x_right(0)(m-1) & x_right(0); 
					end if;
					
					if(left_right='0' and left_right_1='1') then 
							x_left (0) := TO_SFIXED(left_in , m-1, -n);
							x_right(0) := TO_SFIXED(right_in, m-1, -n);
							
							-- implement IIR left filter
							acc_left  := x_left(0)*b_treble(0) + x_left(1)*b_treble(1) + x_left(2)*b_treble(2) 
										  - y_left(2)*a_treble(2) - y_left(1)*a_treble(1);
							-- implement IIR right filter
							acc_right := x_left(0)*b_treble(0) + x_left(1)*b_treble(1) + x_left(2)*b_treble(2) 
										  - y_left(2)*a_treble(2) - y_left(1)*a_treble(1);
							
							-- update left input delay line
							x_left(2) := x_left(1);
							x_left(1) := x_left(0);
							-- update right input delay line
							x_right(2) := x_right(1);
							x_right(1) := x_right(0);
							
							-- update left output delay line
							y_left(0) := acc_left(m-1 downto -n);
							y_left(2) := y_left(1);
							y_left(1) := y_left(0);
							-- update right output delay line
							y_right(0) := acc_right(m-1 downto -n);
							y_right(2) := y_right(1);
							y_right(1) := y_right(0);
					end if;
					
					left_out_int  <= to_stdlogicvector(z_left);  -- convert from SFIXED to std_logic_vector
					right_out_int <= to_stdlogicvector(z_right); -- convert from SFIXED to std_logic_vector
					left_out 	  <= left_out_int (m+n-1 downto 0); -- assign only m+n bits to output vector
					right_out 	  <= right_out_int(m+n-1 downto 0); -- assign only m+n bits to output vector
					left_right_1  <= left_right;
					
					if(SW1 = '1' AND SW2 = '0' AND SW3 = '0') then
						state <= filter0;
					else
						state <= filter_select;
					end if;	
					
				---------------------------------------------------------------------
				WHEN filter1 =>
				
					data_reg_states <= "0100"; -- Schaltung im state "filter 1 - bass"
					
					if SW0='1' then  
						z_left  <= y_left(0)  + x_left(0); 
					 	z_right <= y_right(0) + x_right(0); 
					else						
						z_left  <= x_left(0)(m-1)  & x_left(0); 
					  	z_right <= x_right(0)(m-1) & x_right(0); 
					 end if;
					
					if(left_right='0' and left_right_1='1') then -- filter runs at the sampling rate
							x_left (0) := TO_SFIXED(left_in , m-1, -n);
							x_right(0) := TO_SFIXED(right_in, m-1, -n);
							
							-- implement IIR left filter
							acc_left  := x_left(0)*b_bass(0) + x_left(1)*b_bass(1) + x_left(2)*b_bass(2) 
										  - y_left(2)*a_bass(2) - y_left(1)*a_bass(1);
							-- implement IIR right filter
							acc_right := x_left(0)*b_bass(0) + x_left(1)*b_bass(1) + x_left(2)*b_bass(2) 
										  - y_left(2)*a_bass(2) - y_left(1)*a_bass(1);
							
							-- update left input delay line
							x_left(2) := x_left(1);
							x_left(1) := x_left(0);
							-- update right input delay line
							x_right(2) := x_right(1);
							x_right(1) := x_right(0);
							
							-- update left output delay line
							y_left(0) := acc_left(m-1 downto -n);
							y_left(2) := y_left(1);
							y_left(1) := y_left(0);
							-- update right output delay line
							y_right(0) := acc_right(m-1 downto -n);
							y_right(2) := y_right(1);
							y_right(1) := y_right(0);
					end if;
					
					left_out_int  <= to_stdlogicvector(z_left);  -- convert from SFIXED to std_logic_vector
					right_out_int <= to_stdlogicvector(z_right); -- convert from SFIXED to std_logic_vector
					left_out 	  <= left_out_int (m+n-1 downto 0); -- assign only m+n bits to output vector
					right_out 	  <= right_out_int(m+n-1 downto 0); -- assign only m+n bits to output vector
					left_right_1  <= left_right;
					
					if(SW1 = '0' AND SW2 = '1' AND SW3 = '0') then
						state <= filter1;
					else
						state <= filter_select;
					end if;
				---------------------------------------------------------------------
				WHEN filter2 =>
					
					data_reg_states <= "1000";
				
					if SW0='1' then  
						z_left  <= y_left(0)  + x_left(0); 
						z_right <= y_right(0) + x_right(0); 
					else						
						z_left  <= x_left(0)(m-1)  & x_left(0); 
						z_right <= x_right(0)(m-1) & x_right(0); 
					end if;
					
					if(left_right='0' and left_right_1='1') then -- filter runs at the sampling rate
							x_left (0) := TO_SFIXED(left_in , m-1, -n);
							x_right(0) := TO_SFIXED(right_in, m-1, -n);
							
							-- implement IIR left filter
							acc_left  := x_left(0)*b_move(0) + x_left(1)*b_move(1) + x_left(2)*b_move(2)+0+0; 
							-- implement IIR right filter
							acc_right := x_left(0)*b_move(0) + x_left(1)*b_move(1) + x_left(2)*b_move(2)+0+0;
							
							-- update left input delay line
							x_left(2) := x_left(1);
							x_left(1) := x_left(0);
							-- update right input delay line
							x_right(2) := x_right(1);
							x_right(1) := x_right(0);
					end if;
					
					left_out_int  <= to_stdlogicvector(z_left);  -- convert from SFIXED to std_logic_vector
					right_out_int <= to_stdlogicvector(z_right); -- convert from SFIXED to std_logic_vector
					left_out 	  <= left_out_int (m+n-1 downto 0); -- assign only m+n bits to output vector
					right_out 	  <= right_out_int(m+n-1 downto 0); -- assign only m+n bits to output vector
					left_right_1  <= left_right;
					
					if(SW1 = '0' AND SW2 = '0' AND SW3 = '1') then
						state <= filter2;
					else
						state <= filter_select;
					end if;
				---------------------------------------------------------------------
			END CASE;
		END IF;
	END PROCESS;
  data_led_red(3 downto 0) <= data_reg_states;
END behavioral;
