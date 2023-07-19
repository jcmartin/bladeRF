/*
 * This file is part of the bladeRF project:
 *   http://www.github.com/nuand/bladeRF
 *
 * Copyright (C) 2014 Nuand LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <limits.h>

#include <libbladeRF.h>
#include <getopt.h>

#include "conversions.h"

/* TODO Make these configurable */
#define BUFFER_SIZE 4096
#define NUM_BUFFERS 128
#define NUM_XFERS   31
#define TIMEOUT_MS  2500

#define SAMPLE_RATE_MIN 520834
#define SAMPLE_RATE_MAX 122880000
#define RESET_EXPECTED  UINT32_MAX

#define OPTSTR "hd:s:p:c:i:m:b:n:x:t:v:"
const struct option long_options[] = {
    { "help",           no_argument,        0,          'h' },
    { "device",         required_argument,  0,          'd' },
    { "samplerate",     required_argument,  0,          's' },
    { "s_per_iter",     required_argument,  0,          'p' },
    { "channels",       required_argument,  0,          'c' },
    { "iterations",     required_argument,  0,          'i' },
    { "mode",           required_argument,  0,          'm' },
    { "buffer_size",    required_argument,  0,          'b' },
    { "num_buffers",    required_argument,  0,          'n' },
    { "num_xfers",      required_argument,  0,          'x' },
    { "timeout",        required_argument,  0,          't' },
    { "verbosity",      required_argument,  0,          'v' },
};

const struct numeric_suffix freq_suffixes[] = {
    { "K",   1000 },
    { "kHz", 1000 },
    { "M",   1000000 },
    { "MHz", 1000000 },
    { "G",   1000000000 },
    { "GHz", 1000000000 },
};

const struct numeric_suffix count_suffixes[] = {
    { "K", 1000 },
    { "M", 1000000 },
    { "G", 1000000000 },
};

struct app_params {
    unsigned int samplerate;
    unsigned int iterations;
    unsigned int samples_per_iter;
    unsigned int buffer_size;
    unsigned int num_buffers;
    unsigned int num_xfers;
    unsigned int timeout;
    char *device_str;
    bladerf_format fmt;
    bladerf_channel_layout layout;
};

static void print_usage(const char *argv0)
{
    printf("Usage: %s [options]\n", argv0);
    printf("libbladerf_test_discont: Test for discontinuities.\n");
    printf("\n");
    printf("Options:\n");
    printf("    -m, --mode <mode>           Specify 16, 12, or 8 mode + meta\n");
    printf("                                    <16> (default)\n");
    printf("                                    <16m>\n");
    printf("                                    <12>\n");
    printf("                                    <12m>\n");
    printf("                                    <8>\n");
    printf("                                    <8m>\n");
    printf("    -c, --channels <value>      Use the number of given channels\n");
    printf("                                    <1> (default)\n");
    printf("                                    <2>\n");
    printf("    -s, --samplerate <value>    Use the specified sample rate.\n");
    printf("    -p, --s_per_iter <value>    Number of samples per iteration.\n");
    printf("    -i, --iterations <count>    Run the specified number of iterations\n");
    printf("    -b, --buffer_size <value>   Set the sync_rx buffer size.\n");
    printf("    -n, --num_buffers <value>   Set the sync_rx number of buffers.\n");
    printf("    -x, --num_xfers <value>     Set the sync_rx number of in-flight buffers.\n");
    printf("    -t, --timeout <value>       Set the sync_rx timeout in ms.\n");
    printf("    -v, --verbosity <value>     Verbosity level\n");
    printf("                                    critical\n");
    printf("                                    error (default)\n");
    printf("                                    warning\n");
    printf("                                    info\n");
    printf("                                    debug\n");
    printf("    -d, --device <devstr>       Device argument string\n");
    printf("    -h, --help                  Print this help text.\n");
    printf("\n");
    printf("Available tests:\n");
    printf("    rx_counter  -   Received samples are derived from the internal\n"
           "                    FPGA counter. Gaps are reported.\n");
    printf("\n");
}

int handle_cmdline(int argc, char *argv[], struct app_params *p)
{
    int c, idx;
    bladerf_log_level lvl;
    bool ok;

    memset(p, 0, sizeof(p[0]));

    p->samplerate = 1000000;
    p->iterations = 10000;
    p->buffer_size = BUFFER_SIZE;
    p->num_buffers = NUM_BUFFERS;
    p->num_xfers = NUM_XFERS;
    p->timeout = TIMEOUT_MS;
    p->device_str = NULL;
    p->fmt        = BLADERF_FORMAT_SC16_Q11;
    p->layout     = BLADERF_RX_X1;
    bladerf_log_set_verbosity(BLADERF_LOG_LEVEL_ERROR);

    while ((c = getopt_long(argc, argv, OPTSTR, long_options, &idx)) >= 0) {
        switch (c) {
            case 's':
                p->samplerate = str2uint_suffix(optarg,
                                                SAMPLE_RATE_MIN,
                                                SAMPLE_RATE_MAX,
                                                freq_suffixes,
                                                ARRAY_SIZE(freq_suffixes),
                                                &ok);
                if (!ok) {
                    fprintf(stderr, "Invalid sample rate: %s\n", optarg);
                    return -1;
                }
                break;

            case 'i':
                p->iterations = str2uint_suffix(optarg,
                                                1, UINT_MAX,
                                                count_suffixes,
                                                ARRAY_SIZE(count_suffixes),
                                                &ok);

                if (!ok) {
                    fprintf(stderr, "Invalid # iterations: %s\n", optarg);
                    return -1;
                }
                break;

            case 'p':
                p->samples_per_iter = str2uint(optarg, 0, UINT_MAX, &ok);
                if (!ok) {
                    fprintf(stderr, "Invalid # of samples per iteration: %s\n", optarg);
                    return -1;
                }
                break;

            case 'b':
                p->buffer_size = str2uint(optarg, 0, UINT_MAX, &ok);
                if (!ok) {
                    fprintf(stderr, "Invalid buffer size: %s\n", optarg);
                    return -1;
                }
                break;

            case 'n':
                p->num_buffers = str2uint(optarg, 0, UINT_MAX, &ok);
                if (!ok) {
                    fprintf(stderr, "Invalid num_buffers: %s\n", optarg);
                    return -1;
                }
                break;

            case 'x':
                p->num_xfers = str2uint(optarg, 0, UINT_MAX, &ok);
                if (!ok) {
                    fprintf(stderr, "Invalid num_xfers: %s\n", optarg);
                    return -1;
                }
                break;
            
            case 't':
                p->timeout = str2uint(optarg, 0, UINT_MAX, &ok);
                if (!ok) {
                    fprintf(stderr, "Invalid timeout: %s\n", optarg);
                    return -1;
                }
                break;
            
            case 'v':
                lvl = str2loglevel(optarg, &ok);
                if (!ok) {
                    fprintf(stderr, "Invalid log level provided: %s\n", optarg);
                    return -1;
                }
                bladerf_log_set_verbosity(lvl);
                break;
            
            case 'd':
                p->device_str = optarg;
                break;

            case 'c':
                if (strcmp(optarg, "1") == 0) {
                    p->layout = BLADERF_RX_X1;
                } else if (strcmp(optarg, "2") == 0) {
                    p->layout = BLADERF_RX_X2;
                } else {
                    fprintf(stderr, "Unknown number of channels: %s\n", optarg);
                    return -1;
                }
                break;

            case 'm':
                if (strcmp(optarg, "16") == 0) {
                    p->fmt = BLADERF_FORMAT_SC16_Q11;
                } else if (strcmp(optarg, "8") == 0) {
                    p->fmt = BLADERF_FORMAT_SC8_Q7;
                } else if (strcmp(optarg, "12") == 0) {
                    p->fmt = BLADERF_FORMAT_SC12_Q11;
                } else if (strcmp(optarg, "16m") == 0) {
                    p->fmt = BLADERF_FORMAT_SC16_Q11_META;
                } else if (strcmp(optarg, "12m") == 0) {
                    p->fmt = BLADERF_FORMAT_SC12_Q11_META;
                } else if (strcmp(optarg, "8m") == 0) {
                    p->fmt = BLADERF_FORMAT_SC8_Q7_META;
                } else {
                    fprintf(stderr, "Unknown bitmode: %s\n", optarg);
                    return -1;
                }
                break;

            case 'h':
                print_usage(argv[0]);
                return 1;
        }
    }

    return 0;
}

int is_meta_format(bladerf_format format) {
    switch (format) {
        case BLADERF_FORMAT_SC16_Q11_META:
        case BLADERF_FORMAT_SC8_Q7_META:
        case BLADERF_FORMAT_SC12_Q11_META:
            return 1;
        default:
            return 0;
    }
}

int set_sample_rate(struct bladerf *dev,
                    bladerf_channel_layout layout,
                    bladerf_sample_rate rate)
{
    int status;
    bladerf_sample_rate actual;
    status = bladerf_set_sample_rate(dev, BLADERF_CHANNEL_RX(0), rate, &actual);
    if (status != 0) {
        fprintf(stderr, "Failed to set RX0 samplerate: %s\n",
                bladerf_strerror(status));
        return status;
    }
    printf("RX1 samplerate set to: %d (requested %d)\n", actual, rate);

    if (layout == BLADERF_RX_X2) {
        status =
            bladerf_set_sample_rate(dev, BLADERF_CHANNEL_RX(1), rate, &actual);

        if (status != 0) {
            fprintf(stderr, "Failed to set RX1 samplerate: %s\n",
                    bladerf_strerror(status));
            return status;
        }
        printf("RX2 samplerate set to: %d (requested %d)\n", actual, rate);
    }
    return status;
}

int enable_rx(struct bladerf *dev, bladerf_channel_layout layout) {
    int status;
    status = bladerf_enable_module(dev, BLADERF_CHANNEL_RX(0), true);
    if (status != 0) {
        fprintf(stderr, "Failed to enable RX0 module: %s\n",
                bladerf_strerror(status));
        return status;
    }

    if (layout == BLADERF_RX_X2) {
        status = bladerf_enable_module(dev, BLADERF_CHANNEL_RX(1), true);
        if (status != 0) {
            fprintf(stderr, "Failed to enable RX1 module: %s\n",
                    bladerf_strerror(status));
            return status;
        }
    }
    return status;
}

int32_t check_12_bit_buffer(
    bool *ok, int16_t *s, int32_t curr, unsigned int n, bool reset)
{
    // 12-bit counters go from -2047 to 2047 with Q = -I
    unsigned int i;
    *ok = true;
    if (reset) {
        curr = s[0];
    }
    for (i = 0; i < n; i++) {
        if (curr != s[2*i] || -curr != s[2*i+1]) {
            printf(
                "Unexpected I/Q, expected (%d :+ %d) got (%d :+ %d)\n",
                curr, -curr, s[2 * i], s[2 * i + 1]);
            *ok = false;
            curr = s[2*i];
        }

        if (curr++ == 2047) {
            curr = -2047;
        }
    }
    
    return curr;
}

int32_t check_8_bit_buffer(
    bool *ok, int16_t *samples, int32_t curr, unsigned int n, bool reset)
{
    // I and Q form a little-endian 16-bit value (shifting done in signal_gen)
    unsigned int i;
    int8_t *s = (int8_t *)samples;
    int8_t curr_i, curr_q;
    *ok = true;
    if (reset) {
        curr = ((int32_t) s[0] & 0xFF) | ((int32_t) s[1] << 8);
    }
    for (i = 0; i < n; i++) {
        curr_i = curr & 0xFF;
        curr_q = (curr >> 8) & 0xFF;
        if (curr_i != s[2*i] || curr_q != s[2*i+1]) {
            printf("Unexpected I/Q, expected (%d :+ %d) got (%d :+ %d)\n",
                   curr_i, curr_q, s[2 * i], s[2 * i + 1]);
            *ok = false;
            curr = ((int32_t) s[2*i] & 0xFF) | ((int32_t) s[2*i+1] << 8);
        }

        curr++;
    }

    return curr;
}

int32_t check_16_bit_buffer(
    bool *ok, int16_t *s, int32_t curr, unsigned int n, bool reset)
{
    // I and Q form a little-endian 32-bit value
    int32_t val;
    unsigned int i;
    *ok = true;
    if (reset) {
        curr = ((int32_t) s[0] & 0xFFFF) | ((int32_t) s[1] << 16);
    }
    for (i = 0; i < n; i++) {
        val = ((int32_t) s[2*i] & 0xFFFF) | ((int32_t) s[2*i+1] << 16);
        if (curr != val) {
            printf("Unexpected I/Q, expected %d got %d\n", curr, val);
            *ok = false;
            curr = val;
        }

        curr++;
    }

    return curr;
}

int run_test(struct bladerf *dev, struct app_params *p)
{
    int status;
    struct bladerf_metadata meta;
    int num_samples = p->samples_per_iter;

    bool is_twelve_bit = p->fmt == BLADERF_FORMAT_SC12_Q11 ||
                         p->fmt == BLADERF_FORMAT_SC12_Q11_META;
    bool is_sixteen_bit = p->fmt == BLADERF_FORMAT_SC16_Q11 ||
                          p->fmt == BLADERF_FORMAT_SC16_Q11_META;
    bool dual_channel = p->layout == BLADERF_RX_X2;
    bool is_meta = is_meta_format(p->fmt);

    unsigned int i, actual_count, n = 0, n_hw_overruns = 0,
                    n_sw_overruns = 0, n_non_contiguous = 0;
    bool is_contiguous0 = true, is_contiguous1 = true, reset = true;
    int32_t curr0, curr1;

    status = bladerf_sync_config(dev, p->layout, p->fmt, p->num_buffers,
                                 p->buffer_size, p->num_xfers, p->timeout);

    if (status != 0) {
        fprintf(stderr, "Failed to configure RX sync i/f: %s\n",
                bladerf_strerror(status));
        return status;
    }

    int16_t *samples1;
    int16_t *samples = malloc(2 * num_samples * sizeof(int16_t));
    if (samples == NULL) {
        perror("malloc");
        status = BLADERF_ERR_UNEXPECTED;
        goto out;
    }

    status = enable_rx(dev, p->layout);
    if (status != 0) {
        goto out;
    }

    int32_t (*check_buffer)(bool *, int16_t *, int32_t, unsigned int, bool);
    bladerf_format deinterleave_format;
    
    if (is_twelve_bit) {
        check_buffer = &check_12_bit_buffer;
    } else if (is_sixteen_bit) {
        check_buffer = &check_16_bit_buffer;
        deinterleave_format = BLADERF_FORMAT_SC16_Q11;
    } else {
        check_buffer = &check_8_bit_buffer;
        deinterleave_format = BLADERF_FORMAT_SC8_Q7;
    }

    printf("Running %u iterations.\n\n", p->iterations);
    memset(&meta, 0, sizeof(meta));
    meta.flags = BLADERF_META_FLAG_RX_NOW;

    for (i = 0; i < p->iterations; i++) {
        status = bladerf_sync_rx(dev, samples, num_samples, &meta, p->timeout);
        if (status != 0) {
            fprintf(stderr, "\nRX failed: %s\n", bladerf_strerror(status));
            break;
        }
        actual_count = num_samples;
        
        if (is_meta) {
            actual_count = meta.actual_count;
            if (meta.status & BLADERF_META_STATUS_HW_OVERRUN) {
                n_hw_overruns++;
                fprintf(stderr,
                        "Iteration %u: Overrun detected in FPGA. %u valid "
                        "samples read.\n",
                        i, actual_count);
            } else if (meta.status & BLADERF_META_STATUS_SW_OVERRUN) {
                n_sw_overruns++;
                fprintf(stderr,
                        "Iteration %u: Overrun detected in host. %u valid "
                        "samples read\n",
                        i, actual_count);
            }
        }
        
        // Check samples
        if (dual_channel) {
            if (is_twelve_bit) {
                status = bladerf_align_and_deinterleave_12_bit_buffer(
                    actual_count, samples);
            } else {
                status = bladerf_deinterleave_stream_buffer(
                    p->layout, deinterleave_format, actual_count, samples);
            }

            if (status != 0) {
                fprintf(stderr, "Failed to deinterleave buffer: %s\n",
                        bladerf_strerror(status));
                goto out;
            }
            
            // Ch-1 samples offset
            samples1 = samples + actual_count;
            actual_count /= 2;

            if (!is_twelve_bit && !is_sixteen_bit) {
                // 8-bit samples take up half the space
                samples1 = samples + actual_count;
            }

            curr1 = (*check_buffer)(&is_contiguous1, samples1,
                                 curr1, actual_count, reset);
        } else if (is_twelve_bit) {
            status = bladerf_align_12_bit_buffer(actual_count, samples);

            if (status != 0) {
                fprintf(stderr, "Failed to align buffer: %s\n",
                        bladerf_strerror(status));
                goto out;
            }
        }

        curr0 = (*check_buffer)(&is_contiguous0, samples, curr0, actual_count,
                                reset);

        if (!is_contiguous0 || !is_contiguous1) {
            n_non_contiguous++;
            fprintf(stderr, "Iteration %u: Non-contiguous detected.\n", i);
        }
        n++;
        reset = false;
    }

    printf("Total Iterations: %u\nDisc: %u\nHW overruns: %u\nSW overruns %u\n",
            n, n_non_contiguous, n_hw_overruns, n_sw_overruns);

out:
    free(samples);
    return status;
}

int main(int argc, char *argv[])
{
    int status;
    struct app_params params;
    struct bladerf *dev;

    status = handle_cmdline(argc, argv, &params);
    if (status != 0) {
        return status != 1 ? status : 0;
    }

    status = bladerf_open(&dev, params.device_str);
    if (status != 0) {
        fprintf(stderr, "Failed to open device: %s\n",
                bladerf_strerror(status));
        return -1;
    }

    bladerf_rx_mux prev_mux = BLADERF_RX_MUX_INVALID, new_mux = BLADERF_RX_MUX_32BIT_COUNTER;
    if (params.fmt == BLADERF_FORMAT_SC12_Q11 || params.fmt == BLADERF_FORMAT_SC12_Q11_META) {
        new_mux = BLADERF_RX_MUX_12BIT_COUNTER;
    }
    bladerf_get_rx_mux(dev, &prev_mux);
    if (status != 0) {
        prev_mux = BLADERF_RX_MUX_INVALID;
    }
    printf("Enabling RX Counter...\n");
    status = bladerf_set_rx_mux(dev, new_mux);
    if (status != 0) {
        fprintf(stderr, "Failed to enable counter: %s\n",
                bladerf_strerror(status));
        goto out;
    }

    if (params.samplerate > 61440000) {
        printf("Enabling oversampling mode...\n");
        status = bladerf_enable_feature(dev, BLADERF_FEATURE_OVERSAMPLE, true);
        if (status != 0) {
            fprintf(stderr, "Failed to enable oversampling mode: %s\n",
                    bladerf_strerror(status));
            goto out;
        }
    }
    
    status = set_sample_rate(dev, params.layout, params.samplerate);
    if (status != 0) {
        goto out;
    }

    status = run_test(dev, &params);

out:
    if (prev_mux != BLADERF_RX_MUX_INVALID) {
        bladerf_set_rx_mux(dev, prev_mux);
    }
    bladerf_close(dev);
    return status;
}
