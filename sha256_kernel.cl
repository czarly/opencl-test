typedef unsigned char uint8_t;
#define uint32_t unsigned int
#define bool char
#define true 1
#define false 0
#define DEBUG 0

inline uint32_t right_rot(uint32_t value, unsigned int count)
{
    /*
     * Defined behaviour in standard C for all count where 0 < count < 32,
     * which is what we need here.
     */

    return value >> count | value << (32 - count);
}

// make sure to go through the code before making lenght anything else but 64!
__kernel void hash(__global const uint8_t *bits, __global const uint8_t *length, __global const uint8_t *target, __local uint8_t *final, __global int *results) {
    
    int x = get_global_id(0);
    int y = get_local_id(0);
    int z = get_group_id(0);
    
    // printf("start %d (%d) - %d\n", x, y, z);
    
    uint32_t k[64] = {
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
    };
    
    uint32_t hi[] = { 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19 };
    
    // printf("%d\n", hi[0]);
    
    for(int n=0; (n * 64) < *length; n++){
        
        uint32_t a, b, c, d, e, f, g, h;
        
        /*
         * create a 64-entry message schedule array w[0..63] of 32-bit words
         * (The initial values in w[0..63] don't matter, so many implementations zero them here)
         * copy chunk into first 16 words w[0..15] of the message schedule array
         */
        uint32_t w[64];
        __global const uint8_t *p = bits + (n * 64) + (x * 64); // chunk is bits + (i * 64) {the chunk} + (x * 64) the offset for the workgroup
        int i;
        
        //memset(w, 0x00, sizeof w);
        for (i = 0; i < 16; i++) {
            w[i] = (uint32_t) p[0] << 24 | (uint32_t) p[1] << 16 |
            (uint32_t) p[2] << 8 | (uint32_t) p[3];
            p += 4;
        }
        
        /* Extend the first 16 words into the remaining 48 words w[16..63] of the message schedule array: */
        for (i = 16; i < 64; i++) {
            const uint32_t s0 = right_rot(w[i - 15], 7) ^ right_rot(w[i - 15], 18) ^ (w[i - 15] >> 3);
            const uint32_t s1 = right_rot(w[i - 2], 17) ^ right_rot(w[i - 2], 19) ^ (w[i - 2] >> 10);
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
        for (i = 0; i < 64; i++) {
            const uint32_t s1 = right_rot(e, 6) ^ right_rot(e, 11) ^ right_rot(e, 25);
            const uint32_t ch = (e & f) ^ (~e & g);
            const uint32_t temp1 = h + s1 + ch + k[i] + w[i];
            const uint32_t s0 = right_rot(a, 2) ^ right_rot(a, 13) ^ right_rot(a, 22);
            const uint32_t maj = (a & b) ^ (a & c) ^ (b & c);
            const uint32_t temp2 = s0 + maj;
            
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
    

    /* Produce the final hash value (big-endian): */
    // uint8_t *final = (uint8_t*)malloc(sizeof(uint8_t)*32);
    // apparently i can't create arrays inside the kernel
    // but i can hand him a local parameter while creating the context

    final[0] = (uint8_t) (hi[0] >> 24);
    final[1] = (uint8_t) (hi[0] >> 16);
    final[2] = (uint8_t) (hi[0] >> 8);
    final[3] = (uint8_t) hi[0];
    final[4] = (uint8_t) (hi[1] >> 24);
    final[5] = (uint8_t) (hi[1] >> 16);
    final[6] = (uint8_t) (hi[1] >> 8);
    final[7] = (uint8_t) hi[1];
    final[8] = (uint8_t) (hi[2] >> 24);
    final[9] = (uint8_t) (hi[2] >> 16);
    final[10] = (uint8_t) (hi[2] >> 8);
    final[11] = (uint8_t) hi[2];
    final[12] = (uint8_t) (hi[3] >> 24);
    final[13] = (uint8_t) (hi[3] >> 16);
    final[14] = (uint8_t) (hi[3] >> 8);
    final[15] = (uint8_t) hi[3];
    final[16] = (uint8_t) (hi[4] >> 24);
    final[17] = (uint8_t) (hi[4] >> 16);
    final[18] = (uint8_t) (hi[4] >> 8);
    final[19] = (uint8_t) hi[4];
    final[20] = (uint8_t) (hi[5] >> 24);
    final[21] = (uint8_t) (hi[5] >> 16);
    final[22] = (uint8_t) (hi[5] >> 8);
    final[23] = (uint8_t) hi[5];
    final[24] = (uint8_t) (hi[6] >> 24);
    final[25] = (uint8_t) (hi[6] >> 16);
    final[26] = (uint8_t) (hi[6] >> 8);
    final[27] = (uint8_t) hi[6];
    final[28] = (uint8_t) (hi[7] >> 24);
    final[29] = (uint8_t) (hi[7] >> 16);
    final[30] = (uint8_t) (hi[7] >> 8);
    final[31] = (uint8_t) hi[7];


    // test if the result is conform to what i want

    bool valid = true;
    for (int i=0; i<*target; i++){
        valid = valid && final[i] == 0;
    }

    // also check that not everything in the result is 0
    if (valid && final[31] != 0){
        results[x] = 1;
        // we could break here but i don't know how to be honest
    }
    
    if(valid && final[31] != 0){
        // so we go on with debug output
        printf("\nresulting hash: %d\n", x);
        
        for(int i=0; i<32; i++){
            //printf("\n%d) value:\t%" PRIu8 " ", i, final[i]);
            printf("%x", final[i]);
            
            /*int size = sizeof(final[i]);
            uint8_t byte;
            int i, j;
            
            for (i=size-1;i>=0;i--)
            {
                for (j=7;j>=0;j--)
                {
                    byte = (final[i] >> j) & 1;
                    //printf("%u", byte);
                }
            }*/
        }
        
        //__global const uint8_t *u = bits + (x * 64);
        printf("\n and here the original:\n", x, y, z);
        for(int k=0; k<64; k++){
            printf("%x", bits[k+(x*64)]);
        }
        
        printf("\n");
    } else {
        results[x] = 0;
    }
}



