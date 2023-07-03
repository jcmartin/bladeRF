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
        meta_en             : in std_logic;
        usb_speed           : in std_logic;

        -- Sample FIFO
        sample_rreq_out     : out std_logic;
        sample_data_in      : in std_logic_vector(63 downto 0);
        sample_rused_in     : in std_logic_vector(FIFO_USEDR_WIDTH-1 downto 0);

        -- Meta FIFO
        meta_rreq_out       : out std_logic;
        meta_empty_in       : in std_logic;
        meta_data_in        : in std_logic_vector(127 downto 0);
        
        -- FX3 GPIF controller
        sample_rreq_in      : in std_logic;
        sample_data_out     : out std_logic_vector(31 downto 0);
        sample_rused_out    : out std_logic_vector(FIFO_USEDR_WIDTH downto 0);

        meta_rreq_in        : in std_logic;
        -- TODO: impl rusedw if ever needed by GPIF controller
        meta_empty_out      : out std_logic;
        meta_data_out       : out std_logic_vector(31 downto 0)

    );
end entity;

architecture arch of twelve_bit_packer is

    -- GPIF buf sizes GCD of 3 x 64 bit data to fit packed 12-bit samples
    -- in terms of 32-bit dwords
    constant GPIF_BUF_SIZE_HS       :   natural := 255; -- One cycle of padding
    constant GPIF_BUF_SIZE_SS       :   natural := 510; -- Two cycles of padding
    
    type state_t is (START, PASS_0, PASS_1, PACK_0, PACK_1, PACK_2, PAD);
    type meta_state_t is (IDLE, READ, WRITE);

    -- FIFOs are in "Show-Ahead" mode, meaning rreq acts like an acknowledge
    type fsm_t is record
        state               : state_t;
        loading             : std_logic;
        sample_downcount    : integer range 0 to GPIF_BUF_SIZE_SS;
        padding_downcount   : integer range 0 to 2;
        prev_data           : std_logic_vector(31 downto 0);
        -- Previous values
        q0_p, i1_p, q1_p    : std_logic_vector(11 downto 0);
    end record;

    type meta_fsm_t is record
        state               : meta_state_t;
        ret                 : meta_state_t;
        timestamp           : unsigned(63 downto 0);
        offset              : integer range 0 to 504;
        offset_delta        : integer range 0 to 168;
        skip_downcount      : integer range 0 to 3;
        write_downcount     : integer range 0 to 3;
        meta_data           : std_logic_vector(127 downto 0);
        prev_meta_data      : std_logic_vector(127 downto 0);
        prev_discontinuous  : std_logic;
    
    end record;

    constant FSM_RESET_VALUE : fsm_t := (
        state               => START,
        loading             => '0',
        sample_downcount    => 0,
        padding_downcount   => 0,
        prev_data           => (others => '0'),
        q0_p                => (others => '0'),
        i1_p                => (others => '0'),
        q1_p                => (others => '0')
    );

    constant META_FSM_RESET_VALUE : meta_fsm_t := (
        state               => IDLE,
        ret                 => IDLE,
        timestamp           => (others => '0'),
        offset              => 0,
        offset_delta        => 0,
        skip_downcount      => 0,
        write_downcount     => 0,
        meta_data           => (others => '0'),
        prev_meta_data      => (others => '0'),
        prev_discontinuous  => '0'
    );

    signal current, future : fsm_t := FSM_RESET_VALUE;
    signal i0, q0, i1, q1  : std_logic_vector(11 downto 0);
    signal gpif_buf_size   : natural range GPIF_BUF_SIZE_HS to GPIF_BUF_SIZE_SS := GPIF_BUF_SIZE_SS;
    signal padding_size    : natural range 1 to 2;

    signal meta_current, meta_future : meta_fsm_t := META_FSM_RESET_VALUE;
    signal timestamp_in    : unsigned(63 downto 0);

begin

    i0 <= sample_data_in(11 downto 0);
    q0 <= sample_data_in(27 downto 16);
    i1 <= sample_data_in(43 downto 32);
    q1 <= sample_data_in(59 downto 48);
    timestamp_in <= unsigned(meta_data_in(95 downto 32));

    fsm_sync : process (clock, reset)
    begin
        if (reset = '1') then
            current <= FSM_RESET_VALUE;
            meta_current <= META_FSM_RESET_VALUE;
        elsif (rising_edge(clock)) then
            current <= future;
            meta_current <= meta_future;
        end if;
    end process;

    fsm_comb : process (all)
    begin
        future <= current;
        sample_rreq_out <= sample_rreq_in;
        sample_data_out <= (others => '0');

        case current.state is
            when START =>
                if (twelve_bit_mode_en = '1') then 
                    future.state <= PACK_0;
                else
                    future.state <= PASS_0;
                end if;
            
            when PASS_0 =>
                -- TODO: ensure we cannot switch halfway through passthrough
                sample_data_out <= sample_data_in(31 downto 0);
                future.prev_data <= sample_data_in(63 downto 32);
                
                -- Priority goes to sample_rreq since it acts as an acknowledge
                if (sample_rreq_in = '1') then 
                    future.state <= PASS_1;
                elsif (twelve_bit_mode_en = '1') then
                    future.state <= PACK_0;
                end if;

            when PASS_1 =>
                sample_rreq_out <= '0';
                sample_data_out <= current.prev_data;

                if (sample_rreq_in = '1') then
                    future.state <= PASS_0;
                end if;

            when PACK_0 =>
                if (current.loading = '0') then
                    if (meta_en = '1') then
                        future.sample_downcount <= gpif_buf_size - 3;
                        future.padding_downcount <= padding_size - 1;
                    else
                        future.sample_downcount <= gpif_buf_size;
                        future.padding_downcount <= padding_size;
                    end if;
                end if;

                sample_data_out <= i1(7 downto 0) & q0 & i0;
                future.i1_p <= i1;
                future.q1_p <= q1;
                
                if (sample_rreq_in = '1') then
                    future.loading <= '1';
                    future.state <= PACK_1;
                elsif (current.loading = '0' and twelve_bit_mode_en = '0') then
                    future.state <= PASS_0;
                end if;

            when PACK_1 =>
                sample_data_out <= q0(3 downto 0) & i0 & current.q1_p & current.i1_p(11 downto 8);
                future.q0_p <= q0;
                future.i1_p <= i1;
                future.q1_p <= q1;

                if (sample_rreq_in = '1') then
                    future.state <= PACK_2;
                end if;
            
            when PACK_2 =>
                sample_rreq_out <= '0';
                sample_data_out <= current.q1_p & current.i1_p & current.q0_p(11 downto 4);

                if (sample_rreq_in = '1') then
                    future.sample_downcount <= current.sample_downcount - 3;
                    if (current.sample_downcount = 3) then
                        if (current.padding_downcount = 0) then
                            future.loading <= '0';
                            future.state <= PACK_0;
                        else
                            future.state <= PAD;
                        end if;
                    else
                        future.state <= PACK_0;
                    end if;
                end if;

            when PAD =>
                sample_rreq_out <= '0';
                sample_data_out <= (others => '1');

                if (sample_rreq_in = '1') then
                    future.padding_downcount <= current.padding_downcount - 1;
                    if (current.padding_downcount = 1) then
                        future.loading <= '0';
                        future.state <= PACK_0;
                    end if;
                end if;
            
        end case;
    end process;

    -- TODO: generalize to SS 2 ch and HS 1 + 2 ch
    -- TODO: be able to reset / change modes
    meta_fsm_comb : process(all)
        variable discontinuous : std_logic;
    begin
        meta_future <= meta_current;
        meta_empty_out <= '1';
        meta_rreq_out <= '0';

        case (meta_current.state) is
            when IDLE =>
                if (meta_empty_in = '0') then
                    if (twelve_bit_mode_en = '1') then
                        meta_future.prev_meta_data <= meta_data_in;
                        meta_future.timestamp <= timestamp_in;
                        meta_rreq_out <= '1';
                        meta_future.state <= READ;
                        meta_future.ret <= READ;
                        meta_future.offset <= 0;
                        meta_future.offset_delta <= 0;
                        meta_future.skip_downcount <= 3;
                    else
                        meta_future.meta_data <= meta_data_in;
                        meta_future.ret <= IDLE;
                        meta_future.state <= WRITE;
                    end if;
                end if;

            when READ =>
                if (meta_empty_in = '0') then
                    discontinuous := '1' when timestamp_in - meta_current.timestamp /= 508 else '0';
                    if (meta_current.skip_downcount = 3) then
                        discontinuous := meta_current.prev_discontinuous or discontinuous;
                    end if;
                    
                    -- TODO: pick a bit to store discontinous
                    meta_future.meta_data <= 
                        meta_current.prev_meta_data(127 downto 96) &
                        std_logic_vector(meta_current.timestamp + meta_current.offset) & x"12344321";

                    meta_future.timestamp <= timestamp_in;
                    meta_future.prev_meta_data <= meta_data_in;
                    meta_future.prev_discontinuous <= discontinuous;

                    if (meta_current.skip_downcount = 0) then
                        if (meta_current.offset_delta = 168) then
                            meta_future.state <= IDLE;
                        else
                            meta_future.state <= READ;
                            meta_future.skip_downcount <= 3;
                            meta_future.offset <= 168 - meta_current.offset_delta;
                            meta_future.offset_delta <= meta_current.offset_delta + 4;
                        end if;
                    else
                        meta_rreq_out <= '1'; -- ack
                        meta_future.state <= WRITE;
                        meta_future.write_downcount <= 3;
                        meta_future.skip_downcount <= meta_current.skip_downcount - 1;
                        meta_future.offset <= meta_current.offset + 168;
                    end if;

                end if;

            when WRITE =>
                meta_empty_out <= '0';
                meta_data_out <= meta_current.meta_data(31 downto 0);

                if (meta_rreq_in = '1') then 
                    if (meta_current.write_downcount = 0) then
                        meta_future.state <= meta_current.ret;
                    else
                        meta_future.meta_data <= x"00000000" & meta_current.meta_data(127 downto 32);
                        meta_future.write_downcount <= meta_current.write_downcount - 1;
                    end if;
                end if;
                
        end case;

    end process;

    -- Transfer size for DMAs depends on USB speed
    calculate_conditionals : process(reset, clock)
    begin
        if (reset = '1') then
            gpif_buf_size       <= GPIF_BUF_SIZE_SS;
            padding_size        <= 2;
        elsif (rising_edge(clock)) then
            if (usb_speed = '0') then
                gpif_buf_size   <= GPIF_BUF_SIZE_SS;
                padding_size    <= 2;
            else
                gpif_buf_size   <= GPIF_BUF_SIZE_HS;
                padding_size    <= 1;
            end if;
        end if;
    end process calculate_conditionals;
    
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