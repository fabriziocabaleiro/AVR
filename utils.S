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
.global MEMCMP_REG
.global ES_MEMCMP
.global ES_MEMCPY

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

/* MEMCMP_REG {{{2 -------------------------------------------------------------
 * Check if memory pointed by Y across ARG_REG1 bytes is equal to ARG_REG2 */
MEMCMP_REG:
    push  YL
    push  YH
    push  ARG_REG1

MEMCMP_REG_LOOP:
    dec   ARG_REG1
    brmi  MEMCMP_REG_END
    ld    TMP_REG1, Y+
    cp    ARG_REG2, TMP_REG1
    breq  MEMCMP_REG_LOOP
    /* If falling here from line above, then ARG_REG1 didn't reach -1, then
     * after the inc below, it will have a value greater than Zero, setting the
     * Zero flag to 0 */
MEMCMP_REG_END:
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

.end
