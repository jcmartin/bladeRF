source ../../../ip/nuand/nuand.do

compile_nuand ../../../ip/nuand bladerf-micro

vcom -work nuand -2008 ../../../ip/nuand/synthesis/tb/twelve_bit_packer_tb.vhd

vsim -onfinish stop -work nuand twelve_bit_packer_tb
