library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.bladerf_p.all;
    use work.fifo_readwrite_p.all;
    
use std.env.finish;

entity twelve_bit_packer_tb is
    generic (
        TWO_CHANNEL_EN          : std_logic := '1';
        NUM_TWELVE_BIT_TRIALS   : natural := 100000;
        NUM_SIXTEEN_BIT_TRIALS  : natural := 100000
    );
end entity;

architecture test of twelve_bit_packer_tb is
    
    constant FX3_CLK_HALF_PERIOD    : time := 1 sec * (1.0/100.0e6/2.0);
    constant RX_CLK_HALF_PERIOD     : time := 1 sec * (1.0/122.88e6/2.0); 

    signal rx_clock     : std_logic := '1';
    signal fx3_clock    : std_logic := '1';
    signal reset        : std_logic := '1';
    signal rx_reset     : std_logic := '1';

    signal sample_fifo  : rx_fifo_t           := RX_FIFO_T_DEFAULT;
    signal meta_fifo    : meta_fifo_rx_t      := META_FIFO_RX_T_DEFAULT;

    signal twelve_bit_mode_en : std_logic := '1';
    
    signal sample_fifo_rreq     : std_logic := '0';
    signal sample_fifo_rdata    : std_logic_vector(31 downto 0);
    signal sample_fifo_rused    : std_logic_vector(sample_fifo.rused'high+1 downto 0);
    signal sample_reg           : std_logic_vector(95 downto 0);
    signal packet_control       : packet_control_t := PACKET_CONTROL_DEFAULT;

    signal timestamp    : unsigned(63 downto 0)     := (others => '0');
    signal streams      : sample_streams_t(0 to 1)  := (others => ZERO_SAMPLE);
    signal controls     : sample_controls_t(0 to 1) := (others => SAMPLE_CONTROL_DISABLE);
    
    procedure nop( signal clock : in std_logic; count : in natural) is 
    begin
        for i in 1 to count loop
            wait until falling_edge(clock);
        end loop;
    end procedure;
   
    procedure assert_eq(expected : unsigned; actual : unsigned) is
    begin
        assert(actual = expected)
            report "Unexpected sample, expected: " & integer'image(to_integer(expected)) &
                   " got: " & integer'image(to_integer(actual))
            severity failure;
    end procedure;

begin

    fx3_clock <= not fx3_clock after FX3_CLK_HALF_PERIOD;
    reset <= '0' after 10 * FX3_CLK_HALF_PERIOD;
    rx_reset <= '0' after 20 * RX_CLK_HALF_PERIOD;

    rx_clk_slow: if (TWO_CHANNEL_EN = '1') generate
        rx_clock <= not rx_clock after 2 * RX_CLK_HALF_PERIOD;
    end generate rx_clk_slow;
    
    rx_clk_fast: if (TWO_CHANNEL_EN = '0') generate
        rx_clock <= not rx_clock after RX_CLK_HALF_PERIOD;
    end generate rx_clk_fast;

    U_twelve_bit_packer : entity work.twelve_bit_packer
    generic map (
        FIFO_USEDR_WIDTH => sample_fifo.rused'length
    )
    port map (
        clock               =>  fx3_clock,
        reset               =>  reset,

        twelve_bit_mode_en  => twelve_bit_mode_en,
        usb_speed           => '0',

        -- Sample FIFO
        sample_rreq_out     => sample_fifo.rreq,
        sample_data_in      => sample_fifo.rdata,
        sample_rused_in     => sample_fifo.rused,
        
        -- FX3 GPIF controller
        sample_rreq_in      => sample_fifo_rreq,
        sample_data_out     => sample_fifo_rdata,
        sample_rused_out    => sample_fifo_rused
    );


    -- RX sample FIFO
    sample_fifo.aclr   <= reset;
    sample_fifo.wclock <= rx_clock;
    U_rx_sample_fifo : entity work.rx_fifo
        generic map (
            LPM_NUMWORDS        => 2**(sample_fifo.wused'length)
        ) port map (
            aclr                => sample_fifo.aclr,

            wrclk               => sample_fifo.wclock,
            wrreq               => sample_fifo.wreq,
            data                => sample_fifo.wdata,
            wrempty             => sample_fifo.wempty,
            wrfull              => sample_fifo.wfull,
            wrusedw             => sample_fifo.wused,

            rdclk               => fx3_clock,
            rdreq               => sample_fifo.rreq,
            q                   => sample_fifo.rdata,
            rdempty             => sample_fifo.rempty,
            rdfull              => sample_fifo.rfull,
            rdusedw             => sample_fifo.rused
        );


    -- RX meta FIFO
    meta_fifo.aclr   <= reset;
    meta_fifo.wclock <= rx_clock;
    U_rx_meta_fifo : entity work.rx_meta_fifo
        generic map (
            LPM_NUMWORDS        => 2**(meta_fifo.wused'length)
        ) port map (
            aclr                => meta_fifo.aclr,

            wrclk               => meta_fifo.wclock,
            wrreq               => meta_fifo.wreq,
            data                => meta_fifo.wdata,
            wrempty             => meta_fifo.wempty,
            wrfull              => meta_fifo.wfull,
            wrusedw             => meta_fifo.wused,

            rdclk               => fx3_clock,
            rdreq               => '1',
            q                   => open,
            rdempty             => open,
            rdfull              => open,
            rdusedw             => open
        );
    

    -- Sample bridge
    U_fifo_writer : entity work.fifo_writer
        generic map (
            NUM_STREAMS           => 2,
            FIFO_USEDW_WIDTH      => sample_fifo.wused'length,
            FIFO_DATA_WIDTH       => sample_fifo.wdata'length,
            META_FIFO_USEDW_WIDTH => meta_fifo.wused'length,
            META_FIFO_DATA_WIDTH  => meta_fifo.wdata'length
        )
        port map (
            clock               =>  rx_clock,
            reset               =>  rx_reset,
            enable              =>  '1',

            usb_speed           =>  '0', -- SS
            meta_en             =>  '0',
            packet_en           =>  '0',
            timestamp           =>  timestamp,
            mini_exp            =>  "00",

            fifo_full           =>  sample_fifo.wfull,
            fifo_usedw          =>  sample_fifo.wused,
            fifo_data           =>  sample_fifo.wdata,
            fifo_write          =>  sample_fifo.wreq,

            packet_control      =>  packet_control,
            packet_ready        =>  open,

            eight_bit_mode_en   => '0',

            meta_fifo_full      =>  meta_fifo.wfull,
            meta_fifo_usedw     =>  meta_fifo.wused,
            meta_fifo_data      =>  meta_fifo.wdata,
            meta_fifo_write     =>  meta_fifo.wreq,

            in_sample_controls  =>  controls,
            in_samples          =>  streams,

            overflow_led        =>  open,
            overflow_count      =>  open,
            overflow_duration   =>  x"ffff"
        );
        
    gen_streams : process (rx_clock, rx_reset)
        variable count            : unsigned(31 downto 0) := (others => '0');
    begin
        if (rx_reset = '1') then
            count := (others => '0');
            timestamp <= (others => '0');
            controls <= (
                0 => (enable => '1', data_req => '1'),
                1 => (enable => TWO_CHANNEL_EN, data_req => '1')
            );
        elsif (rising_edge(rx_clock)) then
            for i in controls'range loop

                if( controls(i).enable = '1') then
                    if( streams(i).data_v = '1' ) then
                        streams(i).data_i <= signed(std_logic_vector(count(15 downto 0)));
                        streams(i).data_q <= signed(std_logic_vector(count(31 downto 16)));
                        timestamp <= timestamp + 1;
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


    verify : process
        variable curr_count     : unsigned(31 downto 0) := (others => '0');
        variable two_ch_delay   : std_logic;
        variable test           : unsigned(11 downto 0);
    begin
        twelve_bit_mode_en <= '1';
        for x in 1 to NUM_TWELVE_BIT_TRIALS loop
            sample_fifo_rreq <= '0';
            nop(fx3_clock, 1);

            if (unsigned(sample_fifo_rused) >= 3) then
                -- Grab 4, 12-bit IQ samples
                for i in 1 to 3 loop
                    sample_reg <= sample_fifo_rdata & sample_reg(sample_reg'high downto 32);
                    sample_fifo_rreq <= '1';
                    nop(fx3_clock, 1);
                end loop;
                sample_fifo_rreq <= '0';
                two_ch_delay := '0';
                wait until falling_edge(fx3_clock);
                -- Check the 4 samples
                for i in 0 to 3 loop
                    -- Check i
                    test := unsigned(sample_reg(24 * i + 11 downto 24 * i));
                    assert_eq(curr_count(11 downto 0), test);
                    -- Check q
                    test := unsigned(sample_reg(24 * i + 23 downto 24 * i + 12));
                    assert_eq(curr_count(27 downto 16), test);
                    
                    if ((TWO_CHANNEL_EN = '0') or (two_ch_delay = '1')) then
                        curr_count := curr_count + 1;
                    end if;
                    two_ch_delay := not two_ch_delay;

                end loop;
            end if;
        end loop;

        twelve_bit_mode_en <= '0';
        sample_fifo_rreq <= '0';
        two_ch_delay := '0';
        nop(fx3_clock, 1);
        for i in 0 to NUM_SIXTEEN_BIT_TRIALS-1 loop

            if (unsigned(sample_fifo_rused) > 0) then
                -- Check current fifo output
                assert_eq(curr_count, unsigned(sample_fifo_rdata));
                sample_fifo_rreq <= '1';
                nop(fx3_clock, 1);
                sample_fifo_rreq <= '0';

                if ((TWO_CHANNEL_EN = '0') or (two_ch_delay = '1')) then
                    curr_count := curr_count + 1;
                end if;
                two_ch_delay := not two_ch_delay;
            else
                nop(fx3_clock, 1);
            end if;

        end loop;
        
        finish;

    end process verify;

end test ; -- test