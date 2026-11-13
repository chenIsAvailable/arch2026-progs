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
    .globl  q_mul_asm
    .type   q_mul_asm, @function
    .align  2
q_mul_asm:
    li      a0, 0               # TODO: dummy, replace with the Q11.20 product
    ret
    .size   q_mul_asm, .-q_mul_asm
