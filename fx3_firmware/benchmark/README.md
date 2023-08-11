# USB Benchmark

This firmware can be used with the `libbladeRF_test_usb_benchmark` (or the Cypress Streamer application on Windows) to benchmark the throughput various DMA configurations from the GPIF -> host. The firmware contains a GPIF state machine that continuously reads from the GPIF 32b bus into 2 alternating DMA sockets (the time to switch buffers in one socket is not deterministic but can last a few microseconds while switching sockets happens in one clock cycle). An auto many-to-one DMA channel is created with the sizes specified in `benchmark.h`, interleaving buffers from the two GPIF sockets into the USB endpoint.

## Usage

Follow the instructions in `fx3_firmware/README.md` to make the firmware, setting `-DENABLE_FX3_BENCHMARK=ON` to make the benchmark firmware, which ends up in `output/benchmark.img`.

In order to upload the firmware, the device needs to be in bootloader mode. This can be done in one of two ways:

- Start uploading firmware using `bladeRF-cli -f <file>` but disconnect the device partway through, corrupting the image in flash and forcing the FX3 to fall back to the USB bootloader.
- Place a jumper across one of the SPI communication pins, causing the boot from flash to fail as described [here](https://github.com/Nuand/bladeRF/wiki/Upgrading-bladeRF-FX3-Firmware#upgrading-using-the-fx3-bootloader-recovery-method) (For bladeRF2‑micro, short pins 1 and 2 of the J6 header).

Now the firmware can be loaded in one of two ways:

- Compile and run the `download_fx3` program included with the FX3 SDK. For macOS this looks like `$FX3_INSTALL_PATH/../cyusb_mac_1.0/examples/download_fx3 -t RAM -i output/benchmark.img`
- Use the `recover` command in `bladeRF-cli -i`

NOTE: Both of these methods only loads the firmware to RAM without writing to flash. This is recommended because the only way to load bladeRF firmware if this benchmark image is in flash is to short the SPI pins to force the bootloader. The `bladeRF-cli -f` command will not work while the benchmark image is loaded.

## Endpoints

This firmware provides two endpoints, a BULK-IN (0x81) for benchmarking GPIF transactions and an INTERRUPT-IN (0x82) for sending debug messages.

## Results

These results are from a 2023 MacBook Pro (Host Controller Driver: AppleT8112USBXHCI) using `libbladeRF_test_usb_benchmark` with 4 in-flight 1 MiB transfers.

| Burst Length | DMA Buffer Size | DMA Buffer Count | Throughput (Gbps) |
| ------------ | --------------- | ---------------- | ----------------- |
| 1            | 2048            | 22               | 2.399063          |
| 16           | 2048            | 22               | 2.944465          |
| 16           | 16384           | 3                | 3.054650          |

The first row corresponds to the effective settings of the original, the second row corresponds with combining several DMA buffers into one burst (refer to the note at the bottom), and the third row corresponds to the current setting with larger buffers.

## Notes

- By default, the FX3 does not try to combine data from multiple DMA buffers into a single burst transfer on the USB side, this can be remedied by combining multiple buffers using the `CyU3PUsbEPSetBurstMode()` (which incurs the microsecond latencies associated with buffer switching) or by setting buffer sizes to 16 x 1024 bytes = 16 KB as suggested in page 45 of [AN75779](<https://www.infineon.com/dgdl/Infineon-AN75779_How_to_Implement_an_Image_Sensor_Interface_with_EZ-USB_FX3_in_a_USB_Video_Class_(UVC)_Framework-ApplicationNotes-v13_00-EN.pdf?fileId=8ac78c8c7cdc391c017d073ad2b85f0d>)
  - Just setting burst mode for the bladeRF fx3 maxed out at 120 Msps for 12-bit mode
- The FX3 contains 512 KB of system memory, split between DMA descriptors, code, data, and DMA buffers (the Programmers Manual shows a typical size of 256 KB for DMA buffers)
