#include "bf16.h"

/* Dummies: every function returns 0. Replace with the real routines. */
uint16_t bf16_from_f32(uint32_t x)
{
    uint32_t exp = (x >> 23) & 0xFF;
    if (exp == 0xFF) /* Inf or NaN: keep the top half */
        return (uint16_t) (x >> 16);
    x += 0x7FFF + ((x >> 16) & 1); /* round to nearest, ties to even */
    return (uint16_t) (x >> 16);
}

uint16_t bf16_mul(uint16_t a, uint16_t b)
{
    uint32_t sa = (a >> 15) & 1, ea = (a >> 7) & 0xFF, ma = a & 0x7F;
    uint32_t sb = (b >> 15) & 1, eb = (b >> 7) & 0xFF, mb = b & 0x7F;
    uint32_t s = sa ^ sb;

    /* Special values: a first */
    if (ea == 0xFF) {
        if (ma)
            return a; /* a is NaN */
        if (!eb && !mb)
            return 0x7FC0;                      /* Inf times 0 */
        return (uint16_t) ((s << 15) | 0x7F80); /* Inf, even if b is NaN */
    }
    /* Then b */
    if (eb == 0xFF) {
        if (mb)
            return b;
        if (!ea && !ma)
            return 0x7FC0;
        return (uint16_t) ((s << 15) | 0x7F80);
    }
    /* Zero */
    if ((!ea && !ma) || (!eb && !mb))
        return (uint16_t) (s << 15);

    /* Normalize a denormal, or add the hidden one to a normal */
    int32_t adj = 0;
    if (!ea) {
        while (!(ma & 0x80)) {
            ma <<= 1;
            adj--;
        }
        ea = 1;
    } else {
        ma |= 0x80;
    }
    if (!eb) {
        while (!(mb & 0x80)) {
            mb <<= 1;
            adj--;
        }
        eb = 1;
    } else {
        mb |= 0x80;
    }

    uint32_t p = ma * mb; /* 8-bit by 8-bit significand product */
    int32_t e = (int32_t) ea + (int32_t) eb - 127 + adj;
    uint32_t f;
    if (p & 0x8000) { /* product >= 2.0: shift one more bit */
        f = (p >> 8) & 0x7F;
        e++;
    } else {
        f = (p >> 7) & 0x7F; /* truncate */
    }

    if (e >= 0xFF)
        return (uint16_t) ((s << 15) | 0x7F80); /* overflow */
    if (e <= 0) {
        if (e < -6)
            return (uint16_t) (s << 15); /* too small: zero */
        f >>= (1 - e);                   /* denormal */
        e = 0;
    }
    return (uint16_t) ((s << 15) | ((uint32_t) e << 7) | f);
}

uint16_t bf16_sqrt(uint16_t a)
{
    uint32_t s = (a >> 15) & 1;
    uint32_t exp = (a >> 7) & 0xFF;
    uint32_t man = a & 0x7F;
    if (exp == 0xFF) {
        if (man != 0)
            return a; /* NaN */
        if (s == 1)
            return 0x7FC0; /* -Inf */
        return a;          /* +Inf */
    }
    if (exp == 0 && man == 0)
        return 0; /* +0 or -0 */
    if (s == 1)
        return 0x7FC0; /* negative */
    if (exp == 0)
        return 0; /* denormal */

    uint32_t m = 0x80 | man;
    if ((exp & 1) == 0) /* odd unbiased exponent: double the significand */
        m <<= 1;
    uint32_t new_exp = (exp + 127) >> 1;

    /* Largest mid in [90, 256] with (mid * mid) / 128 <= m */
    int32_t low = 90, high = 256;
    uint32_t result = 128;
    while (low <= high) {
        uint32_t mid = (uint32_t) (low + high) >> 1;
        if (((mid * mid) >> 7) <= m) {
            result = mid;
            low = mid + 1;
        } else {
            high = mid - 1;
        }
    }

    return (uint16_t) ((new_exp << 7) | (result & 0x7F));
}
