library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.numeric_std.ALL;

entity HyperInference is
    generic (
        --INDEXES_IMG         : string := "ISOLET_idxs.txt";
        --CLASSES_IMG         : string := "ISOLET_hvs.txt";
        CLASSES_IMG         : string := "UNUSED";
        INDEXES_IMG         : string := "UNUSED"; 
        INDEX_WIDTH         : integer := 13;
        SAMPLE_ADDR_WIDTH   : integer := 10;
        SAMPLE_DATA_WIDTH   : integer := 8;
        CLASS_DATA_WIDTH    : integer := 26;
        CLASS_ADDR_WIDTH    : integer := 12;
        PARALLEL            : integer := 21;
        COUNTER_ADDERS      : integer := 1;
        DIMENSIONS          : integer := 8192     
    );
    port (
        clk             : in std_logic;
        rst             : in std_logic;
        start           : in std_logic;
        done            : out std_logic;
        class           : out std_logic_vector(4 downto 0);
        samples_addr    : out std_logic_vector(SAMPLE_ADDR_WIDTH - 1 downto 0);
        feature         : in std_logic_vector(SAMPLE_DATA_WIDTH - 1 downto 0);
        data_in         : in std_logic_vector(31 downto 0);
        wr_classes      : in std_logic;
        wr_effective_d  : in std_logic;
        wr_max_x        : in std_logic;
        wr_max_y        : in std_logic;
        wr_sample_size  : in std_logic;
        wr_mask_f       : in std_logic;
        wr_mask_x       : in std_logic;
        wr_mask_y       : in std_logic;
        wr_chv          : in std_logic;
        wr_idx          : in std_logic
    );
end HyperInference;

architecture Behavioral of HyperInference is
       
    signal class_addr   : UNSIGNED(CLASS_ADDR_WIDTH - 1 downto 0);
    signal class_bits   : std_logic_vector(CLASS_DATA_WIDTH - 1 downto 0);      
    
    type CountersArray is array(natural range <>) of UNSIGNED(11 downto 0);
    signal counters : CountersArray(0 to CLASS_DATA_WIDTH - 1);
    signal smaller  : UNSIGNED(11 downto 0);
    
    signal bits_av, encoder_done, done_reg: std_logic;
    signal bits, encoded_bits: std_logic_vector(PARALLEL - 1 downto 0);
    signal counting: std_logic;
    
    type State is (INIT, WAITING_BITS, HAMMING, READ_CLASS_HVS_BITS, CLASSIFICATION, FINISHED);
    signal currentState : State;
    
    signal i            : integer;
    signal count_bits   : integer;
    signal classes      : UNSIGNED(4 downto 0);
    signal effective_d  : std_logic_vector(12 downto 0);
    signal max_x, max_y : std_logic_vector(9 downto 0);
    signal sample_size  : std_logic_vector(15 downto 0);
    signal mask_f       : std_logic_vector(16 downto 0); 
    signal mask_x       : std_logic_vector(16 downto 0); 
    signal mask_y       : std_logic_vector(16 downto 0); 
          
begin
    HV_ENCODER: entity work.Encoder(Behavioral)
        generic map (
            PARALLEL            => PARALLEL,
            FEATURE_WIDTH       => SAMPLE_DATA_WIDTH,
            INDEX_WIDTH         => INDEX_WIDTH, 
            DIMENSIONS          => DIMENSIONS,
            INDEXES_IMG         => INDEXES_IMG
        )
        port map (
            clk         => clk,
            rst         => rst,
            start       => start,
            address     => samples_addr,
            feature     => feature,
            bits_av     => bits_av,
            bits        => bits,
            halt        => counting,
            done        => encoder_done,
            effective_d => effective_d,
            max_x       => max_x,
            max_y       => max_y,
            sample_size => sample_size,
            mask_f      => mask_f,
            mask_x      => mask_x,
            mask_y      => mask_y,
            data_in     => data_in,
            wr_idx     => wr_idx
        );
               
    CLASS_HVS: entity work.Memory(BlockRAM)
        generic map (
            imageFileName   => CLASSES_IMG,         
            DATA_WIDTH      => CLASS_DATA_WIDTH,
            ADDR_WIDTH      => CLASS_ADDR_WIDTH
        )
        port map (
            clock           => clk,
            wr              => wr_chv,
            write_address   => (others=>'0'),
            read_address    => std_logic_vector(class_addr),
            data_i          => data_in(CLASS_DATA_WIDTH - 1 downto 0),        
            data_o          => class_bits
        );
        
    -- Backpressure
    -- Used to halt encoder when it is not ready to compute hamming distance (currentState is not WAITING_BITS)
    counting <= '1' when currentState = HAMMING or currentState = READ_CLASS_HVS_BITS else '0';
    
    done <= '1' when currentState = FINISHED else '0';
    
    process(clk)
    begin
        if rising_edge(clk) then
            if wr_classes = '1' then
                classes <= UNSIGNED(data_in(classes'range));
            end if;
            
            if wr_effective_d = '1' then
                effective_d <= data_in(effective_d'range);
            end if;
            
            if wr_max_x = '1' then
                max_x <= data_in(max_x'range);
            end if;
            
            if wr_max_y = '1' then
                max_y <= data_in(max_y'range);
            end if;
            
            if wr_sample_size = '1' then
                sample_size <= data_in(sample_size'range);
            end if;
            
            if wr_mask_f = '1' then
                mask_f <= data_in(mask_f'range);
            end if;
            
            if wr_mask_x = '1' then
                mask_x <= data_in(mask_x'range);
            end if;
            
            if wr_mask_y = '1' then
                mask_y <= data_in(mask_y'range);
            end if;
        end if;
    end process;
    
            
    process(clk, rst)
    begin
        if rst = '1' then
            currentState <= INIT;
            
        elsif rising_edge(clk) then
            case currentState is
                when INIT =>
                    class_addr <= (others=>'0');
                    currentState <= WAITING_BITS;
                    i <= 0;                    
                    
                when WAITING_BITS =>                    
                    encoded_bits <= bits;
                    count_bits <= 0;
                    
                    if bits_av = '1' then                                                
                        currentState <= HAMMING;                       
                    
                    elsif done_reg = '1' then
                        smaller <= counters(0);
                        class <= STD_LOGIC_VECTOR(TO_UNSIGNED(0, class'length));
                        currentState <= CLASSIFICATION;
                    end if;
                    
                when HAMMING =>
                    i <= i + COUNTER_ADDERS;
                        
                    if i + COUNTER_ADDERS >= CLASSES then
                        i <= 0;
                        class_addr <= class_addr + 1;
                        count_bits <= count_bits + 1;                        
                        
                        if count_bits = PARALLEL - 1 then
                            currentState <= WAITING_BITS;
                        else
                            currentState <= READ_CLASS_HVS_BITS;
                        end if;
                    end if;                     
                    
                when READ_CLASS_HVS_BITS =>
                    currentState <= HAMMING;
                    
                when CLASSIFICATION =>
                    if counters(i) < smaller then
                        smaller <= counters(i);
                        class <= STD_LOGIC_VECTOR(TO_UNSIGNED(i, class'length));
                    end if;
                    
                    i <= i + 1;
                    
                    if i = CLASSES - 1 then
                        currentState <= FINISHED;
                    end if;
                    
                when FINISHED =>
                    currentState <= WAITING_BITS; 
                    
                when others =>
            end case;     
        end if;
    end process;
    
    -- Store the done signal generated by Encoder.
    -- This signal can be missed when it arrives and this is not ready to catch it (currentState is not WAITING_BITS) 
    process(clk, rst)
    begin
        if rst = '1' then
            done_reg <= '0';
            
        elsif rising_edge(clk) then
            if encoder_done = '1' then
                done_reg <= '1';
            end if;
            
            if currentState = CLASSIFICATION then
                done_reg <= '0';
            end if;
            
        end if;
    end process;

    
    -- Adders used to compute the hamming distance
    ADDERS: for c in 0 to COUNTER_ADDERS - 1 generate
        process(clk, rst)
        begin
            if rst = '1' then
                counters <= (others=>(others=>'0'));
            elsif rising_edge(clk) then
                if currentState = HAMMING then
                
                    for j in 0 to COUNTER_ADDERS - 1 loop
                        
                        if (i + j) < CLASSES then
                            if encoded_bits(count_bits) = class_bits(i + j) then
                                counters(i + j) <= counters(i + j) + 1;                     
                            end if;
                        end if;
                    end loop;
                
                end if;
            end if;
        end process;
    
    end generate;    
  

end Behavioral;
