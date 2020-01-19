/* vim: set filetype=S foldmethod=marker: */
/* INCLUDES {{{1 */
.NOLIST
#include <avr/io.h>
#include "defs.h"
#include "enc28j60.h"
.LIST

/*******************************************************************************
 * When copying from pointer to pointer:
 *   - Use x as Src
 *   - Use z as Dst
 *   - a1 is the length to copy
 ******************************************************************************/

/* MACORS {{{1 ---------------------------------------------------------------*/
#define OFAST

#define FROM_SRAM    0
#define FROM_EEPROM  1
#define FROM_SPI     2
#define FROM_ZERO    3
#define TO_SRAM      4
#define TO_EEPROM    5
#define TO_SPI       6

#define CP_Rd_SRAM   0
#define CP_Rd_SPI    1
#define CP_Rd_REG    2
#define CP_Rr_SRAM   3
#define CP_Rr_EEPROM 4

/* GLOBAL {{{1 ---------------------------------------------------------------*/
.global MEMCMP_SRAM_SRAM
.global MEMCMP_SRAM_EEPROM
.global MEMCMP_SPI_EEPROM
.global MEMCMP_REG_SRAM

.global MEMCPY_SRAM_SRAM
.global MEMCPY_SRAM_SPI
.global MEMCPY_SRAM_EEPROM
.global MEMCPY_EEPROM_SRAM
.global MEMCPY_EEPROM_SPI
.global MEMCPY_SPI_SRAM
.global MEMCPY_SPI_EEPROM
.global MEMCPY_ZERO_SPI

.global MEMSWAP
.global ADD_UINT32_BIG_ENDIAN
.global SDIV
.global BZERO

/* TEXT {{{1 -----------------------------------------------------------------*/
.section .text

/* MEMCMP variants {{{2 --------------------------------------------------------
 * Compare a1 bytes from (SRAM|SPI|REG) and (SRAM|EEPROM).
 * If data is the same, then Z <= 1, else Z <= 0
 * Lazy comparison, stop after finding first byte that mismatch.
 * Last compared byte placed in a2 and a4
 *
 * Table of comparisons:
 *
 *                     a2         a4        <--- Register where byte is stored
 * MEMCMP_SRAM_SRAM:   SRAM(z) vs SRAM(x)
 * MEMCMP_SRAM_EEPROM: SRAM(z) vs EEPROM(x)
 * MEMCMP_SPI_EEPROM:  SPI     vs EEPROM(x)
 * MEMCMP_REG_SRAM:    REG     vs SRAM(x)
 *
 * a1: Number of bytes to compare
 * x:  Address from SRAM or EEPROM
 * z:  Address from SRAM
 *
 * After routine:
 * a1, x and z unchanged.
 *
 * Note: SPI_MASTER_TRANSMIT and EEPROM_READ_N_INC don't modify many register,
 * only a4, xl, and xh. Modifying those two routines may break MEMCMP_SRAM_SRAM
 * family.
 * ---------------------------------------------------------------------------*/
/* MEMCMP_* {{{3 -------------------------------------------------------------*/
#ifndef OFAST
/* 32 bytes of FLASH less than OFAST implementation */
MEMCMP_SRAM_SRAM:
    ldi   t1, (1 << CP_Rd_SRAM) | (1 << CP_Rr_SRAM)
    rjmp  0f
MEMCMP_SRAM_EEPROM:
    ldi   t1, (1 << CP_Rd_SRAM) | (1 << CP_Rr_EEPROM)
    rjmp  0f
MEMCMP_SPI_EEPROM:
    ldi   t1, (1 << CP_Rd_SPI)  | (1 << CP_Rr_EEPROM)
    rjmp  0f
MEMCMP_REG_SRAM:
    ldi   t1, (1 << CP_Rd_REG)  | (1 << CP_Rr_SRAM)

0:  push  a1
    movw  p1, xl
    movw  p2, zl

0:  subi  a1, 1
    brlo  0f

    /* Rd         Rr
     * SRAM(z) vs SRAM(x)
     * REG     vs SRAM(x)
     * SRAM(z) vs EEPROM(x)
     * SPI     vs EEPROM(x)
     */
    /* Rd (SRAM|SPI|REG) => a2 */
    sbrc  t1, CP_Rd_SRAM
    ld    a2, z+
    sbrc  t1, CP_Rd_SPI
    rcall SPI_MASTER_TRANSMIT
    sbrc  t1, CP_Rd_SPI
    mov   a2, a4

    /* Rr (SRAM|EEPROM) => a4 */
    sbrc  t1, CP_Rr_SRAM
    ld    a4, x+
    sbrc  t1, CP_Rr_EEPROM
    rcall EEPROM_READ_N_INC

    /* Compare */
    cp    a2, a4
    breq  0b

    /* NOTE1: If falling here from line above, then a1 didn't reach -1, then
     * after the inc below, it will have a value greater than Zero, setting the
     * Zero flag to 0 */
0:  inc   a1

    movw  xl, p1
    movw  zl, p2
    pop   a1
    ret
#else
/* MEMCMP_SRAM_SRAM {{{3 -----------------------------------------------------*/
MEMCMP_SRAM_SRAM:
    push  a1
    movw  p1, xl
    movw  p2, zl

0:  subi  a1, 1
    brlo  8f
    ld    a2, z+
    ld    a4, x+
    cp    a2, a4
    breq  0b
    /* See NOTE1 */
    rjmp  8f
/* reusing instructions, reducing 8 bytes of FLASH
8:  inc   a1

    movw  zl, p2
    movw  xl, p1
    pop   a1
    ret
*/

/* MEMCMP_SRAM_EEPROM {{{3 ---------------------------------------------------*/
MEMCMP_SRAM_EEPROM:
    push  a1
    movw  p1, xl
    movw  p2, zl

0:  subi  a1, 1
    brlo  8f
    ld    a2, z+
    rcall EEPROM_READ_N_INC
    cp    a2, a4
    breq  0b
    /* See NOTE1 */
8:  inc   a1

    movw  zl, p2
    movw  xl, p1
    pop   a1
    ret

/* MEMCMP_SPI_EEPROM {{{3 ----------------------------------------------------*/
MEMCMP_SPI_EEPROM:
    push  a1
    movw  p1, xl

0:  subi  a1, 1
    brlo  8f
    rcall EEPROM_READ_N_INC
    mov   a2, a4
    rcall SPI_MASTER_TRANSMIT
    cp    a2, a4
    breq  0b
    /* See NOTE1 */
    rjmp  8f
/* reusing instructions, reducing 6 bytes of FLASH
8:  inc   a1

    movw  xl, p1
    pop   a1
    ret
*/

/* MEMCMP_REG_SRAM {{{3 ------------------------------------------------------*/
MEMCMP_REG_SRAM:
    push  a1
    movw  p1, xl

0:  subi  a1, 1
    brlo  8f
    ld    a4, x+
    cp    a2, a4
    breq  0b
    /* See NOTE1 */
8:  inc   a1

    movw  xl, p1
    pop   a1
    ret
#endif

/* MEMCPY variants {{{2 --------------------------------------------------------
 * Copy a1 bytes from (SRAM|EEPROM|SPI) to (SRAM|EEPROM|SPI).
 *
 * MEMCPY_SRAM_SRAM:   SRAM(x+)   -> SRAM(z+)
 * MEMCPY_SRAM_SPI:    SRAM(x+)   -> SPI
 * MEMCPY_SRAM_EEPROM: SRAM(x+)   -> EEPROM(z+)
 * MEMCPY_EEPROM_SRAM: EEPROM(x+) -> SRAM(z+)
 * MEMCPY_EEPROM_SPI:  EEPROM(x+) -> SPI
 * MEMCPY_SPI_SRAM:    SPI        -> SRAM(z+)
 * MEMCPY_SPI_EEPROM:  SPI        -> EEPROM(z+)
 * MEMCPY_ZERO_SPI:    0          -> SPI
 *
 * After routine:
 * a1 unchanged.
 * x += a1 When calling MEMCPY variant from SRAM or EEPROM.
 * z += a1 When calling MEMCPY variant to SRAM or EEPROM.
 * ---------------------------------------------------------------------------*/
/* MEMCPY_* {{{3 -------------------------------------------------------------*/
#ifndef OFAST
/* Difference is 4 bytes in FLASH... Maybe not worth it. */
MEMCPY_SRAM_SRAM:
    ldi   t1, (1 << FROM_SRAM)|(1 << TO_SRAM)
    rjmp  0f
MEMCPY_SRAM_SPI:
    ldi   t1, (1 << FROM_SRAM)|(1 << TO_SPI)
    rjmp  0f
MEMCPY_SRAM_EEPROM:
    ldi   t1, (1 << FROM_SRAM)|(1 << TO_EEPROM)
    rjmp  0f
MEMCPY_EEPROM_SRAM:
    ldi   t1, (1 << FROM_EEPROM)|(1 << TO_SRAM)
    rjmp  0f
MEMCPY_EEPROM_SPI:
    ldi   t1, (1 << FROM_EEPROM)|(1 << TO_SPI)
    rjmp  0f
MEMCPY_SPI_SRAM:
    ldi   t1, (1 << FROM_SPI)|(1 << TO_SRAM)
    rjmp  0f
MEMCPY_SPI_EEPROM:
    ldi   t1, (1 << FROM_SPI)|(1 << TO_EEPROM)
    rjmp  0f
MEMCPY_ZERO_SPI:
    ldi   t1, (1 << FROM_ZERO)|(1 << TO_SPI)

0:  push  a1

    mov   t3, a1
0:  subi  t3, 1
    brlo  0f
    /* From: */
    ldi   a4, 0               /* a4 <- 0 (FROM_ZERO) */
    sbrc  t1, FROM_SRAM       /* a4 <- SRAM */
    ld    a4, x+
    sbrc  t1, FROM_SPI        /* a4 <- SPI */
    rcall SPI_MASTER_TRANSMIT
    sbrc  t1, FROM_EEPROM     /* a4 <- EEPROM */
    rcall EEPROM_READ_N_INC
    /* To: */
    sbrc  t1, TO_SRAM         /* z <- a4 */
    st    z+, a4
    sbrs  t1, TO_EEPROM       /* (TO_EEPROM|TO_SPI) ? a1 <- a4 */
    sbrc  t1, TO_SPI
    mov   a1, a4
    sbrc  t1, TO_EEPROM
    rcall EEPROM_WRITE_N_INC  /* EEPROM(z) <- a1 */
    sbrc  t1, TO_SPI
    rcall SPI_MASTER_TRANSMIT /* SPI <- a1 */
    rjmp  0b

0:  pop   a1
    ret
#else
/* MEMCPY_SRAM_SRAM {{{3 -----------------------------------------------------*/
MEMCPY_SRAM_SRAM:
    push  a1

0:  subi  a1, 1
    brlo  8f
    ld    t1, x+
    st    z+, t1
    rjmp  0b

/* MEMCPY_SRAM_SPI {{{3 ------------------------------------------------------*/
MEMCPY_SRAM_SPI:
    push  a1

    mov   t3, a1
0:  subi  t3, 1
    brlo  8f
    ld    a1, x+
    rcall SPI_MASTER_TRANSMIT
    rjmp  0b

/* MEMCPY_SRAM_EEPROM {{{3 ---------------------------------------------------*/
MEMCPY_SRAM_EEPROM:
    push  a1

    mov   t3, a1
0:  subi  t3, 1
    brlo  8f
    ld    a1, x+
    rcall EEPROM_WRITE_N_INC
    rjmp  0b

/* MEMCPY_EEPROM_SRAM {{{3 ---------------------------------------------------*/
MEMCPY_EEPROM_SRAM:
    push  a1

0:  subi  a1, 1
    brlo  8f
    rcall EEPROM_READ_N_INC
    st    z+, a4
    rjmp  0b

/* MEMCPY_EEPROM_SPI {{{3 ----------------------------------------------------*/
MEMCPY_EEPROM_SPI:
    push  a1

    mov   t3, a1
0:  subi  t3, 1
    brlo  8f
    rcall EEPROM_READ_N_INC
    mov   a1, a4
    rcall SPI_MASTER_TRANSMIT
    rjmp  0b

/* MEMCPY_SPI_SRAM {{{3 ------------------------------------------------------*/
MEMCPY_SPI_SRAM:
    push  a1

0:  subi  a1, 1
    brlo  8f
    rcall SPI_MASTER_TRANSMIT
    st    z+, a4
    rjmp  0b

/* MEMCPY_SPI_EEPROM {{{3 ----------------------------------------------------*/
MEMCPY_SPI_EEPROM:
    push  a1

    mov   t3, a1
0:  subi  t3, 1
    brlo  8f
    rcall SPI_MASTER_TRANSMIT
    mov   a1, a4
    rcall EEPROM_WRITE_N_INC
    rjmp  0b

/* MEMCPY_ZERO_SPI {{{3 ------------------------------------------------------*/
MEMCPY_ZERO_SPI:
    push  a1

    mov   t3, a1
    clr   a1
0:  subi  t3, 1
    brlo  8f
    rcall SPI_MASTER_TRANSMIT
    rjmp  0b

    /* Common pop and return for MEMCPY_SRAM_SRAM, MEMCPY_EEPROM_SRAM and
     * MEMCPY_SPI_SRAM. */
8:  pop   a1
    ret
#endif

/* MEMSWAP {{{2  ---------------------------------------------------------------
 * Swap a1 bytes on the SRAM pointed by x and z.
 * BEWARE if a1 is set to zero by calling routine, then it will swap 256 bytes.
 *
 * After routine:
 * x += a1
 * z += a1
 * a1 = 0
 * ---------------------------------------------------------------------------*/
MEMSWAP:
    ld   t1, x
    ld   t2, z
    st   x+, t2
    st   z+, t1
    dec  a1
    brne MEMSWAP
    ret

/* ADD_UINT32_BIG_ENDIAN {{{2 --------------------------------------------------
 * Add a1 to the uint32 number pointed by x in SRAM. Big endian addition.
 *
 * a1: Number to be added
 * x: Pointer to uint32 number in SRAM
 *
 * After routine:
 * a1 = 0
 * x unchanged.
 * SREG(C) set on overflow.
 * ---------------------------------------------------------------------------*/
ADD_UINT32_BIG_ENDIAN:
    adiw  xl, 4
    ldi   t3, 4
    clc
0:  ld    t1, -x
    adc   t1, a1
    clr   a1
    st    x, t1
    dec   t3
    brne  0b
    ret

/* Single division {{{2 --------------------------------------------------------
 * One division iteration, return one digit of the quotient and the remainder.
 * Divides 1 byte over another byte
 *
 * a1/a2 => a4 Remainder a3
 *
 * a1: Numerator
 * a2: Denominator
 *
 * After routine:
 * a1: Remainder - Denominator.
 * a2: Unchanged.
 * a3: Remainder
 * a4: Quotient
 *
 * Note: if a2 set to zero, then this routine will never return.
 * ---------------------------------------------------------------------------*/
SDIV:
    clr   a4
0:  sub   a1, a2
    brcs  1f /* Break loop if carrier set */
    inc   a4 /* Quotient++ */
    rjmp  0b /* Jump to the beginning of the loop */
1:  mov   a3, a1
    add   a3, a2
    ret

/* BZERO {{{2 ------------------------------------------------------------------
 * Set a1 bytes to zero pointed by z on the SRAM
 *
 * a1: Number of bytes to set to zero.
 * z: Pointer to memory in SRAM to be set to zero.
 *
 * After routine:
 * z += a1
 * a1 = 0
 * ---------------------------------------------------------------------------*/
BZERO:
    st    z+, zero
    dec   a1
    brne  BZERO
    ret

.end
