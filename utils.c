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

uint64_t convertLittleToBig64(uint64_t x){
    /*uint64_t b0,b1,b2,b3,b4,b5,b6,b7;
    uint64_t res = 0;
    
    b0 = (x & 0x00000000FFFFFFFF) << 32;
    b1 = (x & 0x0000FFFF0000FFFF) << 16;
    b2 = (x & 0x00FF00FF00FF00FF) << 8;
    b3 = (x & 0xFF00FF00FF00FF00) >> 8;
    b4 = (x & 0xFFFF0000FFFF0000) >> 16;
    b5 = (x & 0xFFFFFFFF00000000) >> 32;
    
    res = b0 | b1 | b2 | b3 | b4 | b5 | b6 | b7;*/
    x = (x & 0x00000000FFFFFFFF) << 32 | (x & 0xFFFFFFFF00000000) >> 32;
    x = (x & 0x0000FFFF0000FFFF) << 16 | (x & 0xFFFF0000FFFF0000) >> 16;
    x = (x & 0x00FF00FF00FF00FF) << 8  | (x & 0xFF00FF00FF00FF00) >> 8;
    return x;
}

uint8_t *prepareMessage(uint8_t *initial_msg, size_t initial_len, int *size) {
    return prepareMessage512(initial_msg, initial_len, size);
}

uint8_t *prepareMessage512(uint8_t *initial_msg, size_t initial_len, int *size) {
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

uint8_t *prepareMessage1024(uint8_t *initial_msg, size_t initial_len, int *size) {
    // Message (to prepare)
    uint8_t *msg = NULL;
    
    int new_len;
    for(new_len = initial_len*8 + 1; new_len%1024!=896; new_len++);
    new_len /= 8;
    
    msg = calloc(new_len + 128, 1); // also appends "0" bits
    memcpy(msg, initial_msg, initial_len);
    msg[initial_len] = 128; // write the "1" bit
    
    uint64_t bits_len = 8*initial_len; // note, we append the len
    uint64_t bits_len_big = convertLittleToBig64(bits_len);
    memcpy(msg + new_len + 8, &bits_len_big, 8); // in bits at the end of the buffer
    
    *size = new_len + 8;
    
    return msg;
}



/*
 223  * Pre-processing:
 224  * append the bit '1' to the message
 225  * append k bits '0', where k is the minimum number >= 0 such that the resulting message length (modulo 1024 in bits) is 896.
 226  * append length of message (without the '1' bit or padding), in bits, as 128-bit big-endian integer
 227  * (this will make the entire post-processed length a multiple of 1024 bits)
 228  */
/*void sha512_calc(const uint8_t *ptr, size_t chunk_ln, size_t final_len, hash_t *ctx)
{
         size_t offset;
         for (offset = 0; offset+128 <= chunk_ln; offset += 128)
             sha512_128(ptr + offset, ctx);
         if (offset == chunk_ln && final_len == (size_t)-1)
             return;
         const int remain = chunk_ln - offset;
         uint8_t sha512_buf[128];
         if (remain)
             memcpy(sha512_buf, ptr+offset, remain);
         memset(sha512_buf+remain, 0, 128-remain);
         if (final_len == (size_t)-1) {
             sha512_128(sha512_buf, ctx);
             fprintf(stderr, "sha512: WARN: Incomplete block without EOF!\n");
             return;
         }
         /* EOF */
   /*      sha512_buf[remain] = 0x80;
         if (remain >= 112) {
             sha512_128(sha512_buf, ctx);
             memset(sha512_buf, 0, 116);
         }
         *(uint32_t*)(sha512_buf+116) = htonl(final_len >> 61);
         *(uint32_t*)(sha512_buf+120) = htonl(final_len >> 29);
         *(uint32_t*)(sha512_buf+124) = htonl(final_len <<  3);
         sha512_128(sha512_buf, ctx);
     }*/