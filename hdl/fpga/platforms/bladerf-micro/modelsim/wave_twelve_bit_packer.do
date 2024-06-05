onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /twelve_bit_packer_tb/sample_reg
add wave -noupdate /twelve_bit_packer_tb/U_twelve_bit_packer/clock
add wave -noupdate /twelve_bit_packer_tb/U_twelve_bit_packer/current
add wave -noupdate /twelve_bit_packer_tb/U_twelve_bit_packer/i0
add wave -noupdate /twelve_bit_packer_tb/U_twelve_bit_packer/q0
add wave -noupdate /twelve_bit_packer_tb/U_twelve_bit_packer/i1
add wave -noupdate /twelve_bit_packer_tb/U_twelve_bit_packer/q1
add wave -noupdate /twelve_bit_packer_tb/U_twelve_bit_packer/current.q0_p
add wave -noupdate /twelve_bit_packer_tb/U_twelve_bit_packer/current.i1_p
add wave -noupdate /twelve_bit_packer_tb/U_twelve_bit_packer/current.q1_p
add wave -noupdate /twelve_bit_packer_tb/sample_fifo.rreq
add wave -noupdate /twelve_bit_packer_tb/sample_fifo.rdata
add wave -noupdate /twelve_bit_packer_tb/sample_fifo_rreq
add wave -noupdate /twelve_bit_packer_tb/sample_fifo_rdata
add wave -noupdate -divider META
add wave -noupdate /twelve_bit_packer_tb/U_twelve_bit_packer/meta_current
add wave -noupdate /twelve_bit_packer_tb/meta_fifo.rreq
add wave -noupdate /twelve_bit_packer_tb/meta_fifo.rempty
add wave -noupdate /twelve_bit_packer_tb/meta_fifo_rreq
add wave -noupdate /twelve_bit_packer_tb/meta_fifo_rempty
add wave -noupdate /twelve_bit_packer_tb/meta_fifo_rdata
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {95141 ps} 0}
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
WaveRestoreZoom {0 ps} {320436 ps}
