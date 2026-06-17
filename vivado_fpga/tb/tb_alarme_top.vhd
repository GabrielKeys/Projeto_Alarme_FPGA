library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity tb_alarme_top is
end tb_alarme_top;

architecture Behavioral of tb_alarme_top is

    component alarme_top
        Generic (
            CLK_FREQ_HZ         : integer;
            TEMPO_CONTAGEM_S    : integer;
            TEMPO_TIMEOUT_ESP_S : integer
        );
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

    -- Valores reduzidos so para a simulacao rodar rapido.
    -- Em hardware real, a entidade usa os valores padrao (100 MHz / 10 s / 5 s).
    constant CLK_FREQ_HZ_SIM         : integer := 10;  -- 10 ciclos = "1 segundo" simulado
    constant TEMPO_CONTAGEM_S_SIM    : integer := 5;   -- 50 ciclos = 500 ns para confirmar
    constant TEMPO_TIMEOUT_ESP_S_SIM : integer := 3;   -- 30 ciclos = 300 ns de timeout

begin

    uut: alarme_top
        Generic map (
            CLK_FREQ_HZ         => CLK_FREQ_HZ_SIM,
            TEMPO_CONTAGEM_S    => TEMPO_CONTAGEM_S_SIM,
            TEMPO_TIMEOUT_ESP_S => TEMPO_TIMEOUT_ESP_S_SIM
        )
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

    -- Geracao do clock (periodo 10 ns)
    clk_process : process
    begin
        while true loop
            clk <= '0';
            wait for 5 ns;
            clk <= '1';
            wait for 5 ns;
        end loop;
    end process;

    -- Estimulos de teste
    stim_proc : process
    begin

        -- Reset inicial
        reset <= '1';
        wait for 20 ns;
        reset <= '0';

        wait for 20 ns;

        -- Arma o sistema
        botao_arm <= '1';
        wait for 30 ns;

        -- ===== Cenario 1: falso-positivo =====
        -- Zona 3 e violada por pouco tempo (200 ns), bem menos que os
        -- 500 ns necessarios para confirmar (TEMPO_CONTAGEM_S_SIM=5 -> 50 ciclos).
        -- Esperado: ARMADO -> CONTAGEM -> ARMADO (sem sirene, sem estrobo, sem esp_alerta).
        zona3 <= '1';
        wait for 200 ns;
        zona3 <= '0';
        wait for 100 ns;

        -- ===== Cenario 2: violacao confirmada =====
        -- Zona 3 e violada e permanece ativa por mais tempo que o necessario
        -- para confirmar (600 ns > 500 ns).
        -- Esperado: ARMADO -> CONTAGEM -> DISPARO (sirene, estrobo e esp_alerta em '1').
        zona3 <= '1';
        wait for 600 ns;

        -- ESP32 nao confirma o recebimento do alerta
        esp_ok <= '0';
        wait for 350 ns; -- maior que o timeout (300 ns) -> RESET_ESP

        -- Desarma o sistema manualmente
        botao_arm <= '0';
        zona3 <= '0';
        esp_ok <= '1';

        wait for 50 ns;

        wait;

    end process;

end Behavioral;
