source ../../../ip/nuand/nuand.do

compile_nuand ../../../ip/nuand bladerf-micro

vcom -work nuand -2008 ../vhdl/rx.vhd
vcom -work nuand -2008 ../vhdl/tx.vhd
vcom -work nuand -2008 ../../common/bladerf/vhdl/fx3_gpif.vhd

vcom -work nuand -2008 ../../common/bladerf/vhdl/tb/fx3_gpif_model.vhd
vcom -work nuand -2008 ../../common/bladerf/vhdl/tb/fx3_gpif_rx_tb.vhd

vsim -work nuand fx3_gpif_rx_tb
