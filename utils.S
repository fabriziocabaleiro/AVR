/* vim: set filetype=S foldmethod=marker: */
/* INCLUDES {{{1 */
.NOLIST
#include <avr/io.h>
#include "defs.h"
#include "enc28j60.h"
.LIST

/*******************************************************************************
 * When copying from pointer to pointer:
 *   - Use Y as Src
 *   - Use Z as Dst
 *   - x1 is the length to copy
 ******************************************************************************/

/* GLOBAL {{{1 ---------------------------------------------------------------*/
.global MEMCMP
.global MEMCPY
.global REG_MEMCMP
.global ES_MEMCMP
.global ES_MEMCPY
.global EN_MEMCMP
.global MEMSWAP
.global ADD_32b
.global SDIV

/* TEXT {{{1 -----------------------------------------------------------------*/
.section .text

/* MEMCMP {{{2 -----------------------------------------------------------------
 * Compare x1 bytes pointed by Y and Z
 * Y, Z and x1 unchanged after routine
 * Zero flag => 1 if memory regions are equal, 0 otherwise */
MEMCMP:
    push  YL
    push  YH
    push  ZL
    push  ZH
    push  x1

MEMCMP_LOOP:
    dec   x1
    brmi  MEMCMP_END
    ld    t1, Y+
    ld    t2, Z+
    cp    t1, t2
    breq  MEMCMP_LOOP
    /* If falling here from line above, then x1 didn't reach -1, then
     * after the inc below, it will have a value greater than Zero, setting the
     * Zero flag to 0 */
MEMCMP_END:
    inc   x1
    pop   x1
    pop   ZH
    pop   ZL
    pop   YH
    pop   YL
    ret

/* MEMCPY {{{2 -----------------------------------------------------------------
 * Copy from Y to Z x1 bytes
 * x1 unchanged after routine
 * Y += x1 ; after routine
 * Z += x1 ; after routine */
MEMCPY:
    push  x1

MEMCPY_LOOP:
    dec   x1
    brmi  MEMCPY_END
    ld    t1, Y+
    st    Z+, t1
    rjmp  MEMCPY_LOOP

MEMCPY_END:
    pop   x1
    ret

/* REG_MEMCMP {{{2 -------------------------------------------------------------
 * Check if memory pointed by Y across x1 bytes is equal to x2 */
REG_MEMCMP:
    push  YL
    push  YH
    push  x1

REG_MEMCMP_LOOP:
    dec   x1
    brmi  REG_MEMCMP_END
    ld    t1, Y+
    cp    x2, t1
    breq  REG_MEMCMP_LOOP
    /* If falling here from line above, then x1 didn't reach -1, then
     * after the inc below, it will have a value greater than Zero, setting the
     * Zero flag to 0 */
REG_MEMCMP_END:
    inc   x1
    pop   x1
    pop   YH
    pop   YL
    ret

/* ES_MEMCMP {{{2 --------------------------------------------------------------
 * EEPROM SRAM Compare
 * Same as MEMCMP, but Y from EEPROM */
ES_MEMCMP:
    push  YL
    push  YH
    push  ZL
    push  ZH
    push  x1

ES_MEMCMP_LOOP:
    dec   x1
    brmi  ES_MEMCMP_END
    rcall EEPROM_READ_N_INC
    ld    t1, Z+
    cp    t1, x4
    breq  ES_MEMCMP_LOOP
    /* If falling here from line above, then x1 didn't reach -1, then
     * after the inc below, it will have a value greater than Zero, setting the
     * Zero flag to 0 */
ES_MEMCMP_END:
    inc   x1
ES_MEMCPY_EXIT:
    pop   x1
    pop   ZH
    pop   ZL
    pop   YH
    pop   YL
    ret

/* EN_MEMCMP {{{2 --------------------------------------------------------------
 * EEPROM NETWORK Compare
 * Y from EEPROM. */
EN_MEMCMP:
0:  dec   x1
    brmi  0f
    rcall EEPROM_READ_N_INC
    mov   t1, x4
    ETH_READ_NEXT_BYTE
    cp    t1, x4
    breq  0b
    /* If falling here from line above, then x1 didn't reach -1, then
     * after the inc below, it will have a value greater than Zero, setting the
     * Zero flag to 0 */
0:  inc   x1
    ret

/* ES_MEMCPY {{{2 --------------------------------------------------------------
 * Same as MEMCPY, but source from EEPROM */
ES_MEMCPY:
    push  x1
ES_MEMCPY_LOOP:
    dec   x1
    brmi  ES_MEMCPY_END
    rcall EEPROM_READ_N_INC
    st    Z+, x4
    rjmp  ES_MEMCPY_LOOP

ES_MEMCPY_END:
    pop   x1
    ret

/* MEMSWAP {{{2  ---------------------------------------------------------------
 * Swap the memory pointed by Y and Z across x1 bytes */
MEMSWAP:
    ld   t1, Y
    ld   t2, Z
    st   Y+, t2
    st   Z+, t1
    dec  x1
    brne MEMSWAP
    ret

/* ADD_32b {{{2 ----------------------------------------------------------------
 * 32bits addition, Big endian
 * Y points to 32b number*/
ADD_32b:
    adiw  YL, 4
    clc
0:  ld    t1, -Y
    adc   t1, x1
    clr   x1
    st    Y, t1
    dec   t2
    brne  0b
    ret

/* Single  division {{{2  -------------------------------------------------------
 * Do one division iteration, return one digit of the quotient and the remainder
 * Divide 1 byte by another byte
 * x1: Numerator
 * x2: Denominator
 * x3: Remainder
 * x4: Quotient
 */
SDIV:
    clr   x4
0:  sub   x1, x2
    brcs  1f /* Break loop if carrier set */
    inc   x4 /* Quotient++ */
    rjmp  0b /* Jump to the beginning of the loop */
1:  mov   x3, x1
    add   x3, x2
    ret

.end
