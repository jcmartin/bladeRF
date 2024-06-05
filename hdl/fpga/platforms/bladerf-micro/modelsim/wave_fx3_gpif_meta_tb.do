onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider {RX Sample}
add wave -noupdate /fx3_gpif_meta_tb/U_rx/sample_fifo.wreq
add wave -noupdate /fx3_gpif_meta_tb/U_rx/sample_fifo.wdata
add wave -noupdate /fx3_gpif_meta_tb/rx_sample_fifo.rreq
add wave -noupdate -radix unsigned /fx3_gpif_meta_tb/rx_sample_fifo.rused
add wave -noupdate -radix hexadecimal /fx3_gpif_meta_tb/rx_sample_fifo.rdata
add wave -noupdate -divider {RX Meta}
add wave -noupdate /fx3_gpif_meta_tb/U_rx/meta_fifo.wreq
add wave -noupdate /fx3_gpif_meta_tb/U_rx/meta_fifo.wdata
add wave -noupdate /fx3_gpif_meta_tb/rx_meta_fifo.rreq
add wave -noupdate -radix decimal /fx3_gpif_meta_tb/rx_meta_fifo.rused
add wave -noupdate -radix hexadecimal /fx3_gpif_meta_tb/rx_meta_fifo.rdata
add wave -noupdate -divider {TX Sample}
add wave -noupdate /fx3_gpif_meta_tb/tx_sample_fifo.wfull
add wave -noupdate /fx3_gpif_meta_tb/tx_sample_fifo.wreq
add wave -noupdate /fx3_gpif_meta_tb/tx_sample_fifo.rreq
add wave -noupdate -radix decimal /fx3_gpif_meta_tb/tx_sample_fifo.rused
add wave -noupdate -radix hexadecimal /fx3_gpif_meta_tb/tx_sample_fifo.rdata
add wave -noupdate -divider {TX Meta}
add wave -noupdate /fx3_gpif_meta_tb/tx_meta_fifo.wfull
add wave -noupdate /fx3_gpif_meta_tb/tx_meta_fifo.wreq
add wave -noupdate /fx3_gpif_meta_tb/tx_meta_fifo.rreq
add wave -noupdate -radix decimal /fx3_gpif_meta_tb/tx_meta_fifo.rused
add wave -noupdate -radix hexadecimal /fx3_gpif_meta_tb/tx_meta_fifo.rdata
add wave -noupdate -divider GPIF
add wave -noupdate /fx3_gpif_meta_tb/U_fx3_gpif/current
add wave -noupdate /fx3_gpif_meta_tb/U_fx3_gpif/dma_req
add wave -noupdate /fx3_gpif_meta_tb/U_fx3_gpif/can_rx
add wave -noupdate /fx3_gpif_meta_tb/U_fx3_gpif/should_rx
add wave -noupdate /fx3_gpif_meta_tb/U_fx3_gpif/rx_fifo_enough
add wave -noupdate /fx3_gpif_meta_tb/U_fx3_gpif/rx_fifo_critical
add wave -noupdate /fx3_gpif_meta_tb/U_fx3_gpif/can_tx
add wave -noupdate /fx3_gpif_meta_tb/U_fx3_gpif/should_tx
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {1159123623 ps} 0}
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
WaveRestoreZoom {0 ps} {5250 us}
