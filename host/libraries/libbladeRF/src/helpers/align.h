/**
 * @file align.h
 * 
 */

#include <inttypes.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#ifndef HELPERS_ALIGN_H_
#define HELPERS_ALIGN_H_

#define NUM_CH 2

/**
 * Align and sign extend a buffer packed with 12 bit LE samples, input sample 
 * buffer should be large enough to hold all samples (2 * n * sizeof(int16_t))
 * 
 * @param s Buffer to process
 * @param n Number of 12-bit IQ samples 
 *
 */
int _align_12bit(uint8_t* s, unsigned int n);

/**
 * In addition to aligning and sign extending a buffer containing 12-bit 
 * samples, this also deinterleaves samples from two channels into contiguous
 * sections.
 * 
 * @param s Buffer to process
 * @param n Total number of 12-bit IQ samples (across entire buffer, not just  
 *          one channel)
 * @return int 
 */
int _align_and_deinterleave_12bit(uint8_t* s, unsigned int n);

#endif
