library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

-- Expects an input of 64 bits and outputs 32 bits

entity twelve_bit_packer is
    generic (
        FIFO_USEDR_WIDTH      : natural := 12
    );
    port (
        clock               : in std_logic;
        reset               : in std_logic;
        twelve_bit_mode_en  : in std_logic;
        usb_speed           : in std_logic;

        -- Sample FIFO
        sample_rreq_out    : out std_logic;
        sample_data_in      : in std_logic_vector(63 downto 0);
        sample_rused_in     : in std_logic_vector(FIFO_USEDR_WIDTH-1 downto 0);
        
        -- FX3 GPIF controller
        sample_rreq_in     : in std_logic;
        sample_data_out     : out std_logic_vector(31 downto 0);
        sample_rused_out    : out std_logic_vector(FIFO_USEDR_WIDTH downto 0)

    );
end entity;

architecture arch of twelve_bit_packer is

    type state_t is (IDLE, PASS_1, PASS_2, PACK_1, PACK_2, PACK_3);

    -- Output data only needs to be valid one cycle after req is asserted
    -- however we may need to save current fifo output
    type fsm_t is record
        state               : state_t;
        latch               : std_logic;
        prev_data           : std_logic_vector(31 downto 0);
        -- Previous values
        q0_p, i1_p, q1_p    : std_logic_vector(11 downto 0);
    end record;

    constant FSM_RESET_VALUE : fsm_t := (
        state       => IDLE,
        latch       => '0',
        prev_data   => (others => '0'),
        q0_p        => (others => '0'),
        i1_p        => (others => '0'),
        q1_p        => (others => '0')
    );

    signal current, future : fsm_t := FSM_RESET_VALUE;

    alias i0 : std_logic_vector(11 downto 0) is sample_data_in(11 downto 0);
    alias q0 : std_logic_vector(11 downto 0) is sample_data_in(27 downto 16);
    alias i1 : std_logic_vector(11 downto 0) is sample_data_in(43 downto 32);
    alias q1 : std_logic_vector(11 downto 0) is sample_data_in(59 downto 48);

begin

    fsm_sync : process (clock, reset)
    begin
        if (reset = '1') then
            current <= FSM_RESET_VALUE;
        elsif (rising_edge(clock)) then
            current <= future;
        end if;
    end process;

    fsm_comb : process (all)
    begin
        future <= current;
        sample_rreq_out <= sample_rreq_in;
        sample_data_out <= (others => '0');

        case current.state is
            when IDLE =>
                future.latch <= '0';
                if (sample_rreq_in = '1') then
                    if (twelve_bit_mode_en = '1') then 
                        future.state <= PACK_1;
                    else
                        future.state <= PASS_1;
                    end if;
                end if;

            when PASS_1 =>
                sample_rreq_out <= '0';
                sample_data_out <= sample_data_in(31 downto 0);

                if (current.latch = '0') then
                    future.prev_data <= sample_data_in(63 downto 32);
                end if;

                if (sample_rreq_in = '1') then
                    future.state <= PASS_2;
                else
                    future.latch <= '1';
                end if;

            when PASS_2 =>
                sample_data_out <= current.prev_data;

                if (sample_rreq_in = '1') then
                    future.state <= PASS_1;
                else
                    future.state <= IDLE;
                end if;

            when PACK_1 =>
                sample_data_out <= i1(7 downto 0) & q0 & i0;
                if (current.latch = '0') then
                    future.i1_p <= i1;
                    future.q1_p <= q1;
                end if;

                if (sample_rreq_in = '1') then
                    future.state <= PACK_2;
                    future.latch <= '0';
                else
                    future.latch <= '1';
                end if;
            
            when PACK_2 =>
                sample_rreq_out <= '0';
                sample_data_out <= q0(3 downto 0) & i0 & current.q1_p & current.i1_p(11 downto 8);
                if (current.latch = '0') then
                    future.q0_p <= q0;
                    future.i1_p <= i1;
                    future.q1_p <= q1;
                end if;
                
                if (sample_rreq_in = '1') then
                    future.state <= PACK_3;
                else
                    future.latch <= '1';
                end if;
            
            when PACK_3 =>
                sample_data_out <= current.q1_p & current.i1_p & current.q0_p(11 downto 4);

                if (sample_rreq_in = '1') then
                    future.state <= PACK_1;
                else
                    future.state <= IDLE;
                end if;

        end case;
    end process;

    sample_rused_mux : process (all)
    begin
        if (twelve_bit_mode_en = '1') then
            -- 2 64-bit words = 3 32-bit words
            sample_rused_out <= std_logic_vector(unsigned(sample_rused_in & '0')/3);
        else
            sample_rused_out <= sample_rused_in & '0';
        end if;
    end process;

end architecture;