# BFloat16 routines: hand-written RV32I.
#
# uint16_t bf16_from_f32_asm(uint32_t f32bits)   a0 -> a0
# uint16_t bf16_mul_asm(uint16_t a, uint16_t b)  a0, a1 -> a0
# uint16_t bf16_sqrt_asm(uint16_t a)             a0 -> a0
#
# RV32I and Zicsr only: no mul, div, rem, no floating point, no compressed
# instructions. Tests: tests/tbf16.c.

    .text

    .globl  bf16_from_f32_asm
    .type   bf16_from_f32_asm, @function
    .align  2
bf16_from_f32_asm:
# uint16_t bf16_from_f32_asm(uint32_t x)  x in a0, result in a0
# Registers: t0 = x << 1, then bit 16; t1 = 0xFF000000, then 0x7FFF
    slli    t0, a0, 1           # drop the sign: exponent now in bits 31..24
    lui     t1, 0xFF000         # t1 = 0xFF000000
    bgeu    t0, t1, .Lf32_special   # exponent == 0xFF: Inf or NaN
    srli    t0, a0, 16          # t0 = (x >> 16) & 1
    andi    t0, t0, 1
    add     a0, a0, t0          # x += bit 16
    lui     t1, 8               # t1 = 0x8000
    addi    t1, t1, -1          # t1 = 0x7FFF
    add     a0, a0, t1          # x += 0x7FFF
    srli    a0, a0, 16          # return x >> 16
    ret
.Lf32_special:
    srli    a0, a0, 16          # Inf or NaN: keep the top half
    ret
    .size   bf16_from_f32_asm, .-bf16_from_f32_asm

    .globl  bf16_mul_asm
    .type   bf16_mul_asm, @function
    .align  2
bf16_mul_asm:
# uint16_t bf16_mul_asm(uint16_t a, uint16_t b)  a in a0, b in a1, result in a0
# Registers: a2 = sign << 15, t1/t2 = exponents of a/b, t3/t4 = significands,
#            t6 = exponent adjustment, a3 = product, t0/t5/t6 = scratch
    xor     t0, a0, a1          # sign of the product
    srli    t0, t0, 15
    slli    a2, t0, 15          # a2 = sign << 15
    srli    t1, a0, 7           # t1 = exponent of a
    andi    t1, t1, 0xFF
    srli    t2, a1, 7           # t2 = exponent of b
    andi    t2, t2, 0xFF
    andi    t3, a0, 0x7F        # t3 = fraction of a
    andi    t4, a1, 0x7F        # t4 = fraction of b
    li      t5, 0xFF
    bne     t1, t5, .Lmul_chk_b # a first
    bnez    t3, .Lmul_ret_a     # a is NaN: return a
    or      t6, t2, t4
    beqz    t6, .Lmul_nan       # Inf times 0
    j       .Lmul_inf           # Inf, even if b is NaN
.Lmul_chk_b:                    # then b
    bne     t2, t5, .Lmul_chk_zero
    bnez    t4, .Lmul_ret_b     # b is NaN: return b
    or      t6, t1, t3
    beqz    t6, .Lmul_nan       # 0 times Inf
    j       .Lmul_inf
.Lmul_chk_zero:                 # either operand zero: signed zero
    or      t6, t1, t3
    beqz    t6, .Lmul_ret_zero
    or      t6, t2, t4
    beqz    t6, .Lmul_ret_zero
    li      t6, 0               # exponent adjustment = 0
    bnez    t1, .Lmul_a_norm
.Lmul_a_den:                    # normalize a denormal a
    slli    t3, t3, 1
    addi    t6, t6, -1
    andi    t5, t3, 0x80
    beqz    t5, .Lmul_a_den
    li      t1, 1
    j       .Lmul_b
.Lmul_a_norm:
    ori     t3, t3, 0x80        # add the hidden one
.Lmul_b:
    bnez    t2, .Lmul_b_norm
.Lmul_b_den:                    # normalize a denormal b
    slli    t4, t4, 1
    addi    t6, t6, -1
    andi    t5, t4, 0x80
    beqz    t5, .Lmul_b_den
    li      t2, 1
    j       .Lmul_mult
.Lmul_b_norm:
    ori     t4, t4, 0x80
.Lmul_mult:                     # shift and add, stops when b runs out
    li      a3, 0
.Lmul_loop:
    andi    t5, t4, 1
    beqz    t5, .Lmul_skip
    add     a3, a3, t3
.Lmul_skip:
    slli    t3, t3, 1
    srli    t4, t4, 1
    bnez    t4, .Lmul_loop
    add     t1, t1, t2          # exponent = ea + eb + adjustment - 127
    add     t1, t1, t6
    addi    t1, t1, -127
    srli    t5, a3, 15          # product >= 2.0?
    beqz    t5, .Lmul_noshift
    srli    a3, a3, 8
    addi    t1, t1, 1
    j       .Lmul_frac
.Lmul_noshift:
    srli    a3, a3, 7           # truncate
.Lmul_frac:
    andi    a3, a3, 0x7F
    li      t5, 0xFF
    bge     t1, t5, .Lmul_inf   # overflow
    blez    t1, .Lmul_under
    slli    t1, t1, 7
    or      a0, a2, t1
    or      a0, a0, a3
    ret
.Lmul_under:                    # exponent <= 0
    li      t5, -6
    blt     t1, t5, .Lmul_ret_zero
    li      t5, 1
    sub     t5, t5, t1
    srl     a3, a3, t5          # denormal: shift right by 1 - exponent
    or      a0, a2, a3
    ret
.Lmul_ret_b:
    mv      a0, a1
.Lmul_ret_a:
    ret
.Lmul_nan:
    lui     a0, 8               # 0x8000 - 64 = 0x7FC0
    addi    a0, a0, -64
    ret
.Lmul_inf:
    lui     t5, 8               # 0x8000 - 128 = 0x7F80
    addi    t5, t5, -128
    or      a0, a2, t5
    ret
.Lmul_ret_zero:
    mv      a0, a2
    ret
    .size   bf16_mul_asm, .-bf16_mul_asm

    .globl  bf16_sqrt_asm
    .type   bf16_sqrt_asm, @function
    .align  2
bf16_sqrt_asm:
# uint16_t bf16_sqrt_asm(uint16_t a)  a in a0, result in a0
# Registers: t0 = sign, t1 = exponent then new exponent, t2 = significand m,
#            a1/a2 = low/high, a3 = result, a4 = mid, a5 = mid * mid,
#            t4/t5 = multiply operands, t3/t6 = scratch
    srli    t0, a0, 15          # sign
    andi    t0, t0, 1
    srli    t1, a0, 7           # exponent
    andi    t1, t1, 0xFF
    andi    t2, a0, 0x7F        # fraction

    li      t3, 0xFF
    bne     t1, t3, .Lsqrt_not_inf_nan
    bnez    t2, .Lsqrt_ret_a    # NaN: return a
    bnez    t0, .Lsqrt_ret_nan  # -Inf
.Lsqrt_ret_a:
    ret                         # +Inf or NaN

.Lsqrt_not_inf_nan:
    or      t3, t1, t2
    beqz    t3, .Lsqrt_ret_zero # +0 or -0
    bnez    t0, .Lsqrt_ret_nan  # negative
    beqz    t1, .Lsqrt_ret_zero # denormal

    ori     t2, t2, 0x80        # add the hidden one
    andi    t3, t1, 1
    bnez    t3, .Lsqrt_exp_odd
    slli    t2, t2, 1           # odd unbiased exponent: double m
.Lsqrt_exp_odd:
    addi    t1, t1, 127         # new exponent = (exp + 127) >> 1
    srli    t1, t1, 1

    li      a1, 90              # low
    li      a2, 256             # high
    li      a3, 128             # result
.Lsqrt_bs_loop:
    blt     a2, a1, .Lsqrt_bs_done
    add     a4, a1, a2          # mid = (low + high) >> 1
    srli    a4, a4, 1

    mv      t4, a4              # a5 = mid * mid by shift and add
    mv      t5, a4
    li      a5, 0
.Lsqrt_mul_loop:
    andi    t6, t5, 1
    beqz    t6, .Lsqrt_mul_skip
    add     a5, a5, t4
.Lsqrt_mul_skip:
    slli    t4, t4, 1
    srli    t5, t5, 1
    bnez    t5, .Lsqrt_mul_loop

    srli    a5, a5, 7           # (mid * mid) / 128
    bgtu    a5, t2, .Lsqrt_bs_greater
    mv      a3, a4              # fits: result = mid, low = mid + 1
    addi    a1, a4, 1
    j       .Lsqrt_bs_loop
.Lsqrt_bs_greater:
    addi    a2, a4, -1          # too big: high = mid - 1
    j       .Lsqrt_bs_loop

.Lsqrt_bs_done:
    slli    a0, t1, 7
    andi    a3, a3, 0x7F
    or      a0, a0, a3
    ret

.Lsqrt_ret_nan:
    li      a0, 0x7FC0
    ret
.Lsqrt_ret_zero:
    li      a0, 0
    ret
    .size   bf16_sqrt_asm, .-bf16_sqrt_asm
