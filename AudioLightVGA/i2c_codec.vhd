LIBRARY ieee;
USE ieee.std_logic_1164.all;

entity i2c_codec is
 generic(ic_addr  : std_logic_vector(6 downto 0) := "0011010");
 port(rst, clk    : in std_logic;
      start       : in std_logic;
      reg_addr    : in std_logic_vector(6 downto 0);
	  reg_data    : in std_logic_vector(8 downto 0);
      i2c_sda     : inout std_logic;
	  i2c_scl     : out std_logic;
	  ack         : out std_logic;
	  idle        : out std_logic
 );
end i2c_codec ;

architecture behavioral of i2c_codec is
  type Tstate IS (s_idle, s_start, s_addr, s_ack1, s_ack2, s_ack3, s_byte1, s_byte2, s_stop1, s_stop2);
  signal state: Tstate;
  signal sreg : std_logic_vector(7 downto 0);
  signal en_scl : std_logic;
  signal aux_scl : std_logic;
  signal ack_bit1, ack_bit2, ack_bit3 : std_logic;
  constant BIT_CNT : integer := 7;
  constant TICK_CNT : integer := 1;
begin
  process(clk, rst)  -- generates SCL
  begin
    if rst='0' then
	   aux_scl <= '1';
    elsif(clk'event and clk='1')	then
	   if(en_scl='1') then
	     aux_scl <= not aux_scl;
		else
		  aux_scl <= '1';
      end if;		
	 end if;
  end process;
  i2c_scl <= aux_scl;
  
  process(clk, rst)
    variable bit_count : integer range 0 to 15;
	 variable tick_count : integer range 0 to 3;
  begin 
    if rst='0' then
        state   <= s_idle;
		i2c_sda <= '1';
		en_scl  <= '0';
		ack     <= '0';
		idle    <= '1';
    elsif(clk'event and clk='0') then
	 
      case state is
         when s_idle =>
			  idle <= '1';
           if(start='1') then
              state <= s_start; 
           else 
              state <= s_idle; 
           end if;

         when s_start =>
			  idle       <= '0';
		      sreg       <= ic_addr & '0';   	    -- load IC address and R/W bit
              i2c_sda    <= '0';
			  bit_count  := 0;
			  tick_count := 0;
			  en_scl     <= '1';
              state      <= s_addr;

         when s_addr =>
			  i2c_sda <= sreg(7);
			  if(tick_count = TICK_CNT) then
			    sreg    <= sreg(6 downto 0) & '0'; -- shift left
			    if bit_count = BIT_CNT then
				   bit_count := 0;
			      state <= s_ack1;
			    else
			      bit_count := bit_count + 1;
				   state <= s_addr;
			    end if;
				 tick_count := 0; 
			  else
			    tick_count := tick_count + 1;  
			  end if;
			  
		   when s_ack1 =>
           i2c_sda  <= 'Z';
		     ack_bit1 <= i2c_sda;
			  if(tick_count = TICK_CNT) then
			    sreg    <= reg_addr & reg_data(8);  -- load 7 bits of reg. address and MSB of data
  			    bit_count := 0;
			    state   <= s_byte1;
				 tick_count := 0;
			  else
			    tick_count := tick_count + 1;
			  end if;	 
			  
			when s_byte1 =>
			  i2c_sda <= sreg(7);
			  if(tick_count = TICK_CNT) then
   	       sreg <= sreg(6 downto 0) & '0';  -- shift left
			    if bit_count = BIT_CNT then
				   bit_count := 0;
			      state <= s_ack2;
			    else
			      bit_count := bit_count + 1;
				   state <= s_byte1;
			    end if;
				 tick_count := 0;
			  else
			    tick_count := tick_count + 1;
			  end if;	 

			when s_ack2 =>
  	        i2c_sda  <= 'Z';
		     ack_bit2 <= i2c_sda;
			  if(tick_count = TICK_CNT) then
			    sreg  <= reg_data(7 downto 0);  -- load 8 bits of data
  			    state <= s_byte2;
				 tick_count := 0;
			  else
			    tick_count := tick_count + 1;
			  end if;  

			when s_byte2 =>
  		     i2c_sda <= sreg(7);
			  if(tick_count = TICK_CNT) then
   	       sreg <= sreg(6 downto 0) & '0';  -- shift left
			    if bit_count = BIT_CNT then
				   bit_count := 0;
			      state <= s_ack3;
			    else
			      bit_count := bit_count + 1;
				   state <= s_byte2;
			    end if;
				 tick_count := 0;
			  else
			   tick_count := tick_count + 1;
	        end if;			
	         		
			when s_ack3 =>
   	     i2c_sda  <= 'Z';
		     ack_bit3 <= i2c_sda;
			  if(tick_count = TICK_CNT) then
   		  	 state <= s_stop1;
				 tick_count := 0;
			  else
		       tick_count := tick_count + 1;
			  end if;	  
 
		   when s_stop1 =>
			  i2c_sda <= '0';
			  en_scl  <= '0';
           ack     <= ack_bit1 or ack_bit2 or ack_bit3;
			  state   <= s_stop2;

		   when s_stop2 =>
			  i2c_sda <= '1';
			  state   <= s_idle;

			  
      end case;
    end if;
  end process;

end behavioral;