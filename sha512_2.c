#include "sha512_2.h"

#define uint32_t unsigned int
#define uint64_t unsigned long long
#define size_t unsigned int
#define uint8_t unsigned char

/*uint64_t htonll(uint64_t x){
    x = (x & 0x00000000FFFFFFFF) << 32 | (x & 0xFFFFFFFF00000000) >> 32;
    x = (x & 0x0000FFFF0000FFFF) << 16 | (x & 0xFFFF0000FFFF0000) >> 16;
    x = (x & 0x00FF00FF00FF00FF) << 8  | (x & 0xFF00FF00FF00FF00) >> 8;
    return x;
}*/

uint32_t htonl(uint32_t x){
    uint32_t b0,b1,b2,b3;
    uint32_t res = 0;
    b0 = (x & 0xff) << 24;        // least significant to most significant
    b1 = (x & 0xff00) << 8;       // 2nd least sig. to 2nd most sig.
    b2 = (x & 0xff0000) >> 8;     // 2nd most sig. to 2nd least sig.
    b3 = (x & 0xff000000) >> 24;  // most sig. to least sig.
    res = b0 | b1 | b2 | b3 ;
    
    return res;
}

uint64_t htonll(uint64_t x){
    const uint32_t hi = x>>32;
    const uint32_t lo = x;
    return htonl(hi) + ((uint64_t)htonl(lo) << 32);
}

/*
 * Initialize array of round constants: (first 64 bits of the fractional parts of the cube roots of the first 80 primes 2..409):
 */

static const
uint64_t k[] ={
    0x428a2f98d728ae22, 0x7137449123ef65cd, 0xb5c0fbcfec4d3b2f, 0xe9b5dba58189dbbc,
    0x3956c25bf348b538, 0x59f111f1b605d019, 0x923f82a4af194f9b, 0xab1c5ed5da6d8118,
    0xd807aa98a3030242, 0x12835b0145706fbe, 0x243185be4ee4b28c, 0x550c7dc3d5ffb4e2,
    0x72be5d74f27b896f, 0x80deb1fe3b1696b1, 0x9bdc06a725c71235, 0xc19bf174cf692694,
    0xe49b69c19ef14ad2, 0xefbe4786384f25e3, 0x0fc19dc68b8cd5b5, 0x240ca1cc77ac9c65,
    0x2de92c6f592b0275, 0x4a7484aa6ea6e483, 0x5cb0a9dcbd41fbd4, 0x76f988da831153b5,
    0x983e5152ee66dfab, 0xa831c66d2db43210, 0xb00327c898fb213f, 0xbf597fc7beef0ee4,
    0xc6e00bf33da88fc2, 0xd5a79147930aa725, 0x06ca6351e003826f, 0x142929670a0e6e70,
    0x27b70a8546d22ffc, 0x2e1b21385c26c926, 0x4d2c6dfc5ac42aed, 0x53380d139d95b3df,
    0x650a73548baf63de, 0x766a0abb3c77b2a8, 0x81c2c92e47edaee6, 0x92722c851482353b,
    0xa2bfe8a14cf10364, 0xa81a664bbc423001, 0xc24b8b70d0f89791, 0xc76c51a30654be30,
    0xd192e819d6ef5218, 0xd69906245565a910, 0xf40e35855771202a, 0x106aa07032bbd1b8,
    0x19a4c116b8d2d0c8, 0x1e376c085141ab53, 0x2748774cdf8eeb99, 0x34b0bcb5e19b48a8,
    0x391c0cb3c5c95a63, 0x4ed8aa4ae3418acb, 0x5b9cca4f7763e373, 0x682e6ff3d6b2b8a3,
    0x748f82ee5defb2fc, 0x78a5636f43172f60, 0x84c87814a1f0ab72, 0x8cc702081a6439ec,
    0x90befffa23631e28, 0xa4506cebde82bde9, 0xbef9a3f7b2c67915, 0xc67178f2e372532b,
    0xca273eceea26619c, 0xd186b8c721c0c207, 0xeada7dd6cde0eb1e, 0xf57d4f7fee6ed178,
    0x06f067aa72176fba, 0x0a637dc5a2c898a6, 0x113f9804bef90dae, 0x1b710b35131c471b,
    0x28db77f523047d84, 0x32caab7b40c72493, 0x3c9ebe0a15c9bebc, 0x431d67c49c100d4c,
    0x4cc5d4becb3e42b6, 0x597f299cfc657e2a, 0x5fcb6fab3ad6faec, 0x6c44198c4a475817
};

#define  LEFTROTATE(x, c) (((x) << (c)) | ((x) >> (64 - (c))))
#define RIGHTROTATE(x, c) (((x) >> (c)) | ((x) << (64 - (c))))
/*
 * Process the message in successive 1024-bit chunks:
 * break message into 1024-bit chunks
 * (The initial values in w[0..79] don't matter, so many implementations zero them here)
 */
void sha512_128(const uint8_t* msg, uint64_t* ctx)
{
    int i;
    /* for each chunk create a 80-entry message schedule array w[0..79] of 64-bit words */
    uint64_t w[80];
    
    /* copy chunk into first 16 words w[0..15] of the message schedule array */
    for (i = 0; i < 16; ++i)
        w[i] = htonll(*(uint64_t*)(msg+8*i));

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


/*
 * Pre-processing:
 * append the bit '1' to the message
 * append k bits '0', where k is the minimum number >= 0 such that the resulting message length (modulo 1024 in bits) is 896.
 * append length of message (without the '1' bit or padding), in bits, as 128-bit big-endian integer
 * (this will make the entire post-processed length a multiple of 1024 bits)
 */
void sha512_calc(const uint8_t *ptr, const size_t final_len, uint64_t *ctx)
{
    unsigned int offset;
    for (offset = 0; offset+128 <= final_len; offset += 128)
        sha512_128(ptr + offset, ctx);
    
    const int remain = final_len - offset;
    uint8_t sha512_buf[128];

    if (remain)
        // i have a piece that was not 128 bits and still has to be processed
        // copy the remaining bits in the first places of a empty 128 bit buffer
        memcpy(sha512_buf, ptr+offset, remain);
    
    // set the rest of the buffer to 0
    // it's not really needed it think, but lets leave it in for now
    memset(sha512_buf+remain, 0, 128-remain);
    
    // and go on here. we add our binary 1 as terminator and then we copy the length in the last place of the chunk
    sha512_buf[remain] = 0x80;
    if (remain >= 112) {
        // if the remainder is too long to append the length after it in the same chunk we update the context 1 more round
        sha512_128(sha512_buf, ctx);
        // and 0 out the temporary buffer again up to the point where we wanna add the length information
        memset(sha512_buf, 0, 116);
    }
    
    // finally we add the lenght information
    // i had to know that upfront. in a way i don't need the chunk lenght really, or do i?
    *(uint32_t*)(sha512_buf+116) = htonl(final_len >> 61);
    *(uint32_t*)(sha512_buf+120) = htonl(final_len >> 29);
    *(uint32_t*)(sha512_buf+124) = htonl(final_len <<  3);
    
    /*for(int i=0; i<128; i++){
        //printf("\n%d) value:\t%" PRIu8 " ", i, final[i]);
        printf("%x", sha512_buf[i]);
        
        int size = sizeof(sha512_buf[i]);
        uint8_t byte;
        int i, j;
        
        for (i=size-1;i>=0;i--)
        {
            for (j=7;j>=0;j--)
            {
                byte = (sha512_buf[i] >> j) & 1;
                //printf("%u", byte);
            }
        }
    }*/
    
    // and we'll update the context again, because this is what we want to output as the hash in the end.
    sha512_128(sha512_buf, ctx);
}

void sha512_hash_2(const uint8_t *bits, const size_t length, uint8_t *hash) {
    
    //printf("start %d\n", *length);
    
    /*uint64_t h[] = {
        0x6a09e667f3bcc908,
        0xbb67ae8584caa73b,
        0x3c6ef372fe94f82b,
        0xa54ff53a5f1d36f1,
        0x510e527fade682d1,
        0x9b05688c2b3e6c1f,
        0x1f83d9abfb41bd6b,
        0x5be0cd19137e2179
    };*/
    
    uint64_t h[] = {
        0xcbbb9d5dc1059ed8,
        0x629a292a367cd507,
        0x9159015a3070dd17,
        0x152fecd8f70e5939,
        0x67332667ffc00b31,
        0x8eb44a8768581511,
        0xdb0c2e0d64f98fa7,
        0x47b5481dbefa4fa4
    };
    
    sha512_calc(bits, length, h);
    
    // you have your hash in *result...
    
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
    
    /*hash[56] = (uint8_t) (h[7] >> 56);
    hash[57] = (uint8_t) (h[7] >> 48);
    hash[58] = (uint8_t) (h[7] >> 40);
    hash[59] = (uint8_t) (h[7] >> 32);
    hash[60] = (uint8_t) (h[7] >> 24);
    hash[61] = (uint8_t) (h[7] >> 16);
    hash[62] = (uint8_t) (h[7] >> 8);
    hash[63] = (uint8_t) h[7];*/
    
}

