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
                             unsigned int timeout_ms,
                             bladerf_format format)
{
    int status = 0;
    struct bladerf_metadata meta;
    unsigned int i, n, n_hw_overruns, n_sw_overruns, n_non_contiguous;
    bool is_contiguous;
    int16_t curr_i, curr_q;

    n = 0;
    n_hw_overruns = 0;
    n_sw_overruns = 0;
    n_non_contiguous = 0;

    /* Perform a read immediately, and have the bladerf_sync_rx function
     * provide the timestamp of the read samples */
    memset(&meta, 0, sizeof(meta));
    meta.flags = BLADERF_META_FLAG_RX_NOW;

    /* Receive samples and do work on them */
    for (i = 0; i < rx_count && status == 0; i++) {
        is_contiguous = true;
        status = bladerf_sync_rx(dev, samples, samples_len, &meta, timeout_ms);
        if (status != 0) {
            fprintf(stderr, "RX \"now\" failed: %s\n\n",
                    bladerf_strerror(status));
        } else if (meta.status & BLADERF_META_STATUS_HW_OVERRUN) {
            n_hw_overruns++;
            fprintf(stderr, "Overrun detected in FPGA. %u valid samples were read.\n",
                    meta.actual_count);
        } else if (meta.status & BLADERF_META_STATUS_SW_OVERRUN) {
            n_sw_overruns++;
            fprintf(stderr, "Overrun detected in host. %u valid samples read\n",
                    meta.actual_count);
        } else {
            fflush(stdout);

        }

        if (format == BLADERF_FORMAT_SC12_Q11 || format == BLADERF_FORMAT_SC12_Q11_META)
            bladerf_align_12_bit_buffer(samples_len, samples);

        curr_i = samples[0];
        curr_q = samples[1];

        for (size_t j = 1; j < meta.actual_count-1; j++) {
            // 12-bit counters go from -2047 to 2047 for some reason...
            // Maybe intention was a sign bit and not twos compliment but
            // there is only one 0
            // hdl/fpga/ip/nuand/synthesis/signal_generator.vhd
            if (++curr_i == 2048)
                curr_i = -2047;
            if (--curr_q == -2048)
                curr_q = 2047;

            if (curr_i != samples[2*j]) {
                printf("Unexpected i, expected %x got %x\n", curr_i, samples[2*j]);
                is_contiguous = false;
                curr_i = samples[2*j];
            }

            if (curr_q != samples[2*j+1]) {
                printf("Unexpected q, expected %x got %x\n", curr_q, samples[2*j+1]);
                is_contiguous = false;
                curr_q = samples[2*j+1];
            }
        }
        if (!is_contiguous)
            n_non_contiguous++;
        
        n++;
    }

    printf("Total: %u\nDisc: %u\nHW overruns: %u\nSW overruns %u",
            n, n_non_contiguous, n_hw_overruns, n_sw_overruns);

    return status;
}
/** [rx_meta_now_example] */

static struct option const long_options[] = {
    { "device", required_argument, NULL, 'd' },
    { "mode", required_argument, NULL, 'm' },
    { "rxcount", required_argument, NULL, 'c' },
    { "verbosity", required_argument, 0, 'v' },
    { "help", no_argument, NULL, 'h' },
    { NULL, 0, NULL, 0 },
};

static void usage(const char *argv0)
{
    printf("Usage: %s [options]\n", argv0);
    printf("  -d, --device <str>        Specify device to open.\n");
    printf("  -m, --mode <mode>         Specify mode\n");
    printf("                              <12m> (default, 12-bit meta)\n");
    printf("                              <12> (12-bit)\n");
    printf("                              <16m> (16-bit meta)\n");
    printf("                              <16> (16-bit)\n");
    printf("                              <8m> (8-bit meta)\n");
    printf("                              <8> (8-bit)\n");
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
    bladerf_format fmt  = BLADERF_FORMAT_SC12_Q11_META;

    const unsigned int num_samples = 4096;
    unsigned int rx_count    = 15;
    const unsigned int timeout_ms  = 2500;

    bladerf_log_level lvl = BLADERF_LOG_LEVEL_SILENT;
    bladerf_log_set_verbosity(lvl);
    bool ok;

    int opt = 0;
    int opt_ind = 0;
    while (opt != -1) {
        opt = getopt_long(argc, argv, "d:c:m:v:h", long_options, &opt_ind);

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

            case 'm':
                if (strcmp(optarg, "16") == 0) {
                    fmt = BLADERF_FORMAT_SC16_Q11;
                } else if (strcmp(optarg, "16m") == 0) {
                    fmt = BLADERF_FORMAT_SC16_Q11_META;
                } else if (strcmp(optarg, "12") == 0) {
                    fmt = BLADERF_FORMAT_SC12_Q11;
                } else if (strcmp(optarg, "12m") == 0) {
                    fmt = BLADERF_FORMAT_SC12_Q11_META;
                } else if (strcmp(optarg, "8") == 0) {
                    fmt = BLADERF_FORMAT_SC8_Q7;
                } else if (strcmp(optarg, "8m") == 0) {
                    fmt = BLADERF_FORMAT_SC8_Q7_META;
                } else {
                    printf("Unknown bitmode: %s\n", optarg);
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

    status = bladerf_open(&dev, devstr);
    if (status != 0) {
        fprintf(stderr, "Failed to open device: %s\n",
                bladerf_strerror(status));
        bladerf_close(dev);
        return status;
    }

    status = bladerf_set_frequency(dev, BLADERF_CHANNEL_RX(0), EXAMPLE_RX_FREQ);
    if (status != 0) {
        fprintf(stderr, "Failed to set RX frequency: %s\n",
                bladerf_strerror(status));
        bladerf_close(dev);
        return status;
    } else {
        printf("RX frequency: %u Hz\n", EXAMPLE_RX_FREQ);
    }
    
    bladerf_sample_rate sr;
    status = bladerf_enable_feature(dev, BLADERF_FEATURE_OVERSAMPLE, true);
    status = bladerf_set_sample_rate(dev, BLADERF_CHANNEL_RX(0),
                                     122880000, &sr);

    // status = bladerf_set_sample_rate(dev, BLADERF_CHANNEL_RX(0),
                                    //  EXAMPLE_SAMPLERATE, &sr);
    if (status != 0) {
        fprintf(stderr, "Failed to set RX sample rate: %s\n",
                bladerf_strerror(status));
        bladerf_close(dev);
        return status;
    } else {
        printf("RX samplerate: %u sps\n", sr);
    }

    status = bladerf_set_bandwidth(dev, BLADERF_CHANNEL_RX(0),
                                   EXAMPLE_BANDWIDTH, NULL);
    if (status != 0) {
        fprintf(stderr, "Failed to set RX bandwidth: %s\n",
                bladerf_strerror(status));
        bladerf_close(dev);
        return status;
    } else {
        printf("RX bandwidth: %u Hz\n", EXAMPLE_BANDWIDTH);
    }

    printf("RX Count: %i\n", rx_count);
    bladerf_set_rx_mux(dev, BLADERF_RX_MUX_12BIT_COUNTER);
    samples = init(dev, num_samples, fmt);
    if (samples != NULL) {
        printf("\nRunning RX meta \"now\" example...\n");
        status = sync_rx_meta_now_example(dev, samples, num_samples,
                                          rx_count, timeout_ms, fmt);
    }

    deinit(dev, samples);

    return status;
}
