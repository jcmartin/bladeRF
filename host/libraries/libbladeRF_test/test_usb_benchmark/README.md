# USB Benchmark

In order to run this test, the FX3 device needs to be loaded with firmware that
is capable of sending the required amount of data with no other intervention. 
The `benchmark` firmware in `fx3_firmware` will act as a data source,
continuously pulling data from the fx3's GPIF (and therefore will be going 
through the GPIF, which will form the bottleneck @ 400 MBps). Refer to the 
`README.md` in `fx3_firmware/benchmark` for information on how to load the
firmware.

## Usage

Update the parameters at the top of `src/main.c` to update:
- The `VID` and `PID` of the device that the test attempts to open
- `N_XFERS`, the total number of transfers the test attempts to perform
- `N_IN_FLIGHT`, the number of transfers in flight at a given time (>1 to 
  overcome transfer associated latencies)
- `XFER_SIZE`, the size of each individual transfer in bytes, larger is better (
  max of 4MiB)
- `EP_IN`, the address of the BULK-IN endpoint to benchmark
- `EP_DEBUG`, the address of the INTERRUPT-IN endpoint used to send debug 
  messages from the fx3 (not currently read)
