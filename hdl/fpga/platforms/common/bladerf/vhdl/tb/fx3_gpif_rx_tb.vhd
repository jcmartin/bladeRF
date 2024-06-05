
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.bladerf_p.all;
    use work.fifo_readwrite_p.all;

entity fx3_gpif_rx_tb is
    generic (
        RX_CLK_HALF_PERIOD : time := 1 sec / (122.88e6 * 2.0); -- Running at double the sampling freq
        FX3_CLK_HALF_PERIOD : time := 1 sec / (100.0e6 * 2.0)
    );
end entity;


architecture arch of fx3_gpif_rx_tb is

    signal rx_clock : std_logic := '1';
    signal fx3_clock : std_logic := '1';
    signal reset : std_logic := '1';

    signal rx_timestamp : unsigned(63 downto 0) := (others => '0');
    signal tx_timestamp : unsigned(63 downto 0)   := ( others => '0' );

    signal packet_control      : packet_control_t    := PACKET_CONTROL_DEFAULT;
    signal sample_fifo         : rx_fifo_t           := RX_FIFO_T_DEFAULT;
    signal meta_fifo           : meta_fifo_rx_t      := META_FIFO_RX_T_DEFAULT;
    signal loopback_fifo       : loopback_fifo_t     := LOOPBACK_FIFO_T_DEFAULT;
    signal tx_sample_fifo      : tx_fifo_t           := TX_FIFO_T_DEFAULT;
    signal tx_meta_fifo        : meta_fifo_tx_t      := META_FIFO_TX_T_DEFAULT;

    signal sample_fifo_rreq    : std_logic;
    signal sample_fifo_rdata   : std_logic_vector(31 downto 0);
    signal sample_fifo_rused   : std_logic_vector(sample_fifo.rused'high+1 downto 0);
    signal meta_fifo_rreq      : std_logic;
    signal meta_fifo_rempty    : std_logic;
    signal meta_fifo_rdata     : std_logic_vector(31 downto 0);

    signal fx3_gpif, fx3_gpif_in, fx3_gpif_out : std_logic_vector(31 downto 0);
    signal fx3_gpif_oe         : std_logic;
    signal fx3_ctl, fx3_ctl_in, fx3_ctl_out, fx3_ctl_oe : std_logic_vector(12 downto 0);
    signal dma0                : std_logic_vector(31 downto 0);
    signal dma0_valid          : std_logic;
    signal dma1                : std_logic_vector(31 downto 0);
    signal dma1_valid          : std_logic;

    signal streams             : sample_streams_t(0 to 1) := (others => ZERO_SAMPLE);
    signal controls            : sample_controls_t(0 to 1)  := (others => SAMPLE_CONTROL_DISABLE);


    procedure nop( signal clock : in std_logic; count : in natural) is 
    begin
        for i in 1 to count loop
            wait until rising_edge(clock);
        end loop;
    end procedure;
    
    -- procedure assert_eq()
    procedure assert_eq(expected : unsigned; actual : unsigned) is
    begin
        assert(actual = expected)
            report "Unexpected sample, expected: " & integer'image(to_integer(actual)) &
                   " got: " & integer'image(to_integer(expected))
            severity failure;
    end procedure;
begin

    rx_clock <= not rx_clock after RX_CLK_HALF_PERIOD;
    fx3_clock <= not fx3_clock after FX3_CLK_HALF_PERIOD;
    reset <= '0' after 100 ns;

    -- RX Submodule
    U_rx : entity work.rx
        generic map (
            NUM_STREAMS            => controls'length
        )
        port map (
            rx_reset               => fx3_ctl(7),
            rx_clock               => rx_clock,
            rx_enable              => '1',

            meta_en                => '1',
            timestamp_reset        => open,
            usb_speed              => '0', -- SS
            rx_mux_sel             => to_unsigned(2, 3), -- RX_MUX_32BIT_COUNTER
            rx_overflow_led        => open,
            rx_timestamp           => rx_timestamp,

            -- Triggering
            trigger_arm            => '0',
            trigger_fire           => '0',
            trigger_master         => '0',
            trigger_line           => open,

            -- Eightbit mode
            eight_bit_mode_en      => '0',

            -- Packet FIFO
            packet_en              => '0',
            packet_control         => packet_control,
            packet_ready           => open,

            -- Samples to host via FX3
            sample_fifo_rclock     => fx3_clock,
            sample_fifo_raclr      => '0',
            sample_fifo_rreq       => sample_fifo.rreq,
            sample_fifo_rdata      => sample_fifo.rdata,
            sample_fifo_rempty     => sample_fifo.rempty,
            sample_fifo_rfull      => sample_fifo.rfull,
            sample_fifo_rused      => sample_fifo.rused,

            -- Mini expansion signals
            mini_exp               => "00",

            -- Metadata to host via FX3
            meta_fifo_rclock       => fx3_clock,
            meta_fifo_raclr        => '0',
            meta_fifo_rreq         => meta_fifo.rreq,
            meta_fifo_rdata        => meta_fifo.rdata,
            meta_fifo_rempty       => meta_fifo.rempty,
            meta_fifo_rfull        => meta_fifo.rfull,
            meta_fifo_rused        => meta_fifo.rused,

            -- Digital Loopback Interface
            loopback_fifo_wenabled => open,
            loopback_fifo_wreset   => reset,
            loopback_fifo_wclock   => rx_clock,
            loopback_fifo_wdata    => loopback_fifo.wdata,
            loopback_fifo_wreq     => loopback_fifo.wreq,
            loopback_fifo_wfull    => loopback_fifo.wfull,
            loopback_fifo_wused    => loopback_fifo.wused,

            -- RFFE Interface
            adc_controls           => controls,
            adc_streams            => streams
        );

    -- either pack samples into 12 bits or pass through 64 -> 32
    u_twelve_bit_packer : entity work.twelve_bit_packer
        generic map (
            fifo_usedr_width => sample_fifo.rused'length
        )
        port map (
            clock               =>  fx3_clock,
            reset               =>  reset,

            twelve_bit_mode_en  => '0',
            eight_bit_mode_en   => '0',
            dual_channel_en     => '0',
            meta_en             => '1',
            usb_speed           => '0',

            -- sample fifo
            sample_rreq_out     => sample_fifo.rreq,
            sample_data_in      => sample_fifo.rdata,
            sample_rused_in     => sample_fifo.rused,
            
            -- meta fifo
            meta_rreq_out       => meta_fifo.rreq,
            meta_empty_in       => meta_fifo.rempty,
            meta_data_in        => meta_fifo.rdata,
            
            -- fx3 gpif controller
            sample_rreq_in      => sample_fifo_rreq,
            sample_data_out     => sample_fifo_rdata,
            sample_rused_out    => sample_fifo_rused,
            meta_rreq_in        => meta_fifo_rreq,
            meta_empty_out      => meta_fifo_rempty,
            meta_data_out       => meta_fifo_rdata
        );


    -- FX3 GPIF
    U_fx3_gpif : entity work.fx3_gpif
        port map (
            pclk                =>  fx3_clock,
            reset               =>  reset,

            usb_speed           =>  '0',

            meta_enable         =>  '1',
            packet_enable       =>  '0',
            rx_enable           =>  open,
            tx_enable           =>  open,

            gpif_in             =>  fx3_gpif_in,
            gpif_out            =>  fx3_gpif_out,
            gpif_oe             =>  fx3_gpif_oe,
            ctl_in              =>  fx3_ctl_in,
            ctl_out             =>  fx3_ctl_out,
            ctl_oe              =>  fx3_ctl_oe,

            tx_fifo_write       =>  tx_sample_fifo.wreq,
            tx_fifo_full        =>  tx_sample_fifo.wfull,
            tx_fifo_empty       =>  tx_sample_fifo.wempty,
            tx_fifo_usedw       =>  tx_sample_fifo.wused,
            tx_fifo_data        =>  tx_sample_fifo.wdata,

            tx_timestamp        =>  tx_timestamp,
            tx_meta_fifo_write  =>  tx_meta_fifo.wreq,
            tx_meta_fifo_full   =>  tx_meta_fifo.wfull,
            tx_meta_fifo_empty  =>  tx_meta_fifo.wempty,
            tx_meta_fifo_usedw  =>  tx_meta_fifo.wused,
            tx_meta_fifo_data   =>  tx_meta_fifo.wdata,

            rx_fifo_read        =>  sample_fifo_rreq,
            rx_fifo_full        =>  sample_fifo.rfull,
            rx_fifo_empty       =>  sample_fifo.rempty,
            rx_fifo_usedw       =>  sample_fifo_rused,
            rx_fifo_data        =>  sample_fifo_rdata,

            rx_meta_fifo_read   =>  meta_fifo_rreq,
            rx_meta_fifo_full   =>  meta_fifo.rfull,
            rx_meta_fifo_empty  =>  meta_fifo_rempty,
            rx_meta_fifo_usedr  =>  meta_fifo.rused,
            rx_meta_fifo_data   =>  meta_fifo_rdata
        );

    -- FX3 GPIF bidirectional signal control
    register_gpif : process(reset, fx3_clock)
    begin
        if( reset = '1' ) then
            fx3_gpif    <= (others =>'Z');
            fx3_gpif_in <= (others =>'0');
        elsif( rising_edge(fx3_clock) ) then
            fx3_gpif_in <= fx3_gpif;
            if( fx3_gpif_oe = '1' ) then
                fx3_gpif <= fx3_gpif_out;
            else
                fx3_gpif <= (others =>'Z');
            end if;
        end if;
    end process;

    -- FX3 CTL bidirectional signal control
    generate_ctl : for i in fx3_ctl'range generate
        fx3_ctl(i) <= fx3_ctl_out(i) when fx3_ctl_oe(i) = '1' else 'Z';
    end generate;

    fx3_ctl_in <= fx3_ctl;

    U_fx3_gpif_model : entity work.fx3_gpif_model
        port map (
            pclk        => fx3_clock,
            reset       => reset,
            gpif        => fx3_gpif,
            ctl         => fx3_ctl,
            dma0        => open,
            dma0_valid  => open,
            dma1        => open,
            dma1_valid  => open
        );

    gen_streams : process (rx_clock, reset)
        variable count            : unsigned(31 downto 0) := (others => '0');
    begin
        if (reset = '1') then
            count := (others => '0');
            rx_timestamp <= (others => '0');
            controls <= (
                0 => (enable => '1', data_req => '1'),
                1 => (enable => '1', data_req => '1')
            );
        elsif (rising_edge(rx_clock)) then
            for i in controls'range loop

                if( controls(i).enable = '1') then
                    if( streams(i).data_v = '1' ) then
                        streams(i).data_i <= signed(std_logic_vector(count(15 downto 0)));
                        streams(i).data_q <= signed(std_logic_vector(count(31 downto 16)));
                        rx_timestamp <= rx_timestamp + 1;
                    end if;

                    streams(i).data_v <= not streams(i).data_v;
                    controls(i).data_req <= not controls(i).data_req;
                end if;
            end loop;
            if (streams(0).data_v or streams(1).data_v) then
                count := count + 1;
            end if;
        end if;
    end process gen_streams;


    -- verify: process
    --     variable sample_count : integer := 0;
    --     variable curr_timestep : unsigned(63 downto 0) := (others => '0');
    --     variable next_timestep : unsigned(63 downto 0) := (others => '0');
    --     variable curr_sample   : unsigned(31 downto 0) := (0 => '1', others => '0'); -- TODO: why starting a cycle too late?
    --     constant NUM_SAMPLES_EXPECTED : integer := get_samples_expected;
    --     constant DELTA_EXPECTED : unsigned(63 downto 0) := to_unsigned(get_delta_expected, 64);
    --     -- Buffer size is 508
    -- begin
    --     -- Verify incrimenting timestamps and correct data written

    --     -- x"FFF" & "11" & sync_mini_exp & x"FFFF" & std_logic_vector(timestamp) & x"12344321";
    --     nop(clock, 1);

    --     -- Expecting data in the form:
    --     --      | 63:48 | 47:32 | 31:16 | 15:0 | Bit indices
    --     --   1. |   Q1  |   I1  |   Q0  |  I0  | Channels 0 & 1 enabled
    --     --      | 63:56 | 55:48 | 47:40 | 39:32 | 31:24 | 23:16 |  15:8 |  7:0 | Bit indices
    --     --   1. |   Q1  |   I1  |   Q0  |  I0   |   Q1  |   I1  |   Q0  |  I0  | Channels 0 & 1 enabled
    --     if (sample_fifo.wreq) then
    --         if (EIGHT_BIT_MODE) then
    --             sample_count := sample_count + 4;

    --             assert_eq(curr_sample(15 downto 0), unsigned(sample_fifo.wdata(15 downto 0)));
    --             if (not (ENABLE_CHANNEL_0 and ENABLE_CHANNEL_1)) then
    --                 curr_sample := curr_sample + 1;
    --             end if;
    --             assert_eq(curr_sample(15 downto 0), unsigned(sample_fifo.wdata(31 downto 16)));
    --             curr_sample := curr_sample + 1;

    --             assert_eq(curr_sample(15 downto 0), unsigned(sample_fifo.wdata(47 downto 32)));
    --             if (not (ENABLE_CHANNEL_0 and ENABLE_CHANNEL_1)) then
    --                 curr_sample := curr_sample + 1;
    --             end if;
    --             assert_eq(curr_sample(15 downto 0), unsigned(sample_fifo.wdata(63 downto 48)));
    --             curr_sample := curr_sample + 1;

    --         else
    --             sample_count := sample_count + 2;

    --             assert_eq(curr_sample, unsigned(sample_fifo.wdata(31 downto 0)));
    --             if (not (ENABLE_CHANNEL_0 and ENABLE_CHANNEL_1)) then
    --                 curr_sample := curr_sample + 1;
    --             end if;
                
    --             assert_eq(curr_sample, unsigned(sample_fifo.wdata(63 downto 32)));
    --             curr_sample := curr_sample + 1;

    --         end if;
    --     end if;

    --     if (meta_fifo.wreq) then
    --         next_timestep := unsigned(meta_fifo.wdata(95 downto 32));
    --         report "Got meta t = " & integer'image(to_integer(next_timestep));
    --         report "Got n = " & integer'image(sample_count) & " samples";
    --         if (curr_timestep /= 0) then
    --             assert ( next_timestep = (curr_timestep + DELTA_EXPECTED))
    --                 report "Unexpected time jump, expected " & integer'image(to_integer(curr_timestep + DELTA_EXPECTED)) &
    --                        " but got " & integer'image(to_integer(next_timestep))
    --                 severity failure;
                
    --             assert (sample_count = NUM_SAMPLES_EXPECTED)
    --                 report "Incorrect number of samples, expected " & integer'image(NUM_SAMPLES_EXPECTED)
    --                 severity failure;
    --         end if;
    --         curr_timestep := next_timestep;
    --         sample_count := 0;

    --     end if;
    -- end process verify;

end architecture;
