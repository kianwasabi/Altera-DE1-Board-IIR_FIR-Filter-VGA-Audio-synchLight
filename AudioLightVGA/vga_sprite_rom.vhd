Library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity vga_sprite_rom is
	generic(
	W : natural := 120;
	H : natural := 80
	);
	port(
	hc			 	: IN  std_logic_vector(9 downto 0);
	vc		 	 	: IN  std_logic_vector(9 downto 0);
	videon	 	: IN  std_logic;
	sw_filter 	: IN  std_logic;
	sw_filter1	: IN  std_logic;
	sw_filter2	: IN  std_logic;
	--sw			   : IN  std_logic_vector(7 downto 0);
	red			: OUT std_logic_vector(3 downto 0);
	green			: OUT std_logic_vector(3 downto 0);
	blue			: OUT std_logic_vector(3 downto 0)
	);
end vga_sprite_rom;

architecture behavioral of vga_sprite_rom is

	constant hbp : std_logic_vector(9 downto 0) := "0010010000";  -- horizontal back porch 
	constant vbp : std_logic_vector(9 downto 0) := "0000011111";  -- vertical back porch
	
	signal C1, R1 : std_logic_vector(9 downto 0);                 -- left upper corner of sprite 
	
	signal x_pix, y_pix : std_logic_vector(9 downto 0);
	
	signal spriteon  : std_logic; 
	signal spriteon1 : std_logic; 
	signal spriteon2 : std_logic; 
	
	signal rom_data  : std_logic_vector(7 downto 0);               -- ROM  data bus
	signal rom_data1 : std_logic_vector(7 downto 0);               -- ROM1 data bus
	signal rom_data2 : std_logic_vector(7 downto 0);               -- ROM2 data bus

	
	signal rom_ptr : integer;
	signal rom_ptr1 : integer;
	signal rom_ptr2 : integer;
	
	type memory is array (0 to W*H) of STD_LOGIC_VECTOR (7 downto 0); 
	
	signal rom  : memory;
	signal rom1 : memory;
	signal rom2 : memory;
	-- initialize rom with .mif file
	ATTRIBUTE ram_init_file			 : STRING;
	ATTRIBUTE ram_init_file OF rom : SIGNAL IS ".\filter0.mif";
	ATTRIBUTE ram_init_file OF rom1: SIGNAL IS ".\filter1.mif";
	ATTRIBUTE ram_init_file OF rom2: SIGNAL IS ".\filter2.mif";
	
begin
	C1 <= '0' & "1000" & "00001"; -- C1 <= '0' & sw(3 downto 0) & "00001"; 
	R1 <= '0' & "1000" & "00001"; -- R1 <= '0' & sw(7 downto 4) & "00001"; 
	y_pix <= vc - vbp - R1; 	   -- sprite relative y coordinate 
	x_pix <= hc - hbp - C1; 		-- sprite relative x coordinate
	
	spriteon <= '1' when (((hc >= C1+hbp) and (hc < C1+hbp+W)) 
							and ((vc >= R1+vbp) and (vc < R1+vbp+H))) 
						 else '0';
	rom_ptr  <= conv_integer(y_pix)*W + conv_integer(x_pix); 
	rom_data <= rom(rom_ptr);
	
	spriteon1 <= '1' when (((hc >= C1+hbp) and (hc < C1+hbp+W)) 
							and ((vc >= R1+vbp) and (vc < R1+vbp+H))) 
						 else '0';
	rom_ptr1  <= conv_integer(y_pix)*W + conv_integer(x_pix); 
	rom_data1 <= rom1(rom_ptr1);
	
	spriteon2 <= '1' when (((hc >= C1+hbp) and (hc < C1+hbp+W)) 
							and ((vc >= R1+vbp) and (vc < R1+vbp+H))) 
						 else '0';
	rom_ptr2  <= conv_integer(y_pix)*W + conv_integer(x_pix); 
	rom_data2 <= rom2(rom_ptr2);
	
process(spriteon ,videon ,rom_data ,
		  spriteon1,        rom_data1,
		  spriteon2,	     rom_data2)
	begin 
		 if 	(spriteon ='1' and videon = '1' and sw_filter = '1'and sw_filter1 = '0'and sw_filter2 = '0') then -- decodes color stored in ROM
			 red   <= rom_data(7 downto 5) & '0'; 
			 green <= rom_data(4 downto 2) & '0'; 
			 blue  <= rom_data(1 downto 0) & "00"; 
		 elsif(spriteon1='1' and videon = '1' and sw_filter = '0'and sw_filter1 = '1'and sw_filter2 = '0') then -- decodes color stored in ROM1
			 red   <= rom_data1(7 downto 5) & '0'; 
			 green <= rom_data1(4 downto 2) & '0'; 
			 blue  <= rom_data1(1 downto 0) & "00"; 
		 elsif(spriteon2='1' and videon = '1' and sw_filter = '0'and sw_filter1 = '0'and sw_filter2 = '1') then -- decodes color stored in ROM2
			 red   <= rom_data2(7 downto 5) & '0'; 
			 green <= rom_data2(4 downto 2) & '0'; 
			 blue  <= rom_data2(1 downto 0) & "00"; 
		 else
			red   <= "0000";
			green <= "0000"; 
			blue  <= "0000";		 
		 end if; 
		 
	 end process; 
end behavioral; 