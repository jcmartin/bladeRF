-- A model for the state machine and actions inside of the fx3 interacting with
-- the GPIF during RX


library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

entity fx3_gpif_model is
  port (
    pclk                :   in      std_logic;
    reset               :   in      std_logic;
    gpif                :   in      std_logic_vector(31 downto 0);
    ctl                 :   inout   std_logic_vector(12 downto 0);
    dma0                :   out     std_logic_vector(31 downto 0);
    dma0_valid          :   out     std_logic;
    dma1                :   out     std_logic_vector(31 downto 0);
    dma1_valid          :   out     std_logic
  );
end entity;

architecture arch of fx3_gpif_model is

    alias dma0_rx_ack   is ctl(0);
    alias dma1_rx_ack   is ctl(1);
    alias dma2_tx_ack   is ctl(2);
    alias dma3_tx_ack   is ctl(3);
    alias dma_rx_enable is ctl(4);
    alias dma_tx_enable is ctl(5);
    alias dma_idle      is ctl(6);
    alias sys_reset     is ctl(7);
    alias dma0_rx_reqx  is ctl(8);
    alias dma1_rx_reqx  is ctl(12);
    alias dma2_tx_reqx  is ctl(10);
    alias dma3_tx_reqx  is ctl(11);

    constant DMA_DOWNCOUNT_RESET        : natural := 512; -- 2048 bytes
    constant DMA_READY_DOWNCOUNT_RESET  : natural := 50;

    type state_t is (START, INIT, WAIT_0, IF_RX, IF_RX_0, IF_RX_1, DONE);

    type fsm_t is record
        state                   : state_t;
        dma_downcount           : integer range 0 to DMA_DOWNCOUNT_RESET;
        dma0_ready              : std_logic;
        dma0_ready_downcount    : integer range 0 to DMA_READY_DOWNCOUNT_RESET;
        dma1_ready              : std_logic;
        dma1_ready_downcount    : integer range 0 to DMA_READY_DOWNCOUNT_RESET;
    end record;

    constant FSM_RESET_VALUE : fsm_t := (
        state => START,
        dma_downcount => 0,
        dma0_ready => '0',
        dma0_ready_downcount => 0,
        dma1_ready => '0',
        dma1_ready_downcount => 0
    );

    signal current, future : fsm_t := FSM_RESET_VALUE;

begin
    
    -- Synchronous process for FSM
    fsm_sync_proc : process(reset, pclk) is
    begin
        if (reset = '1') then
            current <= FSM_RESET_VALUE;
        elsif (rising_edge(pclk)) then
            current <= future;
        end if;
    end process fsm_sync_proc;


    -- Combinatorial process for FSM
    fsm_comb_proc : process(all) is
    begin
        future      <= current;
        sys_reset   <= '0';
        dma_idle    <= '0';
        dma0        <= (others => 'X');
        dma0_valid  <= '0';
        dma1        <= (others => 'X');
        dma1_valid  <= '0';
        
        if (current.dma0_ready = '0') then
            if (current.dma0_ready_downcount = 0) then
                future.dma0_ready <= '1';
            else
                future.dma0_ready_downcount <= current.dma0_ready_downcount - 1;
            end if;
        end if;

        if (current.dma1_ready = '0') then
            if (current.dma1_ready_downcount = 0) then
                future.dma1_ready <= '1';
            else
                future.dma1_ready_downcount <= current.dma1_ready_downcount - 1;
            end if;
        end if;

        case (current.state) is
            when START =>
                future.state <= INIT;
            when INIT =>
                sys_reset <= '1';
                future.state <= WAIT_0;
            when WAIT_0 =>
                dma_idle <= '1';
                if (dma0_rx_ack = '1' or dma1_rx_ack = '1') then
                    future.state <= IF_RX;
                    future.dma_downcount <= DMA_DOWNCOUNT_RESET;
                end if;
            when IF_RX =>
                if (dma0_rx_ack = '1') then
                    future.state <= IF_RX_0;
                elsif (dma1_rx_ack = '1') then
                    future.state <= IF_RX_1;
                end if;
            when IF_RX_0 =>
                dma0 <= gpif;
                dma0_valid <= '1';
                dma1 <= (others => 'X');

                if (current.dma_downcount = 0) then
                    future.state <= DONE;
                    future.dma0_ready <= '0';
                    future.dma0_ready_downcount <= DMA_READY_DOWNCOUNT_RESET;
                else
                    future.dma_downcount <= current.dma_downcount - 1;
                end if;
            when IF_RX_1 =>
                dma0 <= (others => 'X');
                dma1 <= gpif;
                dma1_valid <= '1';

                if (current.dma_downcount = 0) then
                    future.state <= DONE;
                    future.dma1_ready <= '0';
                    future.dma1_ready_downcount <= DMA_READY_DOWNCOUNT_RESET;
                else
                    future.dma_downcount <= current.dma_downcount - 1;
                end if;
            when DONE =>
                future.state <= WAIT_0;
        end case;
        
    end process;

    fsm_output : process(current) is
    begin
        dma_rx_enable <= '1';
        dma_tx_enable <= '0';
        dma0_rx_reqx <= not current.dma0_ready;
        dma1_rx_reqx <= not current.dma1_ready;
        dma2_tx_reqx <= '0';
        dma3_tx_reqx <= '0';       
    end process fsm_output;

    

end architecture arch;


