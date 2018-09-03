#include <inttypes.h>

void printBits(size_t const size, void const * const ptr);
void printStream(uint8_t *bits, int size);
uint8_t *prepareMessage(uint8_t *initial_msg, size_t initial_len, int *size); // alias for 512
uint8_t *prepareMessage512(uint8_t *initial_msg, size_t initial_len, int *size);
uint8_t *prepareMessage1024(uint8_t *initial_msg, size_t initial_len, int *size);