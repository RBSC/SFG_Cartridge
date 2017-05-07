library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;

entity YM2148 is
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
  );
end YM2148;
architecture RTL of YM2148 is
  

  component txmit
    port  
    ( 
        -- общий срос 
        rst         : in std_logic ; 
        -- -- частота бод *16 
        clk128x     : in std_logic ; 
        -- загрузка данных в буфер на передачу (falling edge) 
        wrn         : in std_logic ; 
        -- входные данные 
        din          : in std_logic_vector(7 downto 0) ;  
        -- буфер передатчика пуст 
        tbre         : out std_logic ;  
        -- выход передатчика 
        txd          : out std_logic  
        -- выход сигнала rts (для rs485)     
   --     rts          : out std_logic   
    );
  end component;  
  
  component rcvr
    port  
    ( 
        -- общий срос 
        rst         :    in std_logic ; 
        -- cброс ошибок
		rst_err		:    in std_logic ; 
        -- частота бод *16 
        clk128x    :    in std_logic ; 
        -- последовательный вход 
        rxd         :    in std_logic ; 
        -- разрешение чтения данных (1) 
        rdn         :    in std_logic ; 
 
        -- выходные данные  
        dout     :    out std_logic_vector (7 downto 0) ; 
        -- данные готовы (rising edge) 
        data_ready     :    out std_logic; 
		-- переполнение буфера (не успели считать байт)
        err_overrun	 :  out std_logic;
        -- нет стопового бита (ошибка разрядности, обрыв линии)
        err_framing	 :  out std_logic
    ) ;
  end component;  
  
  
  
  signal CLC_n		   : std_logic;
--  signal RD_hT1	   : std_logic;
--  signal RD_hT2	   : std_logic;

--  signal WR_hT1    : std_logic;
--  signal WR_hT2    : std_logic;

  signal rdtn	   : std_logic;
  
  signal IntVMidi  : std_logic_vector(7 downto 0);
  signal IntVExtr  : std_logic_vector(7 downto 0);
--  signal MIDI_CR   : std_logic_vector(7 downto 0);
  signal TxEN	   : std_logic;
  signal TxIE	   : std_logic;
  signal RxEN	   : std_logic;
  signal RxIE	   : std_logic;
  signal IR	   : std_logic;
  signal ER	   : std_logic;
  signal KeybST    : std_logic_vector(7 downto 0);
  signal MIDI_Drx  : std_logic_vector(7 downto 0);
  signal rsttx	   : std_logic;
  signal rstrx	   : std_logic;
--  signal clcdiv8   : std_logic_vector(2 downto 0);
  signal Intrx	   : std_logic;
  signal Inttx	   : std_logic;
  signal Int       : std_logic;
  signal IntO	   : std_logic;
  signal ResInt	   : std_logic;
  signal wrn	   : std_logic;
  signal rdn	   : std_logic;
  signal trbe 	   : std_logic;
  signal data_ready  : std_logic;
  signal err_overrun : std_logic;
  signal err_framing : std_logic;
  signal RstItx		: std_logic;
  signal RstIrx		: std_logic;
begin
  ----------------------------------------------------------------
  -- OPM Chip address decode
  ----------------------------------------------------------------
    pCrtORM_n <= '0' when CS_n = '0' and pSltAdr(2 downto 1) = "00" 
			else '1';
  ----------------------------------------------------------------
  -- Adapt timing, jitter suppression
  ----------------------------------------------------------------
  CLC_n		<= not pSltClc;
--  process(pSltRst_n, CLC_n, pSltRd_n)
--  begin
--    if (pSltRd_n = '1') then
--      RD_hT1 <= '0';
--    elsif (RD_hT2 = '0') then
--      if (pSltRd_n = '0' and CLC_n = '0' and CS_n = '0') then
--        RD_hT1 <= '1';
--      end if;
--    end if;
--   if (CLC_n'event and CLC_n = '1') then
--      RD_hT2 <= not pSltRd_n;
--    end if;
--  end process;
--  
--    process(pSltRst_n, CLC_n)
--  begin
--    if (pSltRst_n = '0') then
--      WR_hT2 <= '0';
--    elsif (CLC_n'event and CLC_n = '0') then
--      WR_hT2 <= WR_hT1;
--   end if;
--  end process;
--  
-- 
-- process(pSltWr_n,WR_hT2)
--  begin
--    if (pSltWr_n = '1') then
--      WR_hT1 <= '0';
--    elsif (WR_hT2 = '0') then
--      if (pSltWr_n = '0' and CS_n = '0') then
--        WR_hT1 <= '1';
--      end if;
--    end if;
--  end process;
  

  ----------------------------------------------------------------
  -- Set Register (Command register)
  ----------------------------------------------------------------
 process(CLC_n, pSltRst_n)
  begin
    if (pSltRst_n = '0') then
         TxEN <= '0'; TxIE <= '0'; RxEN <= '0'; RxIE <= '0';
         IntVMidi <= "11111111" ; IntVExtr <= "11111111";
    elsif (CLC_n'event and CLC_n = '1') then
      if (CS_n = '0' and pSltWr_n = '0' ) then 
        if (pSltAdr(2 downto 0) = "010") then KeybST	<= not pSltDat ; end if;
        if (pSltAdr(2 downto 0) = "011") then IntVMidi  <= pSltDat ; end if;
        if (pSltAdr(2 downto 0) = "100") then IntVExtr  <= pSltDat ; end if;         
--        if (pSltAdr(2 downto 0) = "101") then MIDI_Dtx  <= pSltDat ; end if;
		if (pSltAdr(2 downto 0) = "110") then 
--		  MIDI_CR   <= pSltDat ; 
		  TxEN <= pSltDat(0);
		  TxIE <= pSltDat(1);
		  RxEN <= pSltDat(2);
		  RxIE <= pSltDat(3);
		end if;  
      end if;
    end if;
end process;
  ----------------------------------------------------------------
  -- Reset bits Command register
  ----------------------------------------------------------------
  ER	<=	 '1' when pSltAdr(2 downto 0) = "110" and CS_n = '0' 
                      and pSltWr_n = '0' and pSltDat(4) = '1'
		else '0';
  IR	<=	 '1' when pSltAdr(2 downto 0) = "110" and CS_n = '0' 
                      and pSltWr_n = '0' and pSltDat(7) = '1'
		else '0';
  ----------------------------------------------------------------
  -- Keyboard port out
  ----------------------------------------------------------------
	pST <= KeybST;
  ----------------------------------------------------------------
  -- MIDI CLC divider ( 4 Mhz / 8 )
  ----------------------------------------------------------------
--process (pCrtClc) 
--begin 
--   if pCrtClc'event and pCrtClc = '1' then 
--        clcdiv8 <= clcdiv8 + "001" ; 
--    end if ; 
--end process ; 
  ----------------------------------------------------------------
  -- MIDI UART Tx
  ----------------------------------------------------------------
    UART_TX  : txmit
    port map(rsttx,pCrtClc,wrn,pSltDat,trbe,pMidiTx);
	rsttx  <=  '1' when pSltRst_n = '0' or TxEN = '0' or IR = '1'
		  else '0';
	wrn	   <=  '1' when pSltAdr(2 downto 0) = "101" and CS_n = '0' and pSltWr_n = '0' -- WR_hT1 = '1'
	      else '0';
  ----------------------------------------------------------------
  -- MIDI UART Rx
  ----------------------------------------------------------------	
    UART_RX  : rcvr
    port map(rstrx,ER,pCrtClc,pMidiRx,rdn,MIDI_Drx,data_ready,err_overrun,err_framing);
	rstrx  <=  '1' when pSltRst_n = '0' or RxEN = '0' or IR = '1'
		  else '0';  
  	rdn	   <=  '1' when pSltAdr(2 downto 0) = "101" and CS_n = '0' and pSltRd_n = '0'-- RD_hT1 = '1'
	      else '0';
  ----------------------------------------------------------------
  -- Interupt
  ----------------------------------------------------------------	 	
    pSltInt_n <= '0' when Int = '1'
            else 'Z';
    Int       <= '1' when Intrx = '1' or Inttx = '1'
            else '0';
--	Int <= '0';
--    ResInt <= '0' when VInt_n = '0' or pSltRst_n ='0' 
--         else '1';
--    process(Int,ResInt)
--	begin
--	  if ResInt = '0' then IntO <= '0';
--	  elsif Int'event and Int = '1' then
--	    IntO <= '1';
--	  end if;
--	end process;       

  Inttx <= trbe when TxIE = '1' -- and TxEN = '1' 
	  else '0';
--process(trbe, RstItx)
--  begin
--    if (rsttx = '0') then
--         Inttx   <= '0';
--    elsif (trbe'event and trbe = '1') then   
--         Inttx   <= '1';  
--    end if;
--end process;
	RstItx <=	'1' when wrn = '1' or TxIE = '0'
	      else  '0';
  Intrx <= data_ready when  RxIE = '1'	--  and RxEN = '1'
  	       else '0'; 
--process(data_ready, RstIrx)
--  begin
--    if (rstrx = '0') then
--         Intrx   <= '0';
--    elsif (data_ready'event and data_ready = '1') then   
--         Intrx   <= '1';  
--    end if;
--end process;
	RstIrx <=	'1' when RxIE = '0' or rdn = '1'
	      else  '0' ;           
  ----------------------------------------------------------------
  -- MSX Data read
  ----------------------------------------------------------------	
    pSltDat	 <=	 MIDI_Drx when pSltAdr(2 downto 0) = "101" and pSltRd_n = '0' and CS_n = '0' -- MIDI UART
		    else pSD      when pSltAdr(2 downto 0) = "010" and pSltRd_n = '0' and CS_n = '0' -- Keyboard
			else "10000001" when pSltAdr(2 downto 0) = "011" and pSltRd_n = '0' and CS_n = '0' -- 81h
			else "10000001" when pSltAdr(2 downto 0) = "100" and pSltRd_n = '0' and CS_n = '0' -- 81h
            else '0' & '0' & err_framing & err_overrun & '0' & '1' & data_ready & trbe 
                          when pSltAdr(2 downto 0) = "110" and pSltRd_n = '0' and CS_n = '0' -- Status register
            else IntVMidi when VInt_n = '0' and Int = '1' -- Vector MIDI UART
			else IntVExtr when VInt_n = '0' and Int = '0' -- Vector external
    		else (others => 'Z');  
	
end RTL;