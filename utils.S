/* vim: set filetype=S foldmethod=marker: */
/* INCLUDES {{{1 */
.NOLIST
#include <avr/io.h>
#include "defs.h"
.LIST

/*******************************************************************************
 * When copying from pointer to pointer:
 *   - Use Y as Src
 *   - Use Z as Dst
 *   - ARG_REG1 is the length to copy
 ******************************************************************************/

/* GLOBAL {{{1 ---------------------------------------------------------------*/
.global MEMCMP
.global MEMCPY
.global REG_MEMCMP
.global ES_MEMCMP
.global ES_MEMCPY
.global MEMSWAP
.global ADD_32b
.global NUMBER_TO_ASCII
.global SDIV

/* TEXT {{{1 -----------------------------------------------------------------*/
.section .text

/* MEMCMP {{{2 -----------------------------------------------------------------
 * Compare ARG_REG1 bytes pointed by Y and Z
 * Y, Z and ARG_REG1 unchanged after routine
 * Zero flag => 1 if memory regions are equal, 0 otherwise */
MEMCMP:
    push  YL
    push  YH
    push  ZL
    push  ZH
    push  ARG_REG1

MEMCMP_LOOP:
    dec   ARG_REG1
    brmi  MEMCMP_END
    ld    TMP_REG1, Y+
    ld    TMP_REG2, Z+
    cp    TMP_REG1, TMP_REG2
    breq  MEMCMP_LOOP
    /* If falling here from line above, then ARG_REG1 didn't reach -1, then
     * after the inc below, it will have a value greater than Zero, setting the
     * Zero flag to 0 */
MEMCMP_END:
    inc   ARG_REG1
    pop   ARG_REG1
    pop   ZH
    pop   ZL
    pop   YH
    pop   YL
    ret

/* MEMCPY {{{2 -----------------------------------------------------------------
 * Copy from Y to Z ARG_REG1 bytes
 * ARG_REG1 unchanged after routine
 * Y += ARG_REG1 ; after routine
 * Z += ARG_REG1 ; after routine */
MEMCPY:
    push  ARG_REG1

MEMCPY_LOOP:
    dec   ARG_REG1
    brmi  MEMCPY_END
    ld    TMP_REG1, Y+
    st    Z+, TMP_REG1
    rjmp  MEMCPY_LOOP

MEMCPY_END:
    pop   ARG_REG1
    ret

/* REG_MEMCMP {{{2 -------------------------------------------------------------
 * Check if memory pointed by Y across ARG_REG1 bytes is equal to ARG_REG2 */
REG_MEMCMP:
    push  YL
    push  YH
    push  ARG_REG1

REG_MEMCMP_LOOP:
    dec   ARG_REG1
    brmi  REG_MEMCMP_END
    ld    TMP_REG1, Y+
    cp    ARG_REG2, TMP_REG1
    breq  REG_MEMCMP_LOOP
    /* If falling here from line above, then ARG_REG1 didn't reach -1, then
     * after the inc below, it will have a value greater than Zero, setting the
     * Zero flag to 0 */
REG_MEMCMP_END:
    inc   ARG_REG1
    pop   ARG_REG1
    pop   YH
    pop   YL
    ret

/* ES_MEMCMP {{{2 --------------------------------------------------------------
 * Same as MEMCMP, but Y from EEPROM */
ES_MEMCMP:
    push  YL
    push  YH
    push  ZL
    push  ZH
    push  ARG_REG1

ES_MEMCMP_LOOP:
    dec   ARG_REG1
    brmi  ES_MEMCMP_END
    rcall EEPROM_READ_N_INC
    ld    TMP_REG1, Z+
    cp    TMP_REG1, RTV_L_REG
    breq  ES_MEMCMP_LOOP
    /* If falling here from line above, then ARG_REG1 didn't reach -1, then
     * after the inc below, it will have a value greater than Zero, setting the
     * Zero flag to 0 */
ES_MEMCMP_END:
    inc   ARG_REG1
ES_MEMCPY_EXIT:
    pop   ARG_REG1
    pop   ZH
    pop   ZL
    pop   YH
    pop   YL
    ret

/* ES_MEMCPY {{{2 --------------------------------------------------------------
 * Same as MEMCPY, but source from EEPROM */
ES_MEMCPY:
    push  ARG_REG1
ES_MEMCPY_LOOP:
    dec   ARG_REG1
    brmi  ES_MEMCPY_END
    rcall EEPROM_READ_N_INC
    st    Z+, RTV_L_REG
    rjmp  ES_MEMCPY_LOOP

ES_MEMCPY_END:
    pop   ARG_REG1
    ret

/* MEMSWAP {{{2  ---------------------------------------------------------------
 * Swap the memory pointed by Y and Z across ARG_REG1 bytes */
MEMSWAP:
    ld   TMP_REG1, Y
    ld   TMP_REG2, Z
    st   Y+, TMP_REG2
    st   Z+, TMP_REG1
    dec  ARG_REG1
    brne MEMSWAP
    ret

/* ADD_32b {{{2 ----------------------------------------------------------------
 * 32bits addition, Big endian
 * Y points to 32b number*/
ADD_32b:
    adiw  YL, 4
    clc
0:  ld    TMP_REG1, -Y
    adc   TMP_REG1, ARG_REG1
    clr   ARG_REG1
    st    Y, TMP_REG1
    dec   TMP_REG2
    brne  0b
    ret

/* Single  division {{{2  -------------------------------------------------------
 * Do one division iteration, return one digit of the quotient and the remainder
 * Divide 1 byte by another byte
 * ARG_REG1: Numerator
 * ARG_REG2: Denominator
 * RTV_L_REG: Quotient
 * RTV_H_REG: Remainder
 */
SDIV:
    clr   RTV_L_REG
0:  sub   ARG_REG1, ARG_REG2
    brcs  1f /* Break loop if carrier set */
    inc   RTV_L_REG /* Quotient++ */
    rjmp  0b /* Jump to the beginning of the loop */
1:  mov   RTV_H_REG, ARG_REG1
    add   RTV_H_REG, ARG_REG2
    ret

/* Byte to ASCII {{{2  ---------------------------------------------------------
*/
NUMBER_TO_ASCII:
    ldi   RTV_L_REG, '0'
    add   RTV_L_REG, ARG_REG1
    ret

.end
