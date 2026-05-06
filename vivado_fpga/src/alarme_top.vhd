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
    signal estado_atual, proximo_estado : estado_t;

    signal zonas        : STD_LOGIC_VECTOR(4 downto 0);
    signal zona_violada : STD_LOGIC;

    signal zona_memoria : STD_LOGIC_VECTOR(4 downto 0) := "00000";

    signal contador : integer range 0 to 10 := 0;

begin

    -- Agrupa as zonas em um vetor.
    -- Ordem: zona5 zona4 zona3 zona2 zona1
    zonas <= zona5 & zona4 & zona3 & zona2 & zona1;

    -- Detecta se qualquer zona foi violada.
    zona_violada <= zona1 or zona2 or zona3 or zona4 or zona5;

    -- Processo sequencial: atualiza estado, contador e memória da zona.
    process(clk, reset)
    begin
        if reset = '1' then
            estado_atual <= DESARMADO;
            contador <= 0;
            zona_memoria <= "00000";

        elsif rising_edge(clk) then
            estado_atual <= proximo_estado;

            -- Guarda a zona violada quando o sistema está armado
            if estado_atual = ARMADO and zona_violada = '1' then
                zona_memoria <= zonas;
            end if;

            -- Limpa a zona memorizada ao desarmar
            if proximo_estado = DESARMADO then
                zona_memoria <= "00000";
            end if;

            -- Contador do tempo antes do disparo
            if estado_atual = CONTAGEM then
                if contador < 10 then
                    contador <= contador + 1;
                end if;
            else
                contador <= 0;
            end if;
        end if;
    end process;

    -- Processo combinacional: define o próximo estado.
    process(estado_atual, botao_arm, zona_violada, contador, esp_ok)
    begin
        proximo_estado <= estado_atual;

        case estado_atual is

            when DESARMADO =>
                if botao_arm = '1' then
                    proximo_estado <= ARMADO;
                end if;

            when ARMADO =>
                if botao_arm = '0' then
                    proximo_estado <= DESARMADO;
                elsif zona_violada = '1' then
                    proximo_estado <= CONTAGEM;
                end if;

            when CONTAGEM =>
                if botao_arm = '0' then
                    proximo_estado <= DESARMADO;
                elsif zona_violada = '0' then
                    proximo_estado <= ARMADO;
                elsif contador = 10 then
                    proximo_estado <= DISPARO;
                end if;

            when DISPARO =>
                if botao_arm = '0' then
                    proximo_estado <= DESARMADO;
                elsif esp_ok = '0' then
                    proximo_estado <= RESET_ESP;
                end if;

            when RESET_ESP =>
                proximo_estado <= ARMADO;

        end case;
    end process;

    -- Processo combinacional: controla as saídas.
    process(estado_atual, zona_memoria)
    begin
        -- Valores padrão das saídas
        sirene     <= '0';
        estrobo    <= '0';
        esp_alerta <= '0';
        esp_reset  <= '0';
        esp_zonas  <= "00000";
        leds_zona  <= "00000";
        display    <= "1111111";

        case estado_atual is

            when DESARMADO =>
                display <= "0100001"; -- letra d

            when ARMADO =>
                display <= "0001000"; -- letra A

            when CONTAGEM =>
                display   <= "0001000"; -- letra A
                leds_zona <= zona_memoria;

            when DISPARO =>
                display    <= "1000001"; -- letra U
                sirene     <= '1';
                estrobo    <= '1';
                esp_alerta <= '1';
                esp_zonas  <= zona_memoria;
                leds_zona  <= zona_memoria;

            when RESET_ESP =>
                display    <= "1000001"; -- letra U
                esp_reset  <= '1';
                esp_zonas  <= zona_memoria;
                leds_zona  <= zona_memoria;

        end case;
    end process;

end Behavioral;