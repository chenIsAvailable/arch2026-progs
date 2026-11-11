#include "gcd.h"

uint32_t gcd_u32(uint32_t a, uint32_t b)
{
    if (!a)
        return b;
    if (!b)
        return a;

    int k = 0;
    while (!((a & 1) || (b & 1))) {
        k++;
        a >>= 1;
        b >>= 1;
    }
    while (!(a & 1))
        a >>= 1;

    do {
        while (!(b & 1))
            b >>= 1;
        if (a > b) {
            uint32_t tmp = a;
            a = b;
            b = tmp;
        }
        b -= a;
    } while (b);

    return a << k;
}
