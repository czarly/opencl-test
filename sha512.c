//#include <string.h>
//#include <stdio.h>
#include "sha512.h"

typedef unsigned char uint8_t;
#define uint32_t unsigned int
#define uint64_t unsigned long long

static const inline uint64_t right_rot(uint64_t value, unsigned int count)
{
    /*
     * Defined behaviour in standard C for all count where 0 < count < 64,
     * which is what we need here.
     */
    return value >> count | value << (64 - count);
}

static void processChunk(uint8_t chunk[128], uint64_t hi[]){
    
    uint64_t k[80] = {
        0x428a2f98d728ae22, 0x7137449123ef65cd, 0xb5c0fbcfec4d3b2f, 0xe9b5dba58189dbbc, 0x3956c25bf348b538,
        0x59f111f1b605d019, 0x923f82a4af194f9b, 0xab1c5ed5da6d8118, 0xd807aa98a3030242, 0x12835b0145706fbe,
        0x243185be4ee4b28c, 0x550c7dc3d5ffb4e2, 0x72be5d74f27b896f, 0x80deb1fe3b1696b1, 0x9bdc06a725c71235,
        0xc19bf174cf692694, 0xe49b69c19ef14ad2, 0xefbe4786384f25e3, 0x0fc19dc68b8cd5b5, 0x240ca1cc77ac9c65,
        0x2de92c6f592b0275, 0x4a7484aa6ea6e483, 0x5cb0a9dcbd41fbd4, 0x76f988da831153b5, 0x983e5152ee66dfab,
        0xa831c66d2db43210, 0xb00327c898fb213f, 0xbf597fc7beef0ee4, 0xc6e00bf33da88fc2, 0xd5a79147930aa725,
        0x06ca6351e003826f, 0x142929670a0e6e70, 0x27b70a8546d22ffc, 0x2e1b21385c26c926, 0x4d2c6dfc5ac42aed,
        0x53380d139d95b3df, 0x650a73548baf63de, 0x766a0abb3c77b2a8, 0x81c2c92e47edaee6, 0x92722c851482353b,
        0xa2bfe8a14cf10364, 0xa81a664bbc423001, 0xc24b8b70d0f89791, 0xc76c51a30654be30, 0xd192e819d6ef5218,
        0xd69906245565a910, 0xf40e35855771202a, 0x106aa07032bbd1b8, 0x19a4c116b8d2d0c8, 0x1e376c085141ab53,
        0x2748774cdf8eeb99, 0x34b0bcb5e19b48a8, 0x391c0cb3c5c95a63, 0x4ed8aa4ae3418acb, 0x5b9cca4f7763e373,
        0x682e6ff3d6b2b8a3, 0x748f82ee5defb2fc, 0x78a5636f43172f60, 0x84c87814a1f0ab72, 0x8cc702081a6439ec,
        0x90befffa23631e28, 0xa4506cebde82bde9, 0xbef9a3f7b2c67915, 0xc67178f2e372532b, 0xca273eceea26619c,
        0xd186b8c721c0c207, 0xeada7dd6cde0eb1e, 0xf57d4f7fee6ed178, 0x06f067aa72176fba, 0x0a637dc5a2c898a6,
        0x113f9804bef90dae, 0x1b710b35131c471b, 0x28db77f523047d84, 0x32caab7b40c72493, 0x3c9ebe0a15c9bebc,
        0x431d67c49c100d4c, 0x4cc5d4becb3e42b6, 0x597f299cfc657e2a, 0x5fcb6fab3ad6faec, 0x6c44198c4a475817
    };
    
    uint64_t a, b, c, d, e, f, g, h;
    
    /*
     * create a 64-entry message schedule array w[0..63] of 32-bit words
     * (The initial values in w[0..63] don't matter, so many implementations zero them here)
     * copy chunk into first 16 words w[0..15] of the message schedule array
     */
    uint64_t w[80];
    const uint8_t *p = chunk;
    int i;
    
    //memset(w, 0x00, sizeof w);
    for (i = 0; i < 16; i++) {
        w[i] = (uint64_t) p[0] << 56 | (uint64_t) p[1] << 48 | (uint64_t) p[2] << 40 | (uint64_t) p[3] << 32 | (uint64_t) p[4] << 24 | (uint64_t) p[5] << 16 | (uint64_t) p[6] << 8 | (uint64_t) p[7];
        p += 8;
    }
    
    /* Extend the first 16 words into the remaining 48 words w[16..63] of the message schedule array: */
    for (i = 16; i < 79; i++) {
        
        /*
         s0 := (w[i-15] rightrotate 7) xor (w[i-15] rightrotate 18) xor (w[i-15] rightshift 3)
         s1 := (w[i-2] rightrotate 17) xor (w[i-2] rightrotate 19) xor (w[i-2] rightshift 10)
         */
        
        // const uint32_t s0 = right_rot(w[i - 15], 7) ^ right_rot(w[i - 15], 18) ^ (w[i - 15] >> 3);
        // const uint32_t s1 = right_rot(w[i - 2], 17) ^ right_rot(w[i - 2], 19) ^ (w[i - 2] >> 10);
        
        /*
         s0 := (w[i-15] rightrotate 1) xor (w[i-15] rightrotate 8) xor (w[i-15] rightshift 7)
         s1 := (w[i-2] rightrotate 19) xor (w[i-2] rightrotate 61) xor (w[i-2] rightshift 6)
         */
        const uint64_t s0 = right_rot(w[i - 15], 1) ^ right_rot(w[i - 15], 8) ^ (w[i - 15] >> 7);
        const uint64_t s1 = right_rot(w[i - 2], 19) ^ right_rot(w[i - 2], 61) ^ (w[i - 2] >> 6);
        
        w[i] = w[i - 16] + s0 + w[i - 7] + s1;
    }
    
    /* Initialize working variables to current hash value: */
    a = hi[0];
    b = hi[1];
    c = hi[2];
    d = hi[3];
    e = hi[4];
    f = hi[5];
    g = hi[6];
    h = hi[7];
    
    /* Compression function main loop: */
    for (i = 0; i < 80; i++) {
        // S1 := (e rightrotate 6) xor (e rightrotate 11) xor (e rightrotate 25)
        // const uint32_t s1 = right_rot(e, 6) ^ right_rot(e, 11) ^ right_rot(e, 25);
        // S1 := (e rightrotate 14) xor (e rightrotate 18) xor (e rightrotate 41)
        const uint64_t s1 = right_rot(e, 14) ^ right_rot(e, 18) ^ right_rot(e, 41);
        const uint64_t ch = (e & f) ^ (~e & g);
        const uint64_t temp1 = h + s1 + ch + k[i] + w[i];
        
        // S0 := (a rightrotate 2) xor (a rightrotate 13) xor (a rightrotate 22)
        // const uint32_t s0 = right_rot(a, 2) ^ right_rot(a, 13) ^ right_rot(a, 22);
        // S0 := (a rightrotate 28) xor (a rightrotate 34) xor (a rightrotate 39)
        const uint64_t s0 = right_rot(a, 28) ^ right_rot(a, 34) ^ right_rot(a, 39);
        const uint64_t maj = (a & b) ^ (a & c) ^ (b & c);
        const uint64_t temp2 = s0 + maj;
        
        h = g;
        g = f;
        f = e;
        e = d + temp1;
        d = c;
        c = b;
        b = a;
        a = temp1 + temp2;
    }
    
    /* Add the compressed chunk to the current hash value: */
    hi[0] = hi[0] + a;
    hi[1] = hi[1] + b;
    hi[2] = hi[2] + c;
    hi[3] = hi[3] + d;
    hi[4] = hi[4] + e;
    hi[5] = hi[5] + f;
    hi[6] = hi[6] + g;
    hi[7] = hi[7] + h;
    
}

static void processChunks(uint8_t *bits, uint8_t *len, uint8_t *hash){
    //uint32_t h[] = { 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19 };
    uint64_t h[] = { 0x6a09e667f3bcc908, 0xbb67ae8584caa73b, 0x3c6ef372fe94f82b, 0xa54ff53a5f1d36f1, 0x510e527fade682d1, 0x9b05688c2b3e6c1f, 0x1f83d9abfb41bd6b, 0x5be0cd19137e2179 };
    
    //printf("%d\n", h[0]);
    
    for(int i=0; (i * 128) < *len; i++){
        processChunk(bits + i * 128, h);
    }
    
    //printf("%d\n", h[0]);
    
    //uint8_t hash[32];
    
    /* Produce the final hash value (big-endian): */
    hash[0] = (uint8_t) (h[0] >> 56);
    hash[1] = (uint8_t) (h[0] >> 48);
    hash[2] = (uint8_t) (h[0] >> 40);
    hash[3] = (uint8_t) (h[0] >> 32);
    hash[4] = (uint8_t) (h[0] >> 24);
    hash[5] = (uint8_t) (h[0] >> 16);
    hash[6] = (uint8_t) (h[0] >> 8);
    hash[7] = (uint8_t) h[0];
    
    hash[8] = (uint8_t) (h[1] >> 56);
    hash[9] = (uint8_t) (h[1] >> 48);
    hash[10] = (uint8_t) (h[1] >> 40);
    hash[11] = (uint8_t) (h[1] >> 32);
    hash[12] = (uint8_t) (h[1] >> 24);
    hash[13] = (uint8_t) (h[1] >> 16);
    hash[14] = (uint8_t) (h[1] >> 8);
    hash[15] = (uint8_t) h[1];

    hash[16] = (uint8_t) (h[2] >> 56);
    hash[17] = (uint8_t) (h[2] >> 48);
    hash[18] = (uint8_t) (h[2] >> 40);
    hash[19] = (uint8_t) (h[2] >> 32);
    hash[20] = (uint8_t) (h[2] >> 24);
    hash[21] = (uint8_t) (h[2] >> 16);
    hash[22] = (uint8_t) (h[2] >> 8);
    hash[23] = (uint8_t) h[2];

    hash[24] = (uint8_t) (h[3] >> 56);
    hash[25] = (uint8_t) (h[3] >> 48);
    hash[26] = (uint8_t) (h[3] >> 40);
    hash[27] = (uint8_t) (h[3] >> 32);
    hash[28] = (uint8_t) (h[3] >> 24);
    hash[29] = (uint8_t) (h[3] >> 16);
    hash[30] = (uint8_t) (h[3] >> 8);
    hash[31] = (uint8_t) h[3];

    hash[32] = (uint8_t) (h[4] >> 56);
    hash[33] = (uint8_t) (h[4] >> 48);
    hash[34] = (uint8_t) (h[4] >> 40);
    hash[35] = (uint8_t) (h[4] >> 32);
    hash[36] = (uint8_t) (h[4] >> 24);
    hash[37] = (uint8_t) (h[4] >> 16);
    hash[38] = (uint8_t) (h[4] >> 8);
    hash[39] = (uint8_t) h[4];

    // ab hier schon gut
    
    hash[40] = (uint8_t) (h[5] >> 56);
    hash[41] = (uint8_t) (h[5] >> 48);
    hash[42] = (uint8_t) (h[5] >> 40);
    hash[43] = (uint8_t) (h[5] >> 32);
    hash[44] = (uint8_t) (h[5] >> 24);
    hash[45] = (uint8_t) (h[5] >> 16);
    hash[46] = (uint8_t) (h[5] >> 8);
    hash[47] = (uint8_t) h[5];

    hash[48] = (uint8_t) (h[6] >> 56);
    hash[49] = (uint8_t) (h[6] >> 48);
    hash[50] = (uint8_t) (h[6] >> 40);
    hash[51] = (uint8_t) (h[6] >> 32);
    hash[52] = (uint8_t) (h[6] >> 24);
    hash[53] = (uint8_t) (h[6] >> 16);
    hash[54] = (uint8_t) (h[6] >> 8);
    hash[55] = (uint8_t) h[6];

    hash[56] = (uint8_t) (h[7] >> 56);
    hash[57] = (uint8_t) (h[7] >> 48);
    hash[58] = (uint8_t) (h[7] >> 40);
    hash[59] = (uint8_t) (h[7] >> 32);
    hash[60] = (uint8_t) (h[7] >> 24);
    hash[61] = (uint8_t) (h[7] >> 16);
    hash[62] = (uint8_t) (h[7] >> 8);
    hash[63] = (uint8_t) h[7];
}


void sha512_hash(const uint8_t *bits, const uint8_t *length, uint8_t *result) {
    
    //printf("start %d\n", *length);
    
    processChunks(bits, length, result);
    
}

