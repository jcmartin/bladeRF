source ./nuand.do

compile_nuand . bladerf-micro
vcom -work nuand -2008 ./synthesis/tb/fifo_writer_tb.vhd


vsim -work nuand fifo_writer_tb

add wave -position insertpoint sim:/fifo_writer_tb/clock
add wave -position insertpoint sim:/fifo_writer_tb/reset
add wave -position insertpoint sim:/fifo_writer_tb/overflow_led
add wave -position insertpoint -radix unsigned sim:/fifo_writer_tb/timestamp
add wave -position insertpoint sim:/fifo_writer_tb/packet_control
add wave -position insertpoint sim:/fifo_writer_tb/packet_ready
add wave -position insertpoint sim:/fifo_writer_tb/sample_fifo
add wave -position insertpoint sim:/fifo_writer_tb/meta_fifo
add wave -position insertpoint sim:/fifo_writer_tb/fifo_clear
add wave -position insertpoint sim:/fifo_writer_tb/controls
add wave -position insertpoint sim:/fifo_writer_tb/streams
add wave -position end  sim:/fifo_writer_tb/U_fifo_writer/meta_current
add wave -position end  sim:/fifo_writer_tb/U_fifo_writer/fifo_current

