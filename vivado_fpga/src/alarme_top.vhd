library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity alarme_top is
    Port (
        clk        : in  STD_LOGIC;
        reset      : in  STD_LOGIC;
        botao_arm  : in  STD_LOGIC;

        zona1      : in  STD_LOGIC;
        zona2      : in  STD_LOGIC;
        zona3      : in  STD_LOGIC;
        zona4      : in  STD_LOGIC;
        zona5      : in  STD_LOGIC;

        -- SW6 a SW12
        -- tempo programavel de 0 a 120 segundos
        tempo_prog : in  STD_LOGIC_VECTOR(6 downto 0);

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

    type estado_t is (DESARMADO, ARMADO, CONTAGEM, DISPARO, RESET_ESP);
    signal estado_atual : estado_t := DESARMADO;

    signal zonas        : STD_LOGIC_VECTOR(4 downto 0);
    signal zona_violada : STD_LOGIC;
    signal zona_memoria : STD_LOGIC_VECTOR(4 downto 0) := "00000";

    -- Clock da Basys 3 = 100 MHz
    -- 100.000.000 ciclos = 1 segundo

    -- Contador do tempo programavel pos-violacao
    signal contador_clk_contagem : integer range 0 to 100000000 := 0;
    signal contador_seg_contagem : integer range 0 to 120 := 0;

    -- Contador do watchdog do ESP32
    signal contador_clk_watchdog : integer range 0 to 100000000 := 0;
    signal contador_seg_watchdog : integer range 0 to 5 := 0;

    signal esp_ok_recebido : STD_LOGIC := '0';

    signal tempo_programado_int : integer range 0 to 127 := 0;
    signal tempo_limite         : integer range 0 to 120 := 0;

begin

    -- Ordem do vetor: zona5 zona4 zona3 zona2 zona1
    zonas <= zona5 & zona4 & zona3 & zona2 & zona1;

    zona_violada <= zona1 or zona2 or zona3 or zona4 or zona5;

    tempo_programado_int <= to_integer(unsigned(tempo_prog));

    -- Limita o valor maximo para 120 segundos
    tempo_limite <= 120 when tempo_programado_int > 120 else tempo_programado_int;

    process(clk, reset)
    begin
        if reset = '1' then
            estado_atual <= DESARMADO;
            zona_memoria <= "00000";

            contador_clk_contagem <= 0;
            contador_seg_contagem <= 0;

            contador_clk_watchdog <= 0;
            contador_seg_watchdog <= 0;

            esp_ok_recebido <= '0';

        elsif rising_edge(clk) then

            case estado_atual is

                when DESARMADO =>
                    zona_memoria <= "00000";

                    contador_clk_contagem <= 0;
                    contador_seg_contagem <= 0;

                    contador_clk_watchdog <= 0;
                    contador_seg_watchdog <= 0;

                    esp_ok_recebido <= '0';

                    if botao_arm = '1' then
                        estado_atual <= ARMADO;
                    else
                        estado_atual <= DESARMADO;
                    end if;


                when ARMADO =>
                    contador_clk_contagem <= 0;
                    contador_seg_contagem <= 0;

                    contador_clk_watchdog <= 0;
                    contador_seg_watchdog <= 0;

                    esp_ok_recebido <= '0';

                    if botao_arm = '0' then
                        estado_atual <= DESARMADO;
                        zona_memoria <= "00000";

                    elsif zona_violada = '1' then
                        zona_memoria <= zonas;

                        -- Se o tempo programado for 0, dispara imediatamente
                        if tempo_limite = 0 then
                            estado_atual <= DISPARO;
                        else
                            estado_atual <= CONTAGEM;
                        end if;

                    else
                        estado_atual <= ARMADO;
                    end if;


                when CONTAGEM =>
                    if botao_arm = '0' then
                        estado_atual <= DESARMADO;
                        zona_memoria <= "00000";

                        contador_clk_contagem <= 0;
                        contador_seg_contagem <= 0;

                    elsif zona_violada = '0' then
                        -- Se a violacao sumir antes do tempo, cancela
                        estado_atual <= ARMADO;
                        zona_memoria <= "00000";

                        contador_clk_contagem <= 0;
                        contador_seg_contagem <= 0;

                    else
                        -- Mantem memoria atualizada com a zona violada
                        zona_memoria <= zonas;

                        -- Conta ate o tempo escolhido em SW6..SW12
                        if contador_seg_contagem >= tempo_limite then
                            estado_atual <= DISPARO;

                            contador_clk_contagem <= 0;
                            contador_seg_contagem <= 0;

                        else
                            if contador_clk_contagem = 99999999 then
                                contador_clk_contagem <= 0;
                                contador_seg_contagem <= contador_seg_contagem + 1;
                            else
                                contador_clk_contagem <= contador_clk_contagem + 1;
                            end if;
                        end if;
                    end if;


                when DISPARO =>
                    if botao_arm = '0' then
                        estado_atual <= DESARMADO;
                        zona_memoria <= "00000";

                        contador_clk_contagem <= 0;
                        contador_seg_contagem <= 0;

                        contador_clk_watchdog <= 0;
                        contador_seg_watchdog <= 0;

                        esp_ok_recebido <= '0';

                    else
                        -- Se o ESP32 respondeu, registra confirmacao
                        if esp_ok = '1' then
                            esp_ok_recebido <= '1';

                            contador_clk_watchdog <= 0;
                            contador_seg_watchdog <= 0;

                        -- Se ainda nao recebeu esp_ok, conta ate 5 segundos
                        elsif esp_ok_recebido = '0' then

                            if contador_seg_watchdog >= 5 then
                                estado_atual <= RESET_ESP;

                                contador_clk_watchdog <= 0;
                                contador_seg_watchdog <= 0;

                            else
                                if contador_clk_watchdog = 99999999 then
                                    contador_clk_watchdog <= 0;
                                    contador_seg_watchdog <= contador_seg_watchdog + 1;
                                else
                                    contador_clk_watchdog <= contador_clk_watchdog + 1;
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

                        contador_clk_contagem <= 0;
                        contador_seg_contagem <= 0;

                        contador_clk_watchdog <= 0;
                        contador_seg_watchdog <= 0;

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
                display   <= "0001000"; -- A
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