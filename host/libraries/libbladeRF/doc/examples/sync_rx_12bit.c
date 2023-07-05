/*
 * Example of RX synchronous interface usage with 12-bit mode
 */

#include <inttypes.h>
#include <libbladeRF.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <getopt.h>

#include "example_common.h"
#include "conversions.h"
#include "log.h"

/* Initialize sync interface for metadata and allocate our "working"
 * buffer that we'd use to process our RX'd samples.
 *
 * Return sample buffer on success, or NULL on failure.
 */

int16_t *init(struct bladerf *dev, int16_t num_samples, bladerf_format format)
{
    int status = -1;

    /* "User" buffer that we read samples into and do work on, and its
     * associated size, in units of samples. Recall that for the
     * SC16Q11 format (native to the ADCs), one sample = two int16_t values.
     *
     * When using the bladerf_sync_* functions, the buffer size isn't
     * restricted to multiples of any particular size.
     *
     * The value for `num_samples` has no major restrictions here, while the
     * `buffer_size` below must be a multiple of 1024.
     */
    int16_t *samples;

    /* These items configure the underlying asynch stream used by the the sync
     * interface. The "buffer" here refers to those used internally by worker
     * threads, not the `samples` buffer above. */
    const unsigned int num_buffers   = 16;
    const unsigned int buffer_size   = 8192;
    const unsigned int num_transfers = 8;
    const unsigned int timeout_ms    = 1000;

    samples = malloc(num_samples * 2 * sizeof(int16_t));
    if (samples == NULL) {
        perror("malloc");
        goto error;
    }

    /** [sync_config] */

    /* Configure the device's RX for use with the sync interface.
     * SC16 Q11 samples *with* metadata are used. */
    status = bladerf_sync_config(dev, BLADERF_RX_X1,
                                 format, num_buffers,
                                 buffer_size, num_transfers, timeout_ms);
    if (status != 0) {
        fprintf(stderr, "Failed to configure RX sync interface: %s\n",
                bladerf_strerror(status));

        goto error;
    }

    /** [sync_config] */

    /* We must always enable the RX front end *after* calling
     * bladerf_sync_config(), and *before* attempting to RX samples via
     * bladerf_sync_rx(). */
    status = bladerf_enable_module(dev, BLADERF_RX, true);
    if (status != 0) {
        fprintf(stderr, "Failed to enable RX: %s\n", bladerf_strerror(status));

        goto error;
    }

    status = 0;

error:
    if (status != 0) {
        free(samples);
        samples = NULL;
    }

    return samples;
}

void deinit(struct bladerf *dev, int16_t *samples)
{
    printf("\nDeinitalizing device.\n");

    /* Disable RX, shutting down our underlying RX stream */
    int status = bladerf_enable_module(dev, BLADERF_RX, false);
    if (status != 0) {
        fprintf(stderr, "Failed to disable RX: %s\n", bladerf_strerror(status));
    }

    /* Deinitialize and free resources */
    free(samples);
    bladerf_close(dev);
}

/** [rx_meta_now_example] */
int sync_rx_meta_now_example(struct bladerf *dev,
                             int16_t *samples,
                             unsigned int samples_len,
                             unsigned int rx_count,
                             unsigned int timeout_ms)
{
    int status = 0;
    struct bladerf_metadata meta;
    uint8_t* samples_bytes = (uint8_t*) samples;
    unsigned int i, rd;
    FILE* fd = fopen("output.bin", "wb");
    if (!fd) {
        fprintf(stderr, "Failed to open output file!");
        return -1;
    }

    /* Perform a read immediately, and have the bladerf_sync_rx function
     * provide the timestamp of the read samples */
    memset(&meta, 0, sizeof(meta));
    meta.flags = BLADERF_META_FLAG_RX_NOW;

    /* Receive samples and do work on them */
    for (i = 0; i < rx_count && status == 0; i++) {
        status = bladerf_sync_rx(dev, samples, samples_len, &meta, timeout_ms);
        if (status != 0) {
            fprintf(stderr, "RX \"now\" failed: %s\n\n",
                    bladerf_strerror(status));
        } else if (meta.status & BLADERF_META_STATUS_OVERRUN) {
            fprintf(stderr, "Overrun detected. %u valid samples were read.\n",
                    meta.actual_count);
        } else {
            printf("RX'd %u samples at t=0x%016" PRIx64 "\n", meta.actual_count,
                   meta.timestamp);

            fflush(stdout);

        }

        rd = fwrite(samples_bytes, 3, samples_len, fd);

        for (size_t j = 0; j < samples_len-1; j++) {
            if(samples_bytes[3*j] + 1 != samples_bytes[3*(j+1)])
                printf("Disc from %x to %x\n", samples_bytes[3*j], samples_bytes[3*(j+1)]);
        }
        printf("Wrote %u 3-byte samples to file\n", rd);
    }
    fclose(fd);
    return status;
}
/** [rx_meta_now_example] */

static struct option const long_options[] = {
    { "device", required_argument, NULL, 'd' },
    { "bitmode", required_argument, NULL, 'b' },
    { "rxcount", required_argument, NULL, 'c' },
    { "verbosity", required_argument, 0, 'v' },
    { "help", no_argument, NULL, 'h' },
    { NULL, 0, NULL, 0 },
};

static void usage(const char *argv0)
{
    printf("Usage: %s [options]\n", argv0);
    printf("  -d, --device <str>        Specify device to open.\n");
    printf("  -b, --bitmode <mode>      Specify 16bit or 8bit mode\n");
    printf("                              <16bit|16> (default)\n");
    printf("                              <8bit|8>\n");
    printf("  -c, --rxcount <int>       Specify # of RX streams\n");
    printf("  -v, --verbosity <level>   Set test verbosity\n");
    printf("  -h, --help                Show this text.\n");
}

int main(int argc, char *argv[])
{
    int status          = -1;
    struct bladerf *dev = NULL;
    const char *devstr  = NULL;
    int16_t *samples    = NULL;
    bladerf_format fmt  = BLADERF_FORMAT_SC12_Q11;

    const unsigned int num_samples = 4096;
    unsigned int rx_count    = 15;
    const unsigned int timeout_ms  = 2500;

    bladerf_log_level lvl = BLADERF_LOG_LEVEL_SILENT;
    bladerf_log_set_verbosity(lvl);
    bool ok;

    int opt = 0;
    int opt_ind = 0;
    while (opt != -1) {
        opt = getopt_long(argc, argv, "d:c:v:h", long_options, &opt_ind);

        switch (opt) {
            case 'd':
                devstr = optarg;
                break;

            case 'c':
                rx_count = str2int(optarg, 1, INT_MAX, &ok);
                if (!ok) {
                    printf("RX count not valid: %s\n", optarg);
                    return -1;
                }
                break;

            case 'v':
                lvl = str2loglevel(optarg, &ok);
                if (!ok) {
                    log_error("Invalid log level provided: %s\n", optarg);
                    return -1;
                } else {
                    bladerf_log_set_verbosity(lvl);
                }
                break;

            case 'h':
                usage(argv[0]);
                return 0;

            default:
                break;
        }
    }

    dev = example_init(devstr);
    printf("Format: ");
    printf("SC12_Q11_META\n");
    printf("RX Count: %i\n", rx_count);
    bladerf_set_rx_mux(dev, BLADERF_RX_MUX_32BIT_COUNTER);

    if (dev) {
        samples = init(dev, num_samples, fmt);
        if (samples != NULL) {
            printf("\nRunning RX meta \"now\" example...\n");
            status = sync_rx_meta_now_example(dev, samples, num_samples,
                                              rx_count, timeout_ms);
        }

        deinit(dev, samples);
    }

    return status;
}
