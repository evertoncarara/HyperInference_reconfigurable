library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.numeric_std.ALL;

entity Encoder is
    generic (
        PARALLEL            : integer := 4;
        FEATURE_WIDTH       : integer := 8;
        INDEX_WIDTH         : integer := 13; 
        DIMENSIONS          : integer := 8192;
        INDEXES_IMG         : string := ""
    );
    port (
        clk         : in std_logic;
        rst         : in std_logic;
        start       : in std_logic;
        feature     : in std_logic_vector(FEATURE_WIDTH - 1 downto 0);
        address     : out std_logic_vector(9 downto 0);
        bits        : out std_logic_vector(PARALLEL - 1 downto 0);
        bits_av     : out std_logic;
        halt        : in std_logic; -- Back pressure control
        done        : out std_logic;
        effective_d : in std_logic_vector(12 downto 0);
        max_x       : in std_logic_vector(9 downto 0);
        max_y       : in std_logic_vector(9 downto 0);
        sample_size : in std_logic_vector(15 downto 0);
        mask_f      : in std_logic_vector(16 downto 0);
        mask_x      : in std_logic_vector(16 downto 0);
        mask_y      : in std_logic_vector(16 downto 0);
        data_in     : in std_logic_vector(31 downto 0);
        wr_idx      : in std_logic          
    );
end Encoder;

architecture Behavioral of Encoder is   
    
    constant ADDR_WIDTH: integer := 12;
    
    type State is (RESET, INIT_SAMPLE_MEM_ADDR, READ_INDEXES, SAMPLE_MEM_ADDR, SUM, BITS_AVAILABLE, FINISH);
    signal currentState : State;
    
    signal x, y: UNSIGNED(9 downto 0);
    signal data_av : std_logic;
            
    signal bit_enc_rst: std_logic;
    
    
    -- Memories
    signal samples_addr : UNSIGNED(9 downto 0);
    
    signal indexes_addr: UNSIGNED(ADDR_WIDTH - 1 downto 0);
    
    type IndexesArray is array(natural range <>) of std_logic_vector(INDEX_WIDTH - 1 downto 0);
    signal idxs : IndexesArray(PARALLEL - 1 downto 0);
    signal idx : std_logic_vector(INDEX_WIDTH - 1 downto 0);
    signal i: integer; 
    
begin

    address <= STD_LOGIC_VECTOR(samples_addr); 
        
    INDEXES: entity work.Memory(BlockRAM)
        generic map (
            imageFileName   => INDEXES_IMG,         
            DATA_WIDTH      => INDEX_WIDTH,
            ADDR_WIDTH      => ADDR_WIDTH
        )
        port map (
            clock           => clk,
            wr              => wr_idx,
            write_address   => (others=>'0'),
            read_address    => STD_LOGIC_VECTOR(indexes_addr),
            data_i          => data_in(INDEX_WIDTH - 1 downto 0),        
            data_o          => idx
        );
    
    PARALLEL_BIT_ENCODERS: for i in 0 to PARALLEL - 1 generate    
        BIT_ENCODER: entity work.BitEncoder(Behavioral) 
            generic map (
                INDEX_WIDTH => INDEX_WIDTH,
                DIMENSIONS  => DIMENSIONS
            )
            port map (
                clk         => clk,
                rst         => bit_enc_rst,
                idx         => idxs(i),
                data        => feature,
                data_av     => data_av,
                x           => STD_LOGIC_VECTOR(x),
                y           => STD_LOGIC_VECTOR(y),
                b           => bits(i),
                threshold   => sample_size(sample_size'left downto 1),
                mask_f      => mask_f,
                mask_x      => mask_x,
                mask_y      => mask_y
            );
            
    end generate PARALLEL_BIT_ENCODERS;
    
 
    bit_enc_rst <= '1' when currentState = INIT_SAMPLE_MEM_ADDR else '0';
    
    data_av <= '1' when currentState = SUM else '0';
    
    bits_av <= '1' when currentState = BITS_AVAILABLE else '0';
    
    done <= '1' when currentState = FINISH else '0';
       
    process(clk, rst)
    begin
        if rst = '1' then
            
            currentState <= RESET;
        
        elsif rising_edge(clk) then
            case currentState is 
                when RESET =>                    
                    indexes_addr <= (others=>'0'); 
                    i <= 0;                   
                    
                    if start = '1' then
                        currentState <= INIT_SAMPLE_MEM_ADDR;
                    end if;
                    
                when INIT_SAMPLE_MEM_ADDR =>
                    x <= (others=>'0');
                    y <= (others=>'0');
                    samples_addr <= (others=>'0');
                    indexes_addr <= indexes_addr + 1;
                    currentState <= READ_INDEXES;
                    
                when READ_INDEXES =>                    
                    idxs(i) <= idx;
                    
                    if i < PARALLEL - 1 and indexes_addr < UNSIGNED(effective_d) then                        
                        i <= i + 1;
                        indexes_addr <= indexes_addr + 1; 
                    else       
                        i <= 0;
                        currentState <= SAMPLE_MEM_ADDR;
                    end if;
                    
                when SAMPLE_MEM_ADDR =>
                    samples_addr <= samples_addr + 1;
                    currentState <= SUM;
                    
                when SUM =>           
                    if samples_addr < UNSIGNED(sample_size) then
                        samples_addr <= samples_addr + 1;
                    else
                        currentState <= BITS_AVAILABLE;
                    end if;
                    
                    if y < UNSIGNED(max_y) then
                        if x < UNSIGNED(max_x) - 1 then
                            x <= x + 1;
                        else
                            x <= (others=>'0');
                            y <= y + 1;
                        end if; 
                    end if; 
                    
                when BITS_AVAILABLE =>
                    if halt = '0' then
                        if indexes_addr >= UNSIGNED(effective_d)  then
                            currentState <= FINISH;
                        else
                            currentState <= INIT_SAMPLE_MEM_ADDR;
                        end if;
                    end if;
                    
                when FINISH =>
                    currentState <= RESET;
                                        
                
            end case;
        end if;  
    end process;

end Behavioral;