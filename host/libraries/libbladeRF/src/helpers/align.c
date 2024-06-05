/**
 * @file align.c
 * 
 * This is used to take packed 12-bit samples, sign-extend and byte align them,
 * optionally deinterleaving two channels.
 * 
 */

#include "helpers/align.h"

int _align_12bit(uint8_t* s, unsigned int n) {
    int16_t* buf = malloc(2 * n * sizeof(int16_t));
    uint32_t iq;
    int16_t x;

    for (unsigned int i = 0; i < n; i++) {
        iq = (s[3*i+2] << 16) | (s[3*i+1] << 8) | s[3*i];

        x = (iq & 0xFFF) << 4;
        buf[2*i] = x >> 4;

        x = iq >> 8 & 0xFFF0;
        buf[2*i+1] = x >> 4;
    }

    memcpy(s, buf, 2 * n * sizeof(int16_t));
    free(buf);
    return 0;
}

int _align_and_deinterleave_12bit(uint8_t* s, unsigned int n) {
    int16_t* buf = malloc(2 * n * sizeof(int16_t));
    uint32_t iq;
    int16_t x;
    unsigned int n_per_ch, src_idx, i, ch;
    
    n_per_ch = n / NUM_CH;

    for (i = 0; i < n_per_ch; i++) {
        for (ch = 0; ch < NUM_CH; ch++) {
            src_idx = NUM_CH * i + ch;
            iq = (s[3*src_idx+2] << 16) | (s[3*src_idx+1] << 8) | s[3*src_idx];

            x = (iq & 0xFFF) << 4;
            buf[2*(n_per_ch * ch + i)] = x >> 4;

            x = iq >> 8 & 0xFFF0;
            buf[2*(n_per_ch * ch + i) + 1] = x >> 4;
        }
    }

    memcpy(s, buf, 2 * n * sizeof(int16_t));
    free(buf);
    return 0;
}
