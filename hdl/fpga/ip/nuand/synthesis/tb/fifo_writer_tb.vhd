
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.bladerf_p.all;
    use work.fifo_readwrite_p.all;

entity fifo_writer_tb is
    generic (
        ENABLE_CHANNEL_0 : std_logic := '1';
        ENABLE_CHANNEL_1 : std_logic := '1';
        EIGHT_BIT_MODE   : std_logic := '1'
    );
end entity;


architecture arch of fifo_writer_tb is

    signal clock : std_logic := '1';
    signal reset : std_logic := '1';

    signal timestamp : unsigned(63 downto 0) := (others => '0');

    signal packet_control    :   packet_control_t := PACKET_CONTROL_DEFAULT;
    signal sample_fifo         : rx_fifo_t           := RX_FIFO_T_DEFAULT;
    signal meta_fifo           : meta_fifo_rx_t      := META_FIFO_RX_T_DEFAULT;

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

    function get_delta_expected return integer is
    begin
        if (EIGHT_BIT_MODE) then
            if (ENABLE_CHANNEL_0 and ENABLE_CHANNEL_1) then
                return 508;
            else
                return 1016;
            end if;
        else
            if (ENABLE_CHANNEL_0 and ENABLE_CHANNEL_1) then
                return 254;
            else
                return 508;
            end if;
        end if;
    end function;

    function get_samples_expected return integer is
    begin
        if (EIGHT_BIT_MODE) then
            return 1016;
        else
            return 508;
        end if;
    end function;

begin

    clock <= not clock after 1 ns;
    reset <= '0' after 5 ns;

    U_fifo_writer : entity work.fifo_writer
        generic map (
            NUM_STREAMS           => 2,
            FIFO_USEDW_WIDTH      => sample_fifo.wused'length,
            FIFO_DATA_WIDTH       => sample_fifo.wdata'length,
            META_FIFO_USEDW_WIDTH => meta_fifo.wused'length,
            META_FIFO_DATA_WIDTH  => meta_fifo.wdata'length
        )
        port map (
            clock               =>  clock,
            reset               =>  reset,
            enable              =>  '1',

            usb_speed           =>  '0', -- SS
            meta_en             =>  '1',
            packet_en           =>  '0',
            timestamp           =>  timestamp,
            mini_exp            =>  "00",

            fifo_full           =>  '0',
            fifo_usedw          =>  (others => '0'),
            fifo_data           =>  sample_fifo.wdata,
            fifo_write          =>  sample_fifo.wreq,
            fifo_clear          =>  open,

            packet_control      =>  packet_control,
            packet_ready        =>  open,

            eight_bit_mode_en   =>  EIGHT_BIT_MODE,

            meta_fifo_full      =>  '0',
            meta_fifo_usedw     =>  (others => '0'),
            meta_fifo_data      =>  meta_fifo.wdata,
            meta_fifo_write     =>  meta_fifo.wreq,

            in_sample_controls  =>  controls,
            in_samples          =>  streams,

            overflow_led        =>  open,
            overflow_count      =>  open,
            overflow_duration   =>  x"ffff"
        );


    gen_streams : process (clock, reset)
        variable count            : unsigned(31 downto 0) := (others => '0');
    begin
        if (reset = '1') then
            count := (others => '0');
            timestamp <= (others => '0');
            controls <= (
                0 => (enable => ENABLE_CHANNEL_0, data_req => '1'),
                1 => (enable => ENABLE_CHANNEL_1, data_req => '1')
            );
        elsif (rising_edge(clock)) then
            for i in controls'range loop

                if( controls(i).enable = '1') then
                    if( streams(i).data_v = '1' ) then
                        if (EIGHT_BIT_MODE) then 
                            -- data_i(11 downto 4)
                            streams(i).data_i <= signed(std_logic_vector(count(11 downto 0)) & b"0000");
                            streams(i).data_q <= signed(std_logic_vector(count(19 downto 8)) & b"0000");
                        else
                            streams(i).data_i <= signed(std_logic_vector(count(15 downto 0)));
                            streams(i).data_q <= signed(std_logic_vector(count(31 downto 16)));
                        end if;
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


    verify: process
        variable sample_count : integer := 0;
        variable curr_timestep : unsigned(63 downto 0) := (others => '0');
        variable next_timestep : unsigned(63 downto 0) := (others => '0');
        variable curr_sample   : unsigned(31 downto 0) := (0 => '1', others => '0'); -- TODO: why starting a cycle too late?
        constant NUM_SAMPLES_EXPECTED : integer := get_samples_expected;
        constant DELTA_EXPECTED : unsigned(63 downto 0) := to_unsigned(get_delta_expected, 64);
        -- Buffer size is 508
    begin
        -- Verify incrimenting timestamps and correct data written

        -- x"FFF" & "11" & sync_mini_exp & x"FFFF" & std_logic_vector(timestamp) & x"12344321";
        nop(clock, 1);

        -- Expecting data in the form:
        --      | 63:48 | 47:32 | 31:16 | 15:0 | Bit indices
        --   1. |   Q1  |   I1  |   Q0  |  I0  | Channels 0 & 1 enabled
        --      | 63:56 | 55:48 | 47:40 | 39:32 | 31:24 | 23:16 |  15:8 |  7:0 | Bit indices
        --   1. |   Q1  |   I1  |   Q0  |  I0   |   Q1  |   I1  |   Q0  |  I0  | Channels 0 & 1 enabled
        if (sample_fifo.wreq) then
            if (EIGHT_BIT_MODE) then
                sample_count := sample_count + 4;

                assert_eq(curr_sample(15 downto 0), unsigned(sample_fifo.wdata(15 downto 0)));
                if (not (ENABLE_CHANNEL_0 and ENABLE_CHANNEL_1)) then
                    curr_sample := curr_sample + 1;
                end if;
                assert_eq(curr_sample(15 downto 0), unsigned(sample_fifo.wdata(31 downto 16)));
                curr_sample := curr_sample + 1;

                assert_eq(curr_sample(15 downto 0), unsigned(sample_fifo.wdata(47 downto 32)));
                if (not (ENABLE_CHANNEL_0 and ENABLE_CHANNEL_1)) then
                    curr_sample := curr_sample + 1;
                end if;
                assert_eq(curr_sample(15 downto 0), unsigned(sample_fifo.wdata(63 downto 48)));
                curr_sample := curr_sample + 1;

            else
                sample_count := sample_count + 2;

                assert_eq(curr_sample, unsigned(sample_fifo.wdata(31 downto 0)));
                if (not (ENABLE_CHANNEL_0 and ENABLE_CHANNEL_1)) then
                    curr_sample := curr_sample + 1;
                end if;
                
                assert_eq(curr_sample, unsigned(sample_fifo.wdata(63 downto 32)));
                curr_sample := curr_sample + 1;

            end if;
        end if;

        if (meta_fifo.wreq) then
            next_timestep := unsigned(meta_fifo.wdata(95 downto 32));
            report "Got meta t = " & integer'image(to_integer(next_timestep));
            report "Got n = " & integer'image(sample_count) & " samples";
            if (curr_timestep /= 0) then
                assert ( next_timestep = (curr_timestep + DELTA_EXPECTED))
                    report "Unexpected time jump, expected " & integer'image(to_integer(curr_timestep + DELTA_EXPECTED)) &
                           " but got " & integer'image(to_integer(next_timestep))
                    severity failure;
                
                assert (sample_count = NUM_SAMPLES_EXPECTED)
                    report "Incorrect number of samples, expected " & integer'image(NUM_SAMPLES_EXPECTED)
                    severity failure;
            end if;
            curr_timestep := next_timestep;
            sample_count := 0;

        end if;
        
        



    end process verify;

end architecture;
