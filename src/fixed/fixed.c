#include "fixed.h"

uint32_t op1(uint32_t a, uint32_t b, int *n)
{
    int count = 0;
    while (b != 0) {
        uint32_t c = (a & b) << 1;
        a = a ^ b;
        b = c;
        count = count + 1;
    }
    *n = count;
    return a;
}

uint32_t op2(uint32_t a, uint32_t b)
{
    return a - b;
}

uint32_t op3(uint32_t a, uint32_t b)
{
    return ((a ^ b) >> 1) + (a & b);
}

/* TODO: dummy, replace with the Q11.20 product */
int32_t q_mul(int32_t a, int32_t b)
{
    (void) a;
    (void) b;
    return 0;
}
