library ieee ; 
use ieee.std_logic_1164.all ; 
use ieee.std_logic_arith.all ; 
 
entity rcvr is 
    generic 
    ( 
--        databytes            : integer := 8;        -- кол. бит данных (5,6,7,8) 
--        stopbits      : integer := 1    -- кол. стоп бит (1 или 2) 
       databytes	: integer	:= 8;         
       stopbits		: integer   := 1		   
    ) ; 
    port  
    ( 
        -- общий срос 
        rst         :    in std_logic ; 
        -- сброс ошибок
		rst_err		:    in std_logic ; 
        -- частота бод *16 
        clk128x    :    in std_logic ; 
        -- последовательный вход 
        rxd         :    in std_logic ; 
        -- разрешение чтения данных (1) 
        rdn         :    in std_logic ; 
 
        -- выходные данные  
        dout     :    out std_logic_vector (databytes - 1 downto 0) ; 
        -- данные готовы (rising edge) 
        data_ready     :    out std_logic; 
		-- переполнение буфера (не успели считать байт)
        err_overrun	 :  out std_logic;
        -- нет стопового бита (ошибка разрядности, обрыв линии)
        err_framing	 :  out std_logic  
    ) ; 
end rcvr ; 
 
architecture v1 of rcvr is 
 
    -- функция инвертирования данных 
    function revers_inv (iv_data : in unsigned (databytes - 1 downto 0)) return unsigned is 
        variable sv_return : unsigned (databytes - 1 downto 0):=(others => '0'); 
    begin 
    for i in 0 to databytes - 1  
        loop 
            sv_return(i):=iv_data(databytes - 1 - i); 
        end loop; 
    return sv_return; 
    end revers_inv; 
 
    -- битовые приемные буфера  
    signal rxd1                 : std_logic ; 
    signal rxd2                 : std_logic ; 
    -- разблокировка счетчика приемника 
    signal clk1x_enable : std_logic ; 
    -- счетчик приемника 
    signal clkdiv             : unsigned (6 downto 0) ; 
    -- буфер сдвига 
    signal rsr                     : unsigned (databytes - 1 downto 0) ; 
    -- буфер результата 
    signal rbr                     : unsigned (databytes - 1 downto 0) ; 
    -- счетчик состояний приемника 
    signal no_bits_rcvd : unsigned (3 downto 0) ; 
    -- частота бод*2 
    signal clk1x                 : std_logic ;
	-- сброс ошибок
    signal rste					: std_logic; 
    signal dr					: std_logic;
	signal rstb					: std_logic;
	signal e_overrun			: std_logic;
	signal e_framing			: std_logic;
begin 
 
-- буферизация  
process (rstb,clk128x) 
begin 
    if rstb = '1' then 
        rxd1 <= '1' ; 
        rxd2 <= '1' ; 
    elsif clk128x'event and clk128x = '1' then 
        rxd2 <= rxd1 ; 
        rxd1 <= rxd ; 
    end if ; 
end process ; 
 
-- формирование строба clk1x_enable 
process (rstb,clk128x,rxd1,rxd2,no_bits_rcvd) 
begin 
    -- если no_bits_rcvd находится в положении (databytes + stopbits + 1) 
--  if rstb = '1' or conv_integer(no_bits_rcvd) = databytes + stopbits + 1 then 
    if rstb = '1' or (conv_integer(no_bits_rcvd) = databytes + stopbits
                      and clk1x = '1' and clkdiv(0) = '1') then 
        clk1x_enable <= '0' ; 
    elsif clk128x'event and clk128x = '1' then 
        if rxd1 = '0' and rxd2 = '1' then 
            clk1x_enable <= '1' ; 
        end if ; 
    end if ; 
end process  ; 
 
-- data_ready <= not clk1x_enable ; 
 
-- делитель на 16 (работает при rst = '0') 
process (rstb,clk128x,clk1x_enable) 
begin 
--  if rstb = '1' then 
    if rstb = '1' or (clk1x_enable = '0' and conv_integer(no_bits_rcvd) = databytes + stopbits) then
        clkdiv <= "0000000" ; 
    elsif clk128x'event and clk128x = '0' then 
        if clk1x_enable = '1' then 
            clkdiv <= clkdiv + "0000001" ; 
        end if ; 
    end if ; 
end process ; 
-- удвоенная частота бод 
clk1x <= clkdiv(6) ; 
rstb <= '1' when rst = '1' -- or e_overrun = '1' or e_framing = '1'
   else '0' ;
process (clk1x,rstb) 
begin 
    if rstb = '1' then 
        rsr <= (others => '0'); 
        rbr <= (others => '0') ; 
    elsif clk1x'event and clk1x = '1' then 
        if conv_integer(no_bits_rcvd) >= 1 and conv_integer(no_bits_rcvd) <= databytes then 
            rsr(0) <= rxd2 ; 
            rsr(databytes - 1 downto 1) <= rsr(databytes - 2 downto 0) ; 
        -- перепись данных в регистр rbr (буфер результата) 
        elsif conv_integer(no_bits_rcvd) = databytes + stopbits then 
            -- реверс битов 
            rbr <= revers_inv(rsr) ; 
--            rbr <= rsr ; 
        end if ; 
    end if ; 
end process ; 
 
-- обнуление no_bits_rcvd если rst = '1' или (no_bits_rcvd) = 11 
-- и счет no_bits_rcvd если clk1x_enable = '1'    
process (rstb,clk1x,clk1x_enable,no_bits_rcvd) 
begin 
--  if rstb = '1' or (conv_integer(no_bits_rcvd) = databytes + stopbits + 1 and clk1x_enable = '0') then 
--  if rstb = '1' or clk1x_enable = '0' then 
    if rstb = '1' or (clk1x_enable = '0' and conv_integer(no_bits_rcvd) = databytes + stopbits
                     )-- and clk1x = '1' and clkdiv(0) = '1')    
    then        
        no_bits_rcvd <= "0000" ; 
        -- счет no_bits_rcvd по спаду 
    elsif clk1x'event and clk1x = '0' then 
        if clk1x_enable = '1' then 
            no_bits_rcvd <= no_bits_rcvd + 1 ; 
        end if ; 
    end if ; 
end process ; 
 
-- выходные данные когда rdn = '0'  
-- dout <= std_logic_vector(rbr) when rdn = '1' else (others => 'Z') ; 
   dout <= std_logic_vector(rbr);
-- готовность данных
process (clk1x_enable,rdn) 
begin 
    if rdn = '1' or rstb = '1' then 
	   dr <= '0';
    elsif clk1x_enable'event and clk1x_enable = '0' then 
	   dr <= '1';   
    end if ; 
end process ;

data_ready <= dr ;

-- ошибки
rste <= '1' when rst = '1' or rst_err = '1' --or rdn = '1'
	 else '0';

process (clk1x,rste) 
begin 
    if rste = '1' then 
       e_framing <= '0';
    elsif clk1x'event and clk1x = '1' then 
	   if (conv_integer(no_bits_rcvd) = databytes + stopbits)	and rxd2 = '0' then
          e_framing <= '1';
       end if ;    
    end if ; 
end process ; 
process (clk1x,rste) 
begin 
    if rste = '1' then 
	   e_overrun <= '0';
    elsif clk1x'event and clk1x = '1' then 
	   if dr = '1' and conv_integer(no_bits_rcvd) = databytes + stopbits then
          e_overrun <= '1';
       end if ;    
    end if ; 
end process ; 

 err_overrun <= e_overrun;
 err_framing <= e_framing;
---------------------------------------------------------------------- 
 
end ; 