 
library ieee ; 
use ieee.std_logic_1164.all ; 
use ieee.std_logic_arith.all ; 
 
entity txmit is 
    generic 
    ( 
        databytes            : integer := 8 ;         -- кол. бит данных (5,6,7,8) 
        stopbits      : integer := 1            -- кол. стоп бит (1 или 2) 
    ) ; 
    port  
    ( 
        -- общий срос 
        rst         : in std_logic ; 
        -- -- частота бод *16 
        clk128x     : in std_logic ; 
        -- загрузка данных в буфер на передачу (falling edge) 
        wrn         : in std_logic ; 
        -- входные данные 
        din          : in std_logic_vector(databytes - 1 downto 0) ;  
        -- буфер передатчика пуст 
        tbre         : out std_logic ;  
        -- выход передатчика 
        txd          : out std_logic 
        -- выход сигнала rts (для rs485)     
 --       rts          : out std_logic   
    ); 
end txmit ; 
 
architecture v1 of txmit is 
 
    -- функция инвертирования данных 
    function revers_inv (iv_data : in std_logic_vector(databytes - 1 downto 0)) return std_logic_vector is 
        variable sv_return : std_logic_vector(databytes - 1 downto 0):=(others => '0'); 
    begin 
    for i in 0 to databytes - 1  
        loop 
            sv_return(i):= iv_data(databytes - 1 - i); 
        end loop; 
    return sv_return; 
    end revers_inv; 
 
    -- разблокировка счетчика передатчика  
    signal clk1x_enable : std_logic ; 
    -- передающий буфер  
    signal tsr : std_logic_vector (databytes - 1 downto 0) ; 
    -- буфер для загрузки данных 
    signal tbr : std_logic_vector (databytes - 1 downto 0) ; 
    -- счетчик передатчика 
    signal clkdiv :  unsigned (6 downto 0) ; 
    -- частота бод 
    signal clk1x :  std_logic ; 
    -- счетчик состояний передатчика 
    signal no_bits_sent :  unsigned (3 downto 0); 
    -- битовый буфер  
    signal wrn1 :  std_logic ; 
    -- битовый буфер 2 
    signal wrn2 :  std_logic ; 
 
begin 
 
-- старт передачи фрейма 
process (rst,clk128x) 
begin 
    if rst = '1' then 
        wrn1 <= '1' ; 
        wrn2 <= '1' ; 
    elsif clk128x'event and clk128x = '1' then 
        wrn2 <= wrn1 ; 
        wrn1 <= wrn ; 
    end if ; 
end process ; 
 
-- строб работы передатчика 
process (rst,clk128x) 
begin 
    if rst = '1' then 
        clk1x_enable <= '0' ; 
--        tbre <= '1' ; -- 0
    elsif clk128x'event and clk128x = '0' then 
        if wrn1 = '0' and wrn2 = '1' then  
--            tbre <= '1' ; -- 0
            clk1x_enable <= '1' ; 
        elsif conv_integer(no_bits_sent) = 2 then 
--            tbre <= '1'; 
        elsif conv_integer(no_bits_sent) = databytes + stopbits + 3 and clk1x = '0' then 
            clk1x_enable <= '0' ; 
        end if ; 
    end if ; 
end process ; 
 
tbre <= not  clk1x_enable;
-- rts <= clk1x_enable ; 
 
 
-- загрузка данных в буфер tbr 
process (rst,wrn,clk1x_enable) 
begin 
    if rst = '1' then 
        tbr <= (others => '0') ; 
    elsif wrn'event and wrn = '0' then 
--        tbr <= din; 
        tbr <= revers_inv(din); 
    end if ; 
end process ; 
 
-- формирование удвоенной частоты бод clk1x 
process (rst,clk128x,clk1x_enable) 
begin 
    if rst = '1' then 
        clkdiv <=  "0000000" ; 
    elsif clk128x'event and clk128x = '1' then 
        if clk1x_enable = '1' then 
            clkdiv <= clkdiv + "0000001" ; 
        else 
            clkdiv <= "0000000" ;     
        end if ; 
    end if ; 
end process ; 
 
clk1x <= clkdiv(6) ; 
 
-- последовательная передача  
process (rst,clk1x,no_bits_sent,tbr) 
begin 
    if rst = '1' then  
        txd <= '1' ; 
        tsr <= (others => '0'); 
    elsif clk1x'event and clk1x = '0' then 
        -- перегрузка данных из приемного буфера в передающий (из tbr в tsr)     
        if conv_integer(no_bits_sent) = 1 then 
            tsr <=  tbr; 
        -- стартовый бит     
        elsif conv_integer(no_bits_sent) = 2 then 
            txd <= '0' ; 
        -- txd передача     
        elsif conv_integer(no_bits_sent) >= 3 and conv_integer(no_bits_sent) <= databytes + 2 then 
            tsr  <= tsr(databytes - 2 downto 0) & '0' ; 
            txd <= tsr(databytes - 1) ; 
        -- стоповый бит (1 или 2)     
        elsif conv_integer(no_bits_sent) = databytes + 3 then 
            txd <= '1' ; 
        end if ; 
    end if ; 
end process ; 
 
-- счет no_bits_sent при clk1x_enable = '1' 
process (rst,clk1x,clk1x_enable) 
begin 
    if rst = '1' or clk1x_enable = '0' then 
        no_bits_sent <= "0000" ; 
    elsif clk1x'event and clk1x = '1' then 
        if clk1x_enable = '1' then 
            no_bits_sent <= no_bits_sent + "0001" ; 
        end if ; 
    end if ; 
end process ; 
---------------------------------------------------------------------- 
 
end ; 