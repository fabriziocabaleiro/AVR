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

/* GLOBAL {{{1 ---------------------------------------------------------------*/
.global MEMCMP
.global MEMCPY
.global REG_MEMCMP
.global ES_MEMCMP
.global ES_MEMCPY
.global EN_MEMCMP
.global MEMSWAP
.global ADD_UINT32_BIG_ENDIAN
.global SDIV
.global BZERO

/* TEXT {{{1 -----------------------------------------------------------------*/
.section .text

/* MEMCMP {{{2 -----------------------------------------------------------------
 * Compare a1 bytes pointed by x and z
 * x, z and a1 unchanged after routine
 * Zero flag => 1 if memory regions are equal, 0 otherwise */
MEMCMP:
    push  xl
    push  xh
    push  zl
    push  zh
    push  a1

MEMCMP_LOOP:
    dec   a1
    brmi  MEMCMP_END
    ld    t1, x+
    ld    t2, z+
    cp    t1, t2
    breq  MEMCMP_LOOP
    /* If falling here from line above, then a1 didn't reach -1, then
     * after the inc below, it will have a value greater than Zero, setting the
     * Zero flag to 0 */
MEMCMP_END:
    inc   a1
    pop   a1
    pop   zh
    pop   zl
    pop   xh
    pop   xl
    ret

/* MEMCPY {{{2 -----------------------------------------------------------------
 * Copy from x to z a1 bytes
 * a1 unchanged after routine
 * x += a1 ; after routine
 * z += a1 ; after routine */
MEMCPY:
    push  a1

MEMCPY_LOOP:
    dec   a1
    brmi  MEMCPY_END
    ld    t1, x+
    st    z+, t1
    rjmp  MEMCPY_LOOP

MEMCPY_END:
    pop   a1
    ret

/* REG_MEMCMP {{{2 -------------------------------------------------------------
 * Check if memory pointed by x across a1 bytes is equal to a2 */
REG_MEMCMP:
    push  xl
    push  xh
    push  a1

REG_MEMCMP_LOOP:
    dec   a1
    brmi  REG_MEMCMP_END
    ld    t1, x+
    cp    a2, t1
    breq  REG_MEMCMP_LOOP
    /* If falling here from line above, then a1 didn't reach -1, then
     * after the inc below, it will have a value greater than Zero, setting the
     * Zero flag to 0 */
REG_MEMCMP_END:
    inc   a1
    pop   a1
    pop   xh
    pop   xl
    ret

/* ES_MEMCMP {{{2 --------------------------------------------------------------
 * EEPROM SRAM Compare
 * Same as MEMCMP, but x from EEPROM */
ES_MEMCMP:
    push  xl
    push  xh
    push  zl
    push  zh
    push  a1

ES_MEMCMP_LOOP:
    dec   a1
    brmi  ES_MEMCMP_END
    rcall EEPROM_READ_N_INC
    ld    t1, z+
    cp    t1, a4
    breq  ES_MEMCMP_LOOP
    /* If falling here from line above, then a1 didn't reach -1, then
     * after the inc below, it will have a value greater than Zero, setting the
     * Zero flag to 0 */
ES_MEMCMP_END:
    inc   a1
ES_MEMCPY_EXIT:
    pop   a1
    pop   zh
    pop   zl
    pop   xh
    pop   xl
    ret

/* EN_MEMCMP {{{2 --------------------------------------------------------------
 * EEPROM NETWORK Compare
 * x from EEPROM. */
EN_MEMCMP:
0:  dec   a1
    brmi  0f
    rcall EEPROM_READ_N_INC
    mov   t1, a4
    ETH_READ_NEXT_BYTE
    cp    t1, a4
    breq  0b
    /* If falling here from line above, then a1 didn't reach -1, then
     * after the inc below, it will have a value greater than Zero, setting the
     * Zero flag to 0 */
0:  inc   a1
    ret

/* ES_MEMCPY {{{2 --------------------------------------------------------------
 * Same as MEMCPY, but source from EEPROM */
ES_MEMCPY:
    push  a1
ES_MEMCPY_LOOP:
    dec   a1
    brmi  ES_MEMCPY_END
    rcall EEPROM_READ_N_INC
    st    z+, a4
    rjmp  ES_MEMCPY_LOOP

ES_MEMCPY_END:
    pop   a1
    ret

/* MEMSWAP {{{2  ---------------------------------------------------------------
 * Swap the memory pointed by x and z across a1 bytes */
MEMSWAP:
    ld   t1, x
    ld   t2, z
    st   x+, t2
    st   z+, t1
    dec  a1
    brne MEMSWAP
    ret

/* ADD_UINT32_BIG_ENDIAN {{{2 ----------------------------------------------------------------
 * 4 bytes addition, Big endian
 * x points to 32b number*/
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

/* Single  division {{{2  -------------------------------------------------------
 * Do one division iteration, return one digit of the quotient and the remainder
 * Divide 1 byte by another byte
 * a1: Numerator
 * a2: Denominator
 * a3: Remainder
 * a4: Quotient
 */
SDIV:
    clr   a4
0:  sub   a1, a2
    brcs  1f /* Break loop if carrier set */
    inc   a4 /* Quotient++ */
    rjmp  0b /* Jump to the beginning of the loop */
1:  mov   a3, a1
    add   a3, a2
    ret

/* BZERO -----------------------------------------------------------------------
 * Set a1 bytes to zero the memory pointed by z
 */
BZERO:
    subi  a1, 1
    brlo  0f
    st    z+, zero
    rjmp  BZERO
0:  ret

.end
