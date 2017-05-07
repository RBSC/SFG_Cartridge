library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;

entity SFG05S is
  port(
    pSltAdr     : IN std_logic_vector(13 downto 0);
    pSltDat     : INOUT std_logic_vector(7 downto 0);
	pSltSel_n 	: IN std_logic;
    pSltRd_n    : IN std_logic;
    pSltWr_n    : IN std_logic;
    pSltIorq_n  : IN std_logic;
    pSltM1_n    : IN std_logic;       	
    pSltInt_n   : OUT std_logic;
    pSltWait_n  : OUT std_logic;
    pSltBusdir_n  : OUT std_logic;
    pSltRst_n   : IN std_logic;
    pSltClc		: IN std_logic; 
    pCrtClc		: IN std_logic; 
    pCrtORM_n	: OUT std_logic;
    pCrtROM_n	: Out std_logic;  
    pMidiTx_n   : OUT std_logic;  
    pMidiRx		: IN std_logic;  
    pST			: OUT std_logic_vector(7 downto 0);
    pSD			: IN std_logic_vector(7 downto 0)   
  );
end SFG05S;
architecture RTL of SFG05S is
  component YM2148
  port(
    pSltAdr     : IN std_logic_vector(2 downto 0);
    pSltDat     : INOUT std_logic_vector(7 downto 0);
	CS_n 	: IN std_logic;
    pSltRd_n    : IN std_logic;
    pSltWr_n    : IN std_logic;   	

    pSltInt_n   : OUT std_logic;
    VInt_n	: IN std_logic;   
    pSltRst_n   : IN std_logic;
    pSltClc		: IN std_logic; 
    pCrtClc		: IN std_logic; 

    pCrtORM_n	: OUT std_logic;  
    pMidiTx		: OUT std_logic;  
    pMidiRx		: IN std_logic;  
    pST			: OUT std_logic_vector(7 downto 0);
    pSD			: IN std_logic_vector(7 downto 0)   
  );  end component;  
  signal CS_YM2148_n : std_logic;
  signal ROM_blw	 : std_logic;
  signal VR		     : std_logic;
  signal TWait		 : std_logic;
  signal rstTWait    : std_logic;
  signal pMidiTx     : std_logic;
begin
-- ROM Chip Select
  pCrtROM_n <= '0' when ROM_blw = '0' and pSltSel_n = '0' and pSltRd_n = '0'
         else '1';
-- YM2148 Exclude area of ROM
  ROM_blw <= '1' when pSltAdr(13 downto 7) = "1111111"
        else '0';
-- Chip Select YM2148
  CS_YM2148_n <='0' when  pSltAdr(6 downto 3) = "1110" and ROM_blw = '1' and pSltSel_n = '0'
           else '1' ;
-- Vector Interrupt Request
  VR <=   '0' when pSltIorq_n = '0' and pSltM1_n ='0'
     else '1';
  pSltBusdir_n <='0' when VR = '0'
            else 'Z';
-- One T wait
  process (CS_YM2148_n,pSltClc) 
    begin 
      if rstTWait = '1' then 
        TWait <= '0' ; 
      elsif CS_YM2148_n'event and CS_YM2148_n = '0' then 
        TWait <= '1' ; 
      end if ; 
    end process ;   
  process (CS_YM2148_n,pSltClc) 
    begin 
      if pSltClc'event and pSltClc = '0' then 
        rstTWait <= TWait ;
      end if ; 
    end process ;   
  pSltWait_n <= '0'  when TWait = '1'
           else 'Z';
-- conect YM2148
  C_2148  : YM2148
  port map(pSltAdr(2 downto 0),pSltDat,CS_YM2148_n,pSltRd_n,pSltWr_n,
             pSltInt_n,VR,pSltRst_n,pSltClc,pCrtClc,
             pCrtORM_n,pMidiTx,pMidiRx,pST,pSD);
  pMidiTx_n <= not pMidiTx;
end RTL;