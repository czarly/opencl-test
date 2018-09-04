#define uint32_t unsigned int
#define uint64_t unsigned long
#define size_t unsigned int
#define uint8_t unsigned char
#define bool char
#define true 1
#define false 0

void sha384_calc(__global const uint8_t *ptr, const size_t final_len, uint64_t *ctx);
void sha384_128(__global const uint8_t* msg, uint64_t* ctx);
void sha384_128_local(const uint8_t* msg, uint64_t* ctx);
uint64_t rot_right(uint64_t x, uint8_t c);
uint64_t rot_left(uint64_t x, uint8_t c);

inline uint32_t htonl(uint32_t x){
    uint32_t b0,b1,b2,b3;
    uint32_t res = 0;
    b0 = (x & 0xff) << 24;        // least significant to most significant
    b1 = (x & 0xff00) << 8;       // 2nd least sig. to 2nd most sig.
    b2 = (x & 0xff0000) >> 8;     // 2nd most sig. to 2nd least sig.
    b3 = (x & 0xff000000) >> 24;  // most sig. to least sig.
    res = b0 | b1 | b2 | b3 ;
        
    return res;
}

inline uint64_t htonll(uint64_t x){
    const uint32_t hi = x>>32;
    const uint32_t lo = x;
    return htonl(hi) + ((uint64_t)htonl(lo) << 32);
}

/*
 * Initialize array of round constants: (first 64 bits of the fractional parts of the cube roots of the first 80 primes 2..409):
 */
__constant uint64_t k[80] = {
    0x428a2f98d728ae22ULL, 0x7137449123ef65cdULL, 0xb5c0fbcfec4d3b2fULL, 0xe9b5dba58189dbbcULL,
    0x3956c25bf348b538ULL, 0x59f111f1b605d019ULL, 0x923f82a4af194f9bULL, 0xab1c5ed5da6d8118ULL,
    0xd807aa98a3030242ULL, 0x12835b0145706fbeULL, 0x243185be4ee4b28cULL, 0x550c7dc3d5ffb4e2ULL,
    0x72be5d74f27b896fULL, 0x80deb1fe3b1696b1ULL, 0x9bdc06a725c71235ULL, 0xc19bf174cf692694ULL,
    0xe49b69c19ef14ad2ULL, 0xefbe4786384f25e3ULL, 0x0fc19dc68b8cd5b5ULL, 0x240ca1cc77ac9c65ULL,
    0x2de92c6f592b0275ULL, 0x4a7484aa6ea6e483ULL, 0x5cb0a9dcbd41fbd4ULL, 0x76f988da831153b5ULL,
    0x983e5152ee66dfabULL, 0xa831c66d2db43210ULL, 0xb00327c898fb213fULL, 0xbf597fc7beef0ee4ULL,
    0xc6e00bf33da88fc2ULL, 0xd5a79147930aa725ULL, 0x06ca6351e003826fULL, 0x142929670a0e6e70ULL,
    0x27b70a8546d22ffcULL, 0x2e1b21385c26c926ULL, 0x4d2c6dfc5ac42aedULL, 0x53380d139d95b3dfULL,
    0x650a73548baf63deULL, 0x766a0abb3c77b2a8ULL, 0x81c2c92e47edaee6ULL, 0x92722c851482353bULL,
    0xa2bfe8a14cf10364ULL, 0xa81a664bbc423001ULL, 0xc24b8b70d0f89791ULL, 0xc76c51a30654be30ULL,
    0xd192e819d6ef5218ULL, 0xd69906245565a910ULL, 0xf40e35855771202aULL, 0x106aa07032bbd1b8ULL,
    0x19a4c116b8d2d0c8ULL, 0x1e376c085141ab53ULL, 0x2748774cdf8eeb99ULL, 0x34b0bcb5e19b48a8ULL,
    0x391c0cb3c5c95a63ULL, 0x4ed8aa4ae3418acbULL, 0x5b9cca4f7763e373ULL, 0x682e6ff3d6b2b8a3ULL,
    0x748f82ee5defb2fcULL, 0x78a5636f43172f60ULL, 0x84c87814a1f0ab72ULL, 0x8cc702081a6439ecULL,
    0x90befffa23631e28ULL, 0xa4506cebde82bde9ULL, 0xbef9a3f7b2c67915ULL, 0xc67178f2e372532bULL,
    0xca273eceea26619cULL, 0xd186b8c721c0c207ULL, 0xeada7dd6cde0eb1eULL, 0xf57d4f7fee6ed178ULL,
    0x06f067aa72176fbaULL, 0x0a637dc5a2c898a6ULL, 0x113f9804bef90daeULL, 0x1b710b35131c471bULL,
    0x28db77f523047d84ULL, 0x32caab7b40c72493ULL, 0x3c9ebe0a15c9bebcULL, 0x431d67c49c100d4cULL,
    0x4cc5d4becb3e42b6ULL, 0x597f299cfc657e2aULL, 0x5fcb6fab3ad6faecULL, 0x6c44198c4a475817ULL
};

#define  LEFTROTATE(x, c) (((x) << (c)) | ((x) >> (64 - (c))))
#define RIGHTROTATE(x, c) (((x) >> (c)) | ((x) << (64 - (c))))

uint64_t rot_right(uint64_t x, uint8_t c){
    return (uint64_t) (((x) >> (c)) | ((x) << (64 - (c))));
}

uint64_t rot_left(uint64_t x, uint8_t c){
    return (uint64_t) (((x) << (c)) | ((x) >> (64 - (c))));
}

/*
 * Process the message in successive 1024-bit chunks:
 * break message into 1024-bit chunks
 * (The initial values in w[0..79] don't matter, so many implementations zero them here)
 */

void sha384_128(__global const uint8_t* msg, uint64_t* ctx)
{
    int i;
    /* for each chunk create a 80-entry message schedule array w[0..79] of 64-bit words */
    uint64_t w[80];
    
    /* copy chunk into first 16 words w[0..15] of the message schedule array */
    
    for (i = 0; i < 16; ++i){
        uint8_t buf[8] = {
            msg[8*i],
            msg[8*i+1],
            msg[8*i+2],
            msg[8*i+3],
            msg[8*i+4],
            msg[8*i+5],
            msg[8*i+6],
            msg[8*i+7]
        };
        
        w[i] = htonll(*(uint64_t*)buf);
    }
    
    /* Extend the first 16 words into the remaining 48 words w[16..63] of the message schedule array: */
    for (i = 16; i < 80;  ++i) {
        uint64_t s0 = RIGHTROTATE(w[i-15], 1) ^ RIGHTROTATE(w[i-15], 8) ^ (w[i-15] >> 7);
        uint64_t s1 = RIGHTROTATE(w[i-2], 19) ^ RIGHTROTATE(w[i-2] ,61) ^ (w[i-2]  >> 6);
        w[i] = w[i-16] + s0 + w[i-7] + s1;
    }
    
    /* Initialize working variables to current hash value:*/
    uint64_t a = ctx[0], b = ctx[1], c = ctx[2], d = ctx[3];
    uint64_t e = ctx[4], f = ctx[5], g = ctx[6], h = ctx[7];
    
    /* Compression function main loop: */
    for (i = 0; i < 80; ++i) {
        uint64_t S1 = RIGHTROTATE(e, 14) ^ RIGHTROTATE(e, 18) ^ RIGHTROTATE(e, 41);
        //uint64_t ch = (e & f) ^ ((~e) & g);
        uint64_t ch = g ^ (e & (f ^ g));
        uint64_t temp1 = h + S1 + ch + k[i] + w[i];
        uint64_t S0 = RIGHTROTATE(a, 28) ^ RIGHTROTATE(a, 34) ^ RIGHTROTATE(a, 39);
        //uint64_t maj = (a & b) ^ (a & c) ^ (b & c);
        uint64_t maj = (a & b) | (c & (a | b));
        uint64_t temp2 = S0 + maj;
        
        h = g; g = f; f = e;
        e = d + temp1;
        d = c; c = b; b = a;
        a = temp1 + temp2;
    }
    /* Add the compressed chunk to the current hash value: */
    ctx[0] += a; ctx[1] += b; ctx[2] += c; ctx[3] += d;
    ctx[4] += e; ctx[5] += f; ctx[6] += g; ctx[7] += h;
}


void sha384_128_local(const uint8_t* msg, uint64_t* ctx)
{
    /* for each chunk create a 80-entry message schedule array w[0..79] of 64-bit words */
    uint64_t w[80] = { 0ULL << 63 };
    
    /* copy chunk into first 16 words w[0..15] of the message schedule array */
    for (int i = 0; i < 16; ++i){
        uint8_t buf[8] = {
            msg[8*i],
            msg[8*i+1],
            msg[8*i+2],
            msg[8*i+3],
            msg[8*i+4],
            msg[8*i+5],
            msg[8*i+6],
            msg[8*i+7]
        };
        
        w[i] = htonll(*(uint64_t*)buf);
    }

    /* Extend the first 16 words into the remaining 48 words w[16..63] of the message schedule array: */
    for (int j = 16; j < 80;  ++j) {
        uint64_t s0 = rot_right(w[j-15], 1) ^ rot_right(w[j-15], 8) ^ (w[j-15] >> 7);
        uint64_t s1 = rot_right(w[j-2], 19) ^ rot_right(w[j-2] ,61) ^ (w[j-2]  >> 6);

        w[j] = w[j-16] + s0 + w[j-7] + s1;
    }
    
    /* Initialize working variables to current hash value:*/
    uint64_t a = ctx[0], b = ctx[1], c = ctx[2], d = ctx[3];
    uint64_t e = ctx[4], f = ctx[5], g = ctx[6], h = ctx[7];
    
    /* Compression function main loop: */
    for (int x = 0; x < 80; ++x) {
        uint64_t S1 = rot_right(e, 14) ^ rot_right(e, 18) ^ rot_right(e, 41);
        //uint64_t ch = (e & f) ^ ((~e) & g);
        uint64_t ch = g ^ (e & (f ^ g));
        uint64_t temp1 = h + S1 + ch + k[x] + w[x];
        uint64_t S0 = rot_right(a, 28) ^ rot_right(a, 34) ^ rot_right(a, 39);
        //uint64_t maj = (a & b) ^ (a & c) ^ (b & c);
        uint64_t maj = (a & b) | (c & (a | b));
        uint64_t temp2 = S0 + maj;
        
        h = g; g = f; f = e;
        e = d + temp1;
        d = c; c = b; b = a;
        a = temp1 + temp2;
    }
    /* Add the compressed chunk to the current hash value: */
    ctx[0] += a; ctx[1] += b; ctx[2] += c; ctx[3] += d;
    ctx[4] += e; ctx[5] += f; ctx[6] += g; ctx[7] += h;
}

/*
 * Pre-processing:
 * append the bit '1' to the message
 * append k bits '0', where k is the minimum number >= 0 such that the resulting message length (modulo 1024 in bits) is 896.
 * append length of message (without the '1' bit or padding), in bits, as 128-bit big-endian integer
 * (this will make the entire post-processed length a multiple of 1024 bits)
 */

void sha384_calc(__global const uint8_t *ptr, const size_t final_len, uint64_t *ctx)
{
    unsigned int offset=0;
    
    // only important when the message doesn't fit in one chunk anymore.
    for (offset = 0; offset+128 <= final_len; offset += 128){
        sha384_128(ptr + offset, ctx);
    }

    const int remain = final_len - offset;
    
    uint8_t sha384_buf[128] = { 0 };
    
    if (remain) {
        // i have a piece that was not 128 bits and still has to be processed
        // copy the remaining bits in the first places of a empty 128 bit buffer
    
        for(int k=0;k<remain;k++){
            sha384_buf[k] = (uint8_t) *(ptr+(offset+k*sizeof(uint8_t)));
        }
    }
    
    // and go on here. we add our binary 1 as terminator and then we copy the length in the last place of the chunk
    sha384_buf[remain] = 0x80;
    
    // this is irrelevant for short payloads as well
    if (remain >= 112) {

        // if the remainder is too long to append the length after it in the same chunk we update the context 1 more round
        sha384_128_local(sha384_buf, ctx);
        
        // and 0 out the temporary buffer again up to the point where we wanna add the length information
        //gsus that looks stupid;
        for(int z=0;z<116;z++){
            sha384_buf[z] = 0;
        }
    }

    
    // finally we add the lenght information
    // i had to know that upfront. in a way i don't need the chunk lenght really, or do i?
    *(uint32_t*)(sha384_buf+116) = htonl(final_len >> 61);
    *(uint32_t*)(sha384_buf+120) = htonl(final_len >> 29);
    *(uint32_t*)(sha384_buf+124) = htonl(final_len <<  3);
    
    // and we'll update the context again, because this is what we want to output as the hash in the end.
    sha384_128_local(sha384_buf, ctx);
}

__kernel void sha384_hash(__global const uint8_t *bits, __global const size_t *length, __global const uint8_t *target, __global int *results){
    
    
    int x = get_global_id(0);
    
    //printf("size of uint64_t=%d", sizeof(uint64_t));
    //printf("size of uint8_t=%d", sizeof(uint8_t));
    
    // sha384
    
    uint64_t h[] = {
        0xcbbb9d5dc1059ed8ULL,
        0x629a292a367cd507ULL,
        0x9159015a3070dd17ULL,
        0x152fecd8f70e5939ULL,
        0x67332667ffc00b31ULL,
        0x8eb44a8768581511ULL,
        0xdb0c2e0d64f98fa7ULL,
        0x47b5481dbefa4fa4ULL
    };
    
    size_t item_length = *length;
    
    sha384_calc(bits + (x * item_length * sizeof(uint8_t)), item_length, h);
    
    uint8_t hash[64] = { 0 };
    
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
    
    
    // test if the result is conform to what i want
    
    bool valid = true;
    for (int i=0; i<*target; i++){
        valid = valid && hash[i] == 0;
    }
    
    // also check that not everything in the result is 0
    if (valid){
        results[x] = 1;
        // we could break here but i don't know how to be honest
    } else {
        results[x] = 0;
    }
    
    
    return;
    
    /*if(valid){
        // so we go on with debug output
        printf("\nresulting hash: %d - %.12s\n", x, bits+(12*x));
        
        for(int i=0; i<56; i++){
            //printf("\n%d) value:\t%" PRIu8 " ", i, final[i]);
            printf("%x", hash[i]);
            
            int size = sizeof(hash[i]);
             uint8_t byte;
             int i, j;
             
             for (i=size-1;i>=0;i--)
             {
                 for (j=7;j>=0;j--)
                 {
                     byte = (hash[i] >> j) & 1;
                     //printf("%u", byte);
                 }
             }
        }
        
        printf("\n");
    }*/
    
}

