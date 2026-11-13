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

int32_t q_mul(int32_t a, int32_t b)
{
    uint32_t ua = (uint32_t) a, ub = (uint32_t) b;

    /* Multiplicand as a 64-bit value mh:ml, starting at a */
    uint32_t ml = ua, mh = 0;
    /* Product as a 64-bit value hi:lo */
    uint32_t lo = 0, hi = 0;
    /* Multiplier */
    uint32_t m = ub;

    /* Shift and add: multiply as unsigned values first */
    while (m != 0) {
        if (m & 1) { /* this multiplier bit is 1: product += multiplicand */
            lo += ml;
            hi += mh + (lo < ml); /* (lo < ml) is the carry out of lo */
        }
        mh = (mh << 1) | (ml >> 31); /* shift the multiplicand left by 1 */
        ml <<= 1;
        m >>= 1; /* shift the multiplier right by 1 */
    }

    /* Signed correction: only the high word changes */
    if (a < 0)
        hi -= ub;
    if (b < 0)
        hi -= ua;

    /* Add 2^19 to round, carrying into the high word */
    lo += 1u << (Q - 1);
    hi += (lo < (1u << (Q - 1)));

    /* Keep bits 51..20 of the 64-bit product */
    return (int32_t) ((lo >> Q) | (hi << (32 - Q)));
}
