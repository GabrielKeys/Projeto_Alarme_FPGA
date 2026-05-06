library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity tb_alarme_top is
end tb_alarme_top;

architecture Behavioral of tb_alarme_top is

    component alarme_top
        Port (
            clk        : in  STD_LOGIC;
            reset      : in  STD_LOGIC;
            botao_arm  : in  STD_LOGIC;

            zona1      : in  STD_LOGIC;
            zona2      : in  STD_LOGIC;
            zona3      : in  STD_LOGIC;
            zona4      : in  STD_LOGIC;
            zona5      : in  STD_LOGIC;

            esp_ok     : in  STD_LOGIC;

            sirene     : out STD_LOGIC;
            estrobo    : out STD_LOGIC;
            esp_alerta : out STD_LOGIC;
            esp_reset  : out STD_LOGIC;
            esp_zonas  : out STD_LOGIC_VECTOR(4 downto 0);

            leds_zona  : out STD_LOGIC_VECTOR(4 downto 0);
            display    : out STD_LOGIC_VECTOR(6 downto 0)
        );
    end component;

    signal clk        : STD_LOGIC := '0';
    signal reset      : STD_LOGIC := '0';
    signal botao_arm  : STD_LOGIC := '0';

    signal zona1      : STD_LOGIC := '0';
    signal zona2      : STD_LOGIC := '0';
    signal zona3      : STD_LOGIC := '0';
    signal zona4      : STD_LOGIC := '0';
    signal zona5      : STD_LOGIC := '0';

    signal esp_ok     : STD_LOGIC := '1';

    signal sirene     : STD_LOGIC;
    signal estrobo    : STD_LOGIC;
    signal esp_alerta : STD_LOGIC;
    signal esp_reset  : STD_LOGIC;
    signal esp_zonas  : STD_LOGIC_VECTOR(4 downto 0);

    signal leds_zona  : STD_LOGIC_VECTOR(4 downto 0);
    signal display    : STD_LOGIC_VECTOR(6 downto 0);

begin

    uut: alarme_top
        Port map (
            clk        => clk,
            reset      => reset,
            botao_arm  => botao_arm,

            zona1      => zona1,
            zona2      => zona2,
            zona3      => zona3,
            zona4      => zona4,
            zona5      => zona5,

            esp_ok     => esp_ok,

            sirene     => sirene,
            estrobo    => estrobo,
            esp_alerta => esp_alerta,
            esp_reset  => esp_reset,
            esp_zonas  => esp_zonas,

            leds_zona  => leds_zona,
            display    => display
        );

    -- Geração do clock
    clk_process : process
    begin
        while true loop
            clk <= '0';
            wait for 5 ns;
            clk <= '1';
            wait for 5 ns;
        end loop;
    end process;

    -- Estímulos de teste
    stim_proc : process
    begin

        -- Reset inicial
        reset <= '1';
        wait for 20 ns;
        reset <= '0';

        wait for 20 ns;

        -- Armar sistema
        botao_arm <= '1';
        wait for 30 ns;

        -- Violação da Zona 3
        zona3 <= '1';
        wait for 150 ns;

        -- ESP32 não confirma envio
        esp_ok <= '0';
        wait for 40 ns;

        -- Desarmar sistema
        botao_arm <= '0';
        zona3 <= '0';
        esp_ok <= '1';

        wait for 50 ns;

        wait;

    end process;

end Behavioral;