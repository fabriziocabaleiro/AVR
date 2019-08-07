/* vim: set filetype=S foldmethod=marker: */
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

.global MEMCMP
.global MEMCPY
.global ES_MEMCMP
.global ES_MEMCPY

.section .data

.section .text

/* MEMCMP {{{1 -----------------------------------------------------------------
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

/* MEMCPY {{{1 -----------------------------------------------------------------
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

/* ES_MEMCMP {{{1 --------------------------------------------------------------
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
    cp    TMP_REG1, RETURN_VALUE
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

/* ES_MEMCPY {{{1 --------------------------------------------------------------
 * Same as MEMCPY, but source from EEPROM */
ES_MEMCPY:
    push  ARG_REG1
ES_MEMCPY_LOOP:
    dec   ARG_REG1
    brmi  ES_MEMCPY_END
    rcall EEPROM_READ_N_INC
    st    Z+, RETURN_VALUE
    rjmp  ES_MEMCPY_LOOP

ES_MEMCPY_END:
    pop   ARG_REG1
    ret

.end
