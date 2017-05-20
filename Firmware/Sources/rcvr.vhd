library ieee ; 
use ieee.std_logic_1164.all ; 
use ieee.std_logic_arith.all ; 
 
entity rcvr is 
    generic 
    ( 
--        databytes            : integer := 8;        -- ���. ��� ������ (5,6,7,8) 
--        stopbits      : integer := 1    -- ���. ���� ��� (1 ��� 2) 
       databytes	: integer	:= 8;         
       stopbits		: integer   := 1		   
    ) ; 
    port  
    ( 
        -- ����� ���� 
        rst         :    in std_logic ; 
        -- ����� ������
		rst_err		:    in std_logic ; 
        -- ������� ��� *16 
        clk128x    :    in std_logic ; 
        -- ���������������� ���� 
        rxd         :    in std_logic ; 
        -- ���������� ������ ������ (1) 
        rdn         :    in std_logic ; 
 
        -- �������� ������  
        dout     :    out std_logic_vector (databytes - 1 downto 0) ; 
        -- ������ ������ (rising edge) 
        data_ready     :    out std_logic; 
		-- ������������ ������ (�� ������ ������� ����)
        err_overrun	 :  out std_logic;
        -- ��� ��������� ���� (������ �����������, ����� �����)
        err_framing	 :  out std_logic  
    ) ; 
end rcvr ; 
 
architecture v1 of rcvr is 
 
    -- ������� �������������� ������ 
    function revers_inv (iv_data : in unsigned (databytes - 1 downto 0)) return unsigned is 
        variable sv_return : unsigned (databytes - 1 downto 0):=(others => '0'); 
    begin 
    for i in 0 to databytes - 1  
        loop 
            sv_return(i):=iv_data(databytes - 1 - i); 
        end loop; 
    return sv_return; 
    end revers_inv; 
 
    -- ������� �������� ������  
    signal rxd1                 : std_logic ; 
    signal rxd2                 : std_logic ; 
    -- ������������� �������� ��������� 
    signal clk1x_enable : std_logic ; 
    -- ������� ��������� 
    signal clkdiv             : unsigned (6 downto 0) ; 
    -- ����� ������ 
    signal rsr                     : unsigned (databytes - 1 downto 0) ; 
    -- ����� ���������� 
    signal rbr                     : unsigned (databytes - 1 downto 0) ; 
    -- ������� ��������� ��������� 
    signal no_bits_rcvd : unsigned (3 downto 0) ; 
    -- ������� ���*2 
    signal clk1x                 : std_logic ;
	-- ����� ������
    signal rste					: std_logic; 
    signal dr					: std_logic;
	signal rstb					: std_logic;
	signal e_overrun			: std_logic;
	signal e_framing			: std_logic;
begin 
 
-- �����������  
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
 
-- ������������ ������ clk1x_enable 
process (rstb,clk128x,rxd1,rxd2,no_bits_rcvd) 
begin 
    -- ���� no_bits_rcvd ��������� � ��������� (databytes + stopbits + 1) 
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
 
-- �������� �� 16 (�������� ��� rst = '0') 
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
-- ��������� ������� ��� 
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
        -- �������� ������ � ������� rbr (����� ����������) 
        elsif conv_integer(no_bits_rcvd) = databytes + stopbits then 
            -- ������ ����� 
            rbr <= revers_inv(rsr) ; 
--            rbr <= rsr ; 
        end if ; 
    end if ; 
end process ; 
 
-- ��������� no_bits_rcvd ���� rst = '1' ��� (no_bits_rcvd) = 11 
-- � ���� no_bits_rcvd ���� clk1x_enable = '1'    
process (rstb,clk1x,clk1x_enable,no_bits_rcvd) 
begin 
--  if rstb = '1' or (conv_integer(no_bits_rcvd) = databytes + stopbits + 1 and clk1x_enable = '0') then 
--  if rstb = '1' or clk1x_enable = '0' then 
    if rstb = '1' or (clk1x_enable = '0' and conv_integer(no_bits_rcvd) = databytes + stopbits
                     )-- and clk1x = '1' and clkdiv(0) = '1')    
    then        
        no_bits_rcvd <= "0000" ; 
        -- ���� no_bits_rcvd �� ����� 
    elsif clk1x'event and clk1x = '0' then 
        if clk1x_enable = '1' then 
            no_bits_rcvd <= no_bits_rcvd + 1 ; 
        end if ; 
    end if ; 
end process ; 
 
-- �������� ������ ����� rdn = '0'  
-- dout <= std_logic_vector(rbr) when rdn = '1' else (others => 'Z') ; 
   dout <= std_logic_vector(rbr);
-- ���������� ������
process (clk1x_enable,rdn) 
begin 
    if rdn = '1' or rstb = '1' then 
	   dr <= '0';
    elsif clk1x_enable'event and clk1x_enable = '0' then 
	   dr <= '1';   
    end if ; 
end process ;

data_ready <= dr ;

-- ������
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