library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.numeric_std.ALL;

entity HyperInference_tb is
end HyperInference_tb;

architecture Behavioral of HyperInference_tb is

    -- Memories constants
    constant SAMPLE_ADDR_WIDTH  : integer := 10;
    constant SAMPLE_DATA_WIDTH  : integer := 8;   
    
    constant CLASS_ADDR_WIDTH   : integer := 12;
    constant CLASS_DATA_WIDTH   : integer := 32; -- CLASSES
    
    constant INDEX_WIDTH        : integer := 13;    -- Must suport the highest effective index (e.g 8191)

    constant DIMENSIONS         : integer := 8192;
    constant PARALLEL           : integer := 21; 
    constant COUNTER_ADDERS     : integer := 1;    
    
    
    -- Number of dataset classes
    constant CLASSES            : integer := 26;    -- ISOLET
    --constant CLASSES            : integer := 6;    -- UCIHAR
    --constant CLASSES            : integer := 10;    -- MNIST
    
    -- d: diemensions after pruning
    constant EFFECTIVE_INDEXES  : integer := 3700;  -- 'd' : amount of indexes used (ISOLET)
    --constant EFFECTIVE_INDEXES  : integer := 3200;  -- 'd' : amount of indexes used (UCIHAR/MNIST)
    
    
    -- Memory image files
    -- ISOLET image files
    constant SAMPLE_IMG         : string := "ISOLET_sample.txt";
    constant CLASSES_IMG        : string := "ISOLET_hvs.txt";
    constant INDEXES_IMG        : string := "ISOLET_idxs.txt";

    -- UCIHAR image files
--    constant SAMPLE_IMG         : string := "UCIHAR_sample.txt";
--    constant CLASSES_IMG        : string := "UCIHAR_hvs.txt";
--    constant INDEXES_IMG        : string := "UCIHAR_idxs.txt";

    -- MNIST image files
--    constant SAMPLE_IMG         : string := "MNIST_sample.txt";
--    constant CLASSES_IMG        : string := "MNIST_hvs.txt";
--    constant INDEXES_IMG        : string := "MNIST_idxs.txt";
    
   
    -- ISOLET/UCIHAR dimensions
    constant MAX_X              : integer := 617; -- ISOLET
    --constant MAX_X              : integer := 561; -- UCIHAR
    constant MAX_Y              : integer := 1; -- ISOLET/UCIHAR
    
    -- MNIST dimensions
    --constant MAX_X              : integer := 28;    -- MNIST
    --constant MAX_Y              : integer := 28;    -- MNIST
    
    constant SAMPLE_SIZE        : integer := MAX_X * MAX_Y;
    

    -- ISOLET/UCIHAR xor masks
    constant MASK_F             : std_logic_vector(16 downto 0) := "01111111111001100"; -- Bit 16 = 1: not
    constant MASK_X             : std_logic_vector(16 downto 0) := "11111111111001100"; -- Bit 16 = 1: not
    constant MASK_Y             : std_logic_vector(16 downto 0) := "00000000000000000"; -- Bit 16 = 1: not 
    
    -- MNIST xor masks
    --constant MASK_F             : std_logic_vector(16 downto 0) := "00000000011110000"; -- Bit 16 = 1: not
    --constant MASK_X             : std_logic_vector(16 downto 0) := "01111111100000000"; -- Bit 16 = 1: not
    --constant MASK_Y             : std_logic_vector(16 downto 0) := "00011000011111100"; -- Bit 16 = 1: not        



    
    signal samples_addr : std_logic_vector(SAMPLE_ADDR_WIDTH - 1 downto 0);
    signal feature      : std_logic_vector(SAMPLE_DATA_WIDTH - 1 downto 0);    
       
    signal done: std_logic;    
    
    signal clk              : std_logic := '0';
    signal rst              : std_logic;
    signal start            : std_logic;
    signal wr_classes       : std_logic;
    signal wr_effective_d   : std_logic;
    signal wr_max_x         : std_logic;
    signal wr_max_y         : std_logic;
    signal wr_sample_size   : std_logic;
    signal wr_mask_f        : std_logic;
    signal wr_mask_x        : std_logic;
    signal wr_mask_y        : std_logic;
    signal wr_chv           : std_logic;
    signal wr_idx           : std_logic;
    signal data_in          : std_logic_vector(31 downto 0);
      
      
begin

    --clk <= not clk after 2.5 ns;  -- 5ns = 200MHz
    --clk <= not clk after 2.75 ns; -- 5.5ns = 181.81MHz
    --clk <= not clk after 3 ns;      -- 6ns = 166,66MHz
    --clk <= not clk after 3.25 ns;      -- 6.5ns = 153,84MHz
    clk <= not clk after 3.5 ns;    -- 7ns = 142.85MHz
    --clk <= not clk after 4 ns;      -- 8ns = 125MHz
    --clk <= not clk after 4.5 ns;    -- 9ns = 111.11MHz
    
    rst <= '1', '0' after 5 ns;
            
    HYPER_INFERENCE: entity work.HyperInference(behavioral)
        generic map (
            SAMPLE_ADDR_WIDTH   => SAMPLE_ADDR_WIDTH,
            SAMPLE_DATA_WIDTH   => SAMPLE_DATA_WIDTH,
            CLASS_ADDR_WIDTH    => CLASS_ADDR_WIDTH,
            CLASS_DATA_WIDTH    => CLASS_DATA_WIDTH,
            INDEX_WIDTH         => INDEX_WIDTH,
            COUNTER_ADDERS      => COUNTER_ADDERS,
            PARALLEL            => PARALLEL,
            DIMENSIONS          => DIMENSIONS,
            INDEXES_IMG         => INDEXES_IMG,
            CLASSES_IMG         => CLASSES_IMG
        )
        port map (
            clk             => clk,
            rst             => rst,
            start           => start,
            samples_addr    => samples_addr,
            feature         => feature,            
            done            => done,
            data_in         => data_in,
            wr_classes      => wr_classes,
            wr_effective_d  => wr_effective_d,
            wr_max_x        => wr_max_x,
            wr_max_y        => wr_max_y,
            wr_sample_size  => wr_sample_size,
            wr_mask_f       => wr_mask_f,
            wr_mask_x       => wr_mask_x,
            wr_mask_y       => wr_mask_y,
            wr_chv          => wr_chv,
            wr_idx         => wr_idx           
        );
        
        
    SAMPLE: entity work.Memory(BlockRAM)
        generic map (
            imageFileName   => SAMPLE_IMG,         
            DATA_WIDTH      => SAMPLE_DATA_WIDTH,
            ADDR_WIDTH      => SAMPLE_ADDR_WIDTH
        )
        port map (
            clock           => clk,
            wr              => '0',
            write_address   => (others=>'0'),
            read_address    => STD_LOGIC_VECTOR(samples_addr),
            data_i          => (others=>'0'),        
            data_o          => feature
        );
        
   
    process
    begin
        start           <= '0';
        wr_classes      <= '0';
        wr_effective_d  <= '0';
        wr_max_x        <= '0';
        wr_max_y        <= '0';
        wr_sample_size  <= '0';
        wr_mask_f       <= '0';
        wr_mask_x       <= '0';
        wr_mask_y       <= '0';
        wr_chv          <= '0';
        wr_idx          <= '0';
        
        wait until rising_edge(clk);
        data_in <= STD_LOGIC_VECTOR(TO_UNSIGNED(CLASSES, data_in'length));
        wr_classes  <= '1';
        wait until rising_edge(clk);
        wr_classes  <= '0';
        
        wait until rising_edge(clk);
        data_in <= STD_LOGIC_VECTOR(TO_UNSIGNED(EFFECTIVE_INDEXES, data_in'length));
        wr_effective_d  <= '1';
        wait until rising_edge(clk);
        wr_effective_d  <= '0';
        
        wait until rising_edge(clk);
        data_in <= STD_LOGIC_VECTOR(TO_UNSIGNED(MAX_X, data_in'length));
        wr_max_x  <= '1';
        wait until rising_edge(clk);
        wr_max_x  <= '0';
        
        wait until rising_edge(clk);
        data_in <= STD_LOGIC_VECTOR(TO_UNSIGNED(MAX_Y, data_in'length));
        wr_max_y  <= '1';
        wait until rising_edge(clk);
        wr_max_y  <= '0';
        
        wait until rising_edge(clk);
        data_in <= STD_LOGIC_VECTOR(TO_UNSIGNED(SAMPLE_SIZE, data_in'length));
        wr_sample_size  <= '1';
        wait until rising_edge(clk);
        wr_sample_size  <= '0';
        
        wait until rising_edge(clk);
        data_in <= STD_LOGIC_VECTOR(RESIZE(UNSIGNED(MASK_F), data_in'length));
        wr_mask_f  <= '1';
        wait until rising_edge(clk);
        wr_mask_f  <= '0';
        
        wait until rising_edge(clk);
        data_in <= STD_LOGIC_VECTOR(RESIZE(UNSIGNED(MASK_X), data_in'length));
        wr_mask_x  <= '1';
        wait until rising_edge(clk);
        wr_mask_x  <= '0';
        
        wait until rising_edge(clk);
        data_in <= STD_LOGIC_VECTOR(RESIZE(UNSIGNED(MASK_Y), data_in'length));
        wr_mask_y  <= '1';
        wait until rising_edge(clk);
        wr_mask_y  <= '0';
        
        
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        start <= '1';
        
        wait until rising_edge(clk);
        start <= '0';
        
        wait;
    end process;

end Behavioral;
