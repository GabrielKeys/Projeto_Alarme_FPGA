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

    type estado_t is (DESARMADO, ARMADO, DISPARO);
    signal estado_atual : estado_t := DESARMADO;

    signal zonas        : STD_LOGIC_VECTOR(4 downto 0);
    signal zona_violada : STD_LOGIC;
    signal zona_memoria : STD_LOGIC_VECTOR(4 downto 0) := "00000";

begin

    -- Ordem do vetor: zona5 zona4 zona3 zona2 zona1
    zonas <= zona5 & zona4 & zona3 & zona2 & zona1;

    zona_violada <= zona1 or zona2 or zona3 or zona4 or zona5;

    process(clk, reset)
    begin
        if reset = '1' then
            estado_atual <= DESARMADO;
            zona_memoria <= "00000";

        elsif rising_edge(clk) then

            case estado_atual is

                when DESARMADO =>
                    zona_memoria <= "00000";

                    if botao_arm = '1' then
                        estado_atual <= ARMADO;
                    else
                        estado_atual <= DESARMADO;
                    end if;

                when ARMADO =>
                    if botao_arm = '0' then
                        estado_atual <= DESARMADO;
                        zona_memoria <= "00000";

                    elsif zona_violada = '1' then
                        zona_memoria <= zonas;
                        estado_atual <= DISPARO;

                    else
                        estado_atual <= ARMADO;
                    end if;

                when DISPARO =>
                    if botao_arm = '0' then
                        estado_atual <= DESARMADO;
                        zona_memoria <= "00000";
                    else
                        estado_atual <= DISPARO;
                    end if;

            end case;

        end if;
    end process;

    process(estado_atual, zona_memoria)
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

            when DISPARO =>
                display    <= "1000001"; -- U
                sirene     <= '1';
                estrobo    <= '1';
                esp_alerta <= '1';
                esp_zonas  <= zona_memoria;
                leds_zona  <= zona_memoria;

        end case;
    end process;

end Behavioral;