library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.numeric_std.ALL;

entity BitEncoder is
    generic (
        INDEX_WIDTH : integer := 16;
        DIMENSIONS  : integer := 8192
    );
    port ( 
        clk         : in std_logic;
        rst         : in std_logic;
        idx         : in std_logic_vector (INDEX_WIDTH - 1 downto 0);
        data        : in std_logic_vector (7 downto 0);
        x           : in std_logic_vector (9 downto 0);
        y           : in std_logic_vector (9 downto 0);
        data_av     : in std_logic;
        b           : out std_logic;
        threshold   : in std_logic_vector(14 downto 0);
        mask_f      : in std_logic_vector(16 downto 0);
        mask_x      : in std_logic_vector(16 downto 0);
        mask_y      : in std_logic_vector(16 downto 0)
    );
end BitEncoder;

architecture Behavioral of BitEncoder is

    signal hv_bit_f, hv_bit_x, hv_bit_y: std_logic;
    signal bind_fx : std_logic;
    
    signal idx_f, idx_x, idx_y: SIGNED (15 downto 0);
    signal temp_idx_f, temp_idx_x, temp_idx_y: SIGNED (15 downto 0);
    
    signal count: UNSIGNED(9 downto 0);

begin
   
    -- Emulate roll right acording to 'data'
    temp_idx_f <= RESIZE(SIGNED(idx) - SIGNED('0' & data), temp_idx_f'length);
    
    -- Emulate roll right acording to 'x'
    temp_idx_x <= RESIZE(SIGNED(idx) - SIGNED('0' & x), temp_idx_x'length);
    
    -- Emulate roll right acording to 'y'
    temp_idx_y <= RESIZE(SIGNED(idx) - SIGNED('0' & y), temp_idx_y'length);
     
    D_NOT_8192: if DIMENSIONS /= 8192 generate        
        idx_f <= temp_idx_f when temp_idx_f >= 0 else temp_idx_f + TO_SIGNED(DIMENSIONS, temp_idx_f'length);
        idx_x <= temp_idx_x when temp_idx_x >= 0 else temp_idx_x + TO_SIGNED(DIMENSIONS, temp_idx_x'length);
        idx_y <= temp_idx_y when temp_idx_y >= 0 else temp_idx_y + TO_SIGNED(DIMENSIONS, temp_idx_y'length);
    end generate;    
    
    -- DIMENSIONS = 8192 is a power of 2 value
    -- 2 ** 13 = 8192
    D_8192: if DIMENSIONS = 8192 generate 
        idx_f <= "000" & temp_idx_f(INDEX_WIDTH - 1 downto 0);   -- Exploring wrap-around to find the right index         
        idx_x <= "000" & temp_idx_x(INDEX_WIDTH - 1 downto 0);   -- Exploring wrap-around to find the right index
        idx_y <= "000" & temp_idx_y(INDEX_WIDTH - 1 downto 0);   -- Exploring wrap-around to find the right index 
    end generate;
   
   
    BASE_HV_F: entity work.HVBits(configurable) port map(
        t       => STD_LOGIC_VECTOR(idx_f),
        o       => hv_bit_f,
        mask    => mask_f
    );
    
    BASE_HV_X: entity work.HVBits(configurable) port map(
        t       => STD_LOGIC_VECTOR(idx_x),
        o       => hv_bit_x,
        mask    => mask_x
    );
    
    BASE_HV_Y: entity work.HVBits(configurable) port map(
        t       => STD_LOGIC_VECTOR(idx_y),
        o       => hv_bit_y,
        mask    => mask_y
    );
 
      
    bind_fx <= hv_bit_f xor hv_bit_x xor hv_bit_y;     
    
    process(clk, rst)
    begin
        if rst = '1' then
            count <= (others=>'0');
            
        elsif rising_edge(clk) then
            if data_av = '1' then
                count <= count + unsigned'("" & bind_fx);
            end if;          
        end if;
    end process;
    
    b <= '1' when count > UNSIGNED(threshold) else '0';
    
end Behavioral;