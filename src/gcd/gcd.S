# gcd_u32_asm: binary GCD, hand-written RV32I.
#
# uint32_t gcd_u32_asm(uint32_t a, uint32_t b)   a in a0, b in a1, result in a0
#
# Registers: a0 = a, a1 = b, t2 = k (shared factors of two), t3 = scratch

    .text
    .globl  gcd_u32_asm
    .type   gcd_u32_asm, @function
    .align  2
gcd_u32_asm:
    beq a1, zero, .Ldone        # b == 0: return a (already in a0)
    beq a0, x0, .Lretb          # a == 0: return b
    add t2, x0, x0              # k = 0

    or t3, a0, a1               # skip if a or b is already odd
    andi t3, t3, 1
    bne t3, x0, .Lbreak
.Lloop1:                        # strip the shared factors of two
    addi t2, t2, 1
    srli a0, a0, 1
    srli a1, a1, 1
    or t3, a0, a1
    andi t3, t3, 1
    beq t3, x0, .Lloop1
.Lbreak:
    andi t3, a0, 1              # skip if a is already odd
    bne t3, x0, .Lbreak2
.Lloop2:                        # make a odd
    srli a0, a0, 1
    andi t3, a0, 1
    beq t3, x0, .Lloop2
.Lbreak2:
    andi t3, a1, 1              # skip if b is already odd
    bne t3, x0, .LinnerLoop3break
.LinnerLoop3:                   # make b odd
    srli a1, a1, 1
    andi t3, a1, 1
    beq t3, x0, .LinnerLoop3
.LinnerLoop3break:
    bgeu a1, a0, .LinnnerLoop3break2    # keep a <= b
    xor a0, a0, a1
    xor a1, a0, a1
    xor a0, a0, a1
.LinnnerLoop3break2:
    sub a1, a1, a0              # odd - odd is even, so shift at least once
    bne a1, x0, .LinnerLoop3
    sll a0, a0, t2              # put the shared factors of two back
    j .Ldone
.Lretb:
    add a0, a1, x0
.Ldone:
    ret
    .size   gcd_u32_asm, .-gcd_u32_asm
