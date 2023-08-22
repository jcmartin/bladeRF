onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider {RX Sample}
add wave -noupdate /fx3_gpif_meta_tb/rx_sample_fifo.wfull
add wave -noupdate /fx3_gpif_meta_tb/rx_sample_fifo.wreq
add wave -noupdate /fx3_gpif_meta_tb/rx_sample_fifo.rreq
add wave -noupdate -radix unsigned /fx3_gpif_meta_tb/rx_sample_fifo.rused
add wave -noupdate -radix hexadecimal /fx3_gpif_meta_tb/rx_sample_fifo.rdata
add wave -noupdate -divider {TX Sample}
add wave -noupdate /fx3_gpif_meta_tb/tx_sample_fifo.wfull
add wave -noupdate /fx3_gpif_meta_tb/tx_sample_fifo.wreq
add wave -noupdate /fx3_gpif_meta_tb/tx_sample_fifo.rreq
add wave -noupdate -radix decimal /fx3_gpif_meta_tb/tx_sample_fifo.rused
add wave -noupdate -radix hexadecimal /fx3_gpif_meta_tb/tx_sample_fifo.rdata
add wave -noupdate -divider {RX Meta}
add wave -noupdate /fx3_gpif_meta_tb/rx_meta_fifo.wfull
add wave -noupdate /fx3_gpif_meta_tb/rx_meta_fifo.wreq
add wave -noupdate /fx3_gpif_meta_tb/rx_meta_fifo.rreq
add wave -noupdate -radix decimal /fx3_gpif_meta_tb/rx_meta_fifo.rused
add wave -noupdate -radix hexadecimal /fx3_gpif_meta_tb/rx_meta_fifo.rdata
add wave -noupdate -divider {TX Meta}
add wave -noupdate /fx3_gpif_meta_tb/tx_meta_fifo.wfull
add wave -noupdate /fx3_gpif_meta_tb/tx_meta_fifo.wreq
add wave -noupdate /fx3_gpif_meta_tb/tx_meta_fifo.rreq
add wave -noupdate -radix decimal /fx3_gpif_meta_tb/tx_meta_fifo.rused
add wave -noupdate -radix hexadecimal /fx3_gpif_meta_tb/tx_meta_fifo.rdata
add wave -noupdate -divider <NULL>
add wave -noupdate -expand /fx3_gpif_meta_tb/U_tx/U_fifo_reader/meta_current
add wave -noupdate -expand /fx3_gpif_meta_tb/U_tx/U_fifo_reader/fifo_current
add wave -noupdate -expand -subitemconfig {/fx3_gpif_meta_tb/dac_streams(0) -expand} /fx3_gpif_meta_tb/dac_streams
add wave -noupdate -radix hexadecimal /fx3_gpif_meta_tb/tx_timestamp
add wave -noupdate -radix hexadecimal /fx3_gpif_meta_tb/tx_sample_start_check/timestamp_in_header
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {41655131 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 150
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ps
update
WaveRestoreZoom {39658267 ps} {42123603 ps}
