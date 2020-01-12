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
#define FROM_SRAM    0
#define FROM_EEPROM  1
#define FROM_SPI     2

#define CP_Rd_SRAM   0
#define CP_Rd_SPI    1
#define CP_Rd_REG    2
#define CP_Rr_SRAM   3
#define CP_Rr_EEPROM 4

/* GLOBAL {{{1 ---------------------------------------------------------------*/
.global MEMCMP
.global R_MEMCMP
.global E_MEMCMP
.global SE_MEMCMP

.global MEMCPY
.global E_MEMCPY
.global S_MEMCPY

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
 *             a2         a4        <--- Register where byte is stored
 * MEMCMP    : SRAM(z) vs SRAM(x)
 * R_MEMCMP  : REG     vs SRAM(x)
 * E_MEMCMP  : SRAM(z) vs EEPROM(x)
 * SE_MEMCMP : SPI     vs EEPROM(x)
 * 
 * a1: Number of bytes to compare
 * x:  Address from SRAM or EEPROM
 * z:  Address from SRAM
 *
 * After routine:
 * a1, x and z unchanged.
 *
 * Note: SPI_MASTER_TRANSMIT and EEPROM_READ_N_INC don't modify many register,
 * only a4, xl, and xh. Modifying those two routines may break MEMCMP family.
 * ---------------------------------------------------------------------------*/
/* MEMCMP, R_MEMCMP, E_MEMCMP and SE_MEMCMP {{{3 -----------------------------*/
#ifndef OFAST
/* 32 bytes of FLASH less than OFAST implementation */
MEMCMP:
    ldi   t1, (1 << CP_Rd_SRAM) | (1 << CP_Rr_SRAM)
    rjmp  0f
R_MEMCMP:
    ldi   t1, (1 << CP_Rd_REG)  | (1 << CP_Rr_SRAM)
    rjmp  0f
E_MEMCMP:
    ldi   t1, (1 << CP_Rd_SRAM) | (1 << CP_Rr_EEPROM)
    rjmp  0f
SE_MEMCMP:
    ldi   t1, (1 << CP_Rd_SPI)  | (1 << CP_Rr_EEPROM)

0:  push  a1
    movw  t4, xl
    movw  t6, zl

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

    movw  xl, t4
    movw  zl, t6
    pop   a1
    ret
#else
/* MEMCMP {{{3 ---------------------------------------------------------------*/
MEMCMP:
    push  a1
    movw  t4, xl
    movw  t6, zl

0:  subi  a1, 1
    brlo  0f
    ld    a2, z+
    ld    a4, x+
    cp    a2, a4
    breq  0b
    /* See NOTE1 */
0:  rjmp  E_MEMCMP_EXIT
/* reusing instructions, reducing 8 bytes of FLASH
0:  inc   a1

    movw  zl, t6
    movw  xl, t4
    pop   a1
    ret
*/

/* R_MEMCMP {{{3 -----------------------------------------------------------*/
R_MEMCMP:
    push  a1
    movw  t4, xl

0:  subi  a1, 1
    brlo  0f
    ld    a4, x+
    cp    a2, a4
    breq  0b
    /* See NOTE1 */
0:  rjmp  SE_MEMCMP_EXIT
/* reusing instructions, reducing 6 bytes of FLASH
0:  inc   a1

    movw  xl, t4
    pop   a1
    ret
*/

/* E_MEMCMP {{{3 ------------------------------------------------------------*/
E_MEMCMP:
    push  a1
    movw  t4, xl
    movw  t6, zl

0:  subi  a1, 1
    brlo  0f
    ld    a2, z+
    rcall EEPROM_READ_N_INC
    cp    a2, a4
    breq  0b
    /* See NOTE1 */
E_MEMCMP_EXIT:
0:  inc   a1

    movw  zl, t6
    movw  xl, t4
    pop   a1
    ret

/* SE_MEMCMP {{{3 ------------------------------------------------------------*/
SE_MEMCMP:
    push  a1
    movw  t4, xl

0:  subi  a1, 1
    brlo  0f
    rcall EEPROM_READ_N_INC
    mov   a2, a4
    rcall SPI_MASTER_TRANSMIT
    cp    a2, a4
    breq  0b
    /* See NOTE1 */
SE_MEMCMP_EXIT:
0:  inc   a1

    movw  xl, t4
    pop   a1
    ret
#endif

/* MEMCPY variants {{{2 --------------------------------------------------------
 * Copy a1 bytes from (SRAM|EEPROM|SPI) to SRAM.
 *
 * MEMCPY:   SRAM(x+)   -> SRAM(z+)
 * E_MEMCPY: EEPROM(x+) -> SRAM(z+)
 * S_MEMCPY: SPI        -> SRAM(z+)
 *
 * After routine:
 * a1 unchanged.
 * x += a1 When calling MEMCPY and E_MEMCPY.
 * z += a1 When calling MEMCPY, E_MEMCPY and S_MEMCPY.
 * ---------------------------------------------------------------------------*/
/* MEMCPY, E_MEMCPY and S_MEMCPY {{{3 ----------------------------------------*/
#ifndef OFAST
/* Difference is 4 bytes in FLASH... Maybe not worth it. */
MEMCPY:
    ldi   t1, (1 << FROM_SRAM)
    rjmp  0f
E_MEMCPY:
    ldi   t1, (1 << FROM_EEPROM)
    rjmp  0f
S_MEMCPY:
    ldi   t1, (1 << FROM_SPI)
0:  push  a1

0:  subi  a1, 1
    brlo  0f
    /* SRAM => a4 */
    sbrc  t1, FROM_SRAM
    ld    a4, x+
    /* SPI => a4 */
    sbrc  t1, FROM_SPI
    rcall SPI_MASTER_TRANSMIT
    /* EEPROM => a4 */
    sbrc  t1, FROM_EEPROM
    rcall EEPROM_READ_N_INC
    /* a4 => z */
    st    z+, a4
    rjmp  0b

0:  pop   a1
    ret
#else
/* MEMCPY {{{3 ---------------------------------------------------------------*/
MEMCPY:
    push  a1

0:  subi  a1, 1
    brlo  S_MEMCPY_EXIT
    ld    t1, x+
    st    z+, t1
    rjmp  0b

/* E_MEMCPY {{{3 ------------------------------------------------------------*/
E_MEMCPY:
    push  a1

0:  subi  a1, 1
    brlo  S_MEMCPY_EXIT
    rcall EEPROM_READ_N_INC
    st    z+, a4
    rjmp  0b

/* S_MEMCPY {{{3 -------------------------------------------------------------*/
S_MEMCPY:
    push  a1

0:  subi  a1, 1
    brlo  0f
    rcall SPI_MASTER_TRANSMIT
    st    z+, a4
    rjmp  0b

    /* Common pop and return for MEMCPY, E_MEMCPY and S_MEMCPY. */
S_MEMCPY_EXIT:
0:  pop   a1
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
