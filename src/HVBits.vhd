----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 09/22/2025 10:17:18 AM
-- Design Name: 
-- Module Name: HVBits - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity HVBits is
    port (         
        t       : in std_logic_vector(15 downto 0);
        o       : out std_logic;
        mask    : in std_logic_vector(16 downto 0)
    );
end HVBits;


architecture configurable of HVBits is

    signal rt: UNSIGNED(15 downto 0);  
    signal rotate: integer;
    signal xor_mask : std_logic_vector(rt'range);
    
begin
    
    rotate <= TO_INTEGER(UNSIGNED(t(3 downto 0)));

    rt <= ROTATE_LEFT(UNSIGNED(t), rotate);
    
    -- Python indexes:  00 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15
    -- VHDL indexes:    15 14 13 12 11 10 09 08 07 06 05 04 03 02 01 00
  
    -- Apply mask
    MASK_BITS: for i in rt'range generate
        xor_mask(i) <= rt(i) and mask(i);
    end generate;
    
    
    XOR_REDUCE: process(xor_mask)
        variable tmp : std_logic;
    begin
        tmp := '0';
        
        -- XOR reduce
        for i in xor_mask'range loop
            tmp := tmp xor xor_mask(i);
        end loop;
        
        o <= tmp xor mask(mask'left); -- mask(mask'left): NOT
    end process;
    
end configurable;
