# Fixed-point and logic routines, hand-written RV32I (Quiz 3 Problem C).
#
# RV32I and Zicsr only: no mul, div, rem, no floating point, no compressed
# instructions. Tests: tests/tfixed.c.

    .text

# uint32_t op1_asm(uint32_t a, uint32_t b, int *n)
#   a in a0, b in a1, n in a2, result in a0
# Registers: t0 = pass count, t1 = a & b
    .globl  op1_asm
    .type   op1_asm, @function
    .align  2
op1_asm:
    li      t0, 0               # count = 0
    beqz    a1, .Lop1_done      # no carry: zero passes
.Lop1_loop:
    and     t1, a0, a1          # t1 = a & b
    xor     a0, a0, a1          # a = a ^ b, uses the old b
    slli    a1, t1, 1           # b = (a & b) << 1
    addi    t0, t0, 1           # count = count + 1
    bnez    a1, .Lop1_loop      # repeat while the carry word is not zero
.Lop1_done:
    sw      t0, 0(a2)           # *n = count
    ret
    .size   op1_asm, .-op1_asm

# uint32_t op2_asm(uint32_t a, uint32_t b)   a in a0, b in a1, result in a0
    .globl  op2_asm
    .type   op2_asm, @function
    .align  2
op2_asm:
    sub     a0, a0, a1          # a0 = a - b, wraps modulo 2^32
    ret
    .size   op2_asm, .-op2_asm

# uint32_t op3_asm(uint32_t a, uint32_t b)   a in a0, b in a1, result in a0
# Registers: t0 = a & b
    .globl  op3_asm
    .type   op3_asm, @function
    .align  2
op3_asm:
    and     t0, a0, a1          # t0 = a & b
    xor     a0, a0, a1          # a0 = a ^ b
    srli    a0, a0, 1           # a0 = (a ^ b) >> 1
    add     a0, a0, t0          # a0 = ((a ^ b) >> 1) + (a & b)
    ret
    .size   op3_asm, .-op3_asm

# int32_t q_mul_asm(int32_t a, int32_t b)   a in a0, b in a1, result in a0
# Registers: t1:a0 = multiplicand (high:low), a1 = multiplier,
#            t4:t3 = product (high:low), t5 = scratch
    .globl  q_mul_asm
    .type   q_mul_asm, @function
    .align  2
q_mul_asm:
    li      t1, 0               # multiplicand high = 0
    li      t3, 0               # product low = 0
    li      t4, 0               # product high = 0
    bgez    a0, .Lqmul_apos     # signed correction first, while a0 and a1
    sub     t4, t4, a1          #   still hold a and b: a < 0: high -= b
.Lqmul_apos:
    bgez    a1, .Lqmul_bpos
    sub     t4, t4, a0          # b < 0: high -= a
.Lqmul_bpos:
    beqz    a1, .Lqmul_round    # b == 0: skip the loop

.Lqmul_loop:                    # shift and add, two multiplier bits per pass
    andi    t5, a1, 1           # first bit
    beqz    t5, .Lqmul_shift
    add     t3, t3, a0          # product low += multiplicand low
    sltu    t5, t3, a0          # carry out of the low word
    add     t4, t4, t1          # product high += multiplicand high
    add     t4, t4, t5          # add the carry
.Lqmul_shift:
    srli    t5, a0, 31          # shift the 64-bit multiplicand left by 1
    slli    t1, t1, 1
    or      t1, t1, t5
    slli    a0, a0, 1
    srli    a1, a1, 1           # shift the multiplier right by 1, unsigned
    andi    t5, a1, 1           # second bit; a zero multiplier adds nothing
    beqz    t5, .Lqmul_shift2
    add     t3, t3, a0
    sltu    t5, t3, a0
    add     t4, t4, t1
    add     t4, t4, t5
.Lqmul_shift2:
    srli    t5, a0, 31
    slli    t1, t1, 1
    or      t1, t1, t5
    slli    a0, a0, 1
    srli    a1, a1, 1
    bnez    a1, .Lqmul_loop     # test once per two bits

.Lqmul_round:                   # add 2^19 to round
    lui     t5, 0x80            # t5 = 0x80000 = 2^19
    add     t3, t3, t5
    sltu    t5, t3, t5          # carry
    add     t4, t4, t5

    srli    t3, t3, 20          # low bits 31..20 -> bits 11..0
    slli    t4, t4, 12          # high bits 19..0 -> bits 31..12
    or      a0, t3, t4          # bits 51..20 of the product
    ret
    .size   q_mul_asm, .-q_mul_asm
