library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity alarme_top is
    Generic (
        -- Frequencia do clock da placa (Basys 3 = 100 MHz por padrao)
        CLK_FREQ_HZ         : integer := 100000000;

        -- Tempo de confirmacao da violacao antes do disparo (reducao de falso-positivo)
        TEMPO_CONTAGEM_S    : integer := 10;

        -- Tempo de espera pela confirmacao (esp_ok) antes de resetar o ESP32
        TEMPO_TIMEOUT_ESP_S : integer := 5
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
end alarme_top;

architecture Behavioral of alarme_top is

    -- Estado CONTAGEM restaurado: e a etapa responsavel pela reducao de
    -- falso-positivo (uma violacao so e considerada real se permanecer
    -- ativa por TEMPO_CONTAGEM_S segundos seguidos).
    type estado_t is (DESARMADO, ARMADO, CONTAGEM, DISPARO, RESET_ESP);
    signal estado_atual : estado_t := DESARMADO;

    signal zonas        : STD_LOGIC_VECTOR(4 downto 0);
    signal zona_violada : STD_LOGIC;
    signal zona_memoria : STD_LOGIC_VECTOR(4 downto 0) := "00000";

    -- Contador de ciclos de clock (0 a CLK_FREQ_HZ-1 = 1 segundo real)
    signal contador_clk      : integer range 0 to CLK_FREQ_HZ - 1 := 0;

    -- Contador de segundos. Faixa fixa com margem confortavel para os
    -- dois tempos usados (CONTAGEM e TIMEOUT_ESP); ajuste se precisar
    -- de tempos maiores que 1023 segundos.
    signal contador_segundos : integer range 0 to 1023 := 0;

    signal esp_ok_recebido : STD_LOGIC := '0';

begin

    -- Ordem do vetor: zona5 zona4 zona3 zona2 zona1
    zonas <= zona5 & zona4 & zona3 & zona2 & zona1;

    zona_violada <= zona1 or zona2 or zona3 or zona4 or zona5;

    process(clk, reset)
    begin
        if reset = '1' then
            estado_atual <= DESARMADO;
            zona_memoria <= "00000";

            contador_clk <= 0;
            contador_segundos <= 0;
            esp_ok_recebido <= '0';

        elsif rising_edge(clk) then

            case estado_atual is

                when DESARMADO =>
                    zona_memoria <= "00000";

                    contador_clk <= 0;
                    contador_segundos <= 0;
                    esp_ok_recebido <= '0';

                    if botao_arm = '1' then
                        estado_atual <= ARMADO;
                    else
                        estado_atual <= DESARMADO;
                    end if;


                when ARMADO =>
                    contador_clk <= 0;
                    contador_segundos <= 0;
                    esp_ok_recebido <= '0';

                    if botao_arm = '0' then
                        estado_atual <= DESARMADO;
                        zona_memoria <= "00000";

                    elsif zona_violada = '1' then
                        -- Memoriza a zona no instante em que a violacao comecou
                        -- e passa a confirmar antes de disparar.
                        zona_memoria <= zonas;
                        estado_atual <= CONTAGEM;

                    else
                        estado_atual <= ARMADO;
                    end if;


                when CONTAGEM =>
                    if botao_arm = '0' then
                        estado_atual <= DESARMADO;
                        zona_memoria <= "00000";

                        contador_clk <= 0;
                        contador_segundos <= 0;

                    elsif zona_violada = '0' then
                        -- A violacao nao se manteve: trata como falso-positivo
                        -- e volta a vigiar sem acionar sirene/estrobo/ESP32.
                        estado_atual <= ARMADO;
                        zona_memoria <= "00000";

                        contador_clk <= 0;
                        contador_segundos <= 0;

                    else
                        if contador_segundos >= TEMPO_CONTAGEM_S then
                            estado_atual <= DISPARO;
                            contador_clk <= 0;
                            contador_segundos <= 0;

                        elsif contador_clk = CLK_FREQ_HZ - 1 then
                            contador_clk <= 0;
                            contador_segundos <= contador_segundos + 1;
                        else
                            contador_clk <= contador_clk + 1;
                        end if;
                    end if;


                when DISPARO =>
                    if botao_arm = '0' then
                        estado_atual <= DESARMADO;
                        zona_memoria <= "00000";

                        contador_clk <= 0;
                        contador_segundos <= 0;
                        esp_ok_recebido <= '0';

                    else
                        -- Se o ESP32 respondeu, registra confirmacao
                        if esp_ok = '1' then
                            esp_ok_recebido <= '1';
                            contador_clk <= 0;
                            contador_segundos <= 0;

                        -- Se ainda nao recebeu esp_ok, conta o timeout configurado
                        elsif esp_ok_recebido = '0' then

                            if contador_segundos >= TEMPO_TIMEOUT_ESP_S then
                                estado_atual <= RESET_ESP;
                                contador_clk <= 0;
                                contador_segundos <= 0;

                            else
                                if contador_clk = CLK_FREQ_HZ - 1 then
                                    contador_clk <= 0;
                                    contador_segundos <= contador_segundos + 1;
                                else
                                    contador_clk <= contador_clk + 1;
                                end if;
                            end if;

                        else
                            estado_atual <= DISPARO;
                        end if;
                    end if;


                when RESET_ESP =>
                    if botao_arm = '0' then
                        estado_atual <= DESARMADO;
                        zona_memoria <= "00000";

                        contador_clk <= 0;
                        contador_segundos <= 0;
                        esp_ok_recebido <= '0';
                    else
                        estado_atual <= RESET_ESP;
                    end if;

            end case;

        end if;
    end process;


    process(estado_atual, zona_memoria, esp_ok_recebido)
    begin
        sirene     <= '0';
        estrobo    <= '0';
        esp_alerta <= '0';
        esp_reset  <= '0';
        esp_zonas  <= "00000";
        leds_zona  <= "00000";
        display    <= "1111111";

        case estado_atual is

            when DESARMADO =>
                display <= "0100001"; -- d


            when ARMADO =>
                display <= "0001000"; -- A


            when CONTAGEM =>
                -- Ainda nao dispara: so mostra qual zona esta sendo confirmada.
                -- Sirene, estrobo e esp_alerta continuam em '0' propositalmente,
                -- isso e o que evita o falso-positivo virar alarme de fato.
                display   <= "1000110"; -- C
                leds_zona <= zona_memoria;


            when DISPARO =>
                display    <= "1000001"; -- U
                sirene     <= '1';
                estrobo    <= '1';
                esp_alerta <= '1';
                esp_reset  <= '0';

                esp_zonas  <= zona_memoria;
                leds_zona  <= zona_memoria;

                -- Indicacao visual de esp_ok recebido
                -- Acende leds_zona[4] se o ESP32 confirmou
                if esp_ok_recebido = '1' then
                    leds_zona(4) <= '1';
                end if;


            when RESET_ESP =>
                display    <= "1000001"; -- U
                sirene     <= '1';
                estrobo    <= '1';
                esp_alerta <= '1';
                esp_reset  <= '1';

                esp_zonas  <= zona_memoria;
                leds_zona  <= zona_memoria;

        end case;
    end process;

end Behavioral;
