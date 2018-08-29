#include <stdio.h>
#include <stdlib.h>
#include <inttypes.h>
#include <stdint.h>
#include <string.h>

#include "utils.h"

//assumes little endian
void printBits(size_t const size, void const * const ptr)
{
    unsigned char *b = (unsigned char*) ptr;
    unsigned char byte;
    int i, j;
    
    for (i=size-1;i>=0;i--)
    {
        for (j=7;j>=0;j--)
        {
            byte = (b[i] >> j) & 1;
            printf("%u", byte);
        }
    }
    //puts("");
}

void printStream(uint8_t *bits, int size){
    for(int i=0; i<size; i++){
        printBits(sizeof(bits[i]), &bits[i]);
    }
}

uint32_t convertLittleToBig(uint32_t num){
    uint32_t b0,b1,b2,b3;
    uint32_t res = 0;
    b0 = (num & 0xff) << 24;        // least significant to most significant
    b1 = (num & 0xff00) << 8;       // 2nd least sig. to 2nd most sig.
    b2 = (num & 0xff0000) >> 8;     // 2nd most sig. to 2nd least sig.
    b3 = (num & 0xff000000) >> 24;  // most sig. to least sig.
    res = b0 | b1 | b2 | b3 ;
    
    return res;
}

uint8_t *prepareMessage(uint8_t *initial_msg, size_t initial_len, int *size) {
    // Message (to prepare)
    uint8_t *msg = NULL;
    
    int new_len;
    for(new_len = initial_len*8 + 1; new_len%512!=448; new_len++);
    new_len /= 8;
    
    msg = calloc(new_len + 64, 1); // also appends "0" bits
    memcpy(msg, initial_msg, initial_len);
    msg[initial_len] = 128; // write the "1" bit
    
    uint32_t bits_len = 8*initial_len; // note, we append the len
    uint32_t bits_len_big = convertLittleToBig(bits_len);
    memcpy(msg + new_len + 4, &bits_len_big, 4); // in bits at the end of the buffer
    
    *size = new_len + 8;
    
    return msg;
}