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
.global ES_MEMCPY

.section .data

.section .text

/* MEMCMP {{{
 * Compare ARG_REG1 bytes pointed by Y and Z
 * Y, Z and ARG_REG1 unchanged after routine
 * RETURN_VALUE => 0 if memory areas are equal, 1 otherwise */
MEMCMP:
    push  YL
    push  YH
    push  ZL
    push  ZH
    push  ARG_REG1

    clr   RETURN_VALUE
MEMCMP_LOOP:
    dec   ARG_REG1
    brmi  MEMCMP_END
    ld    TMP_REG1, Y+
    ld    TMP_REG2, Z+
    cp    TMP_REG1, TMP_REG2
    breq  MEMCMP_LOOP
    inc   RETURN_VALUE ; memory spaces aren't equal

MEMCMP_END:
    pop   ARG_REG1
    pop   ZH
    pop   ZL
    pop   YH
    pop   YL
    ret
/* }}} */
/* MEMCPY {{{
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
/* }}} */
/* ES_MEMCPY {{{
 * Same as MEMCPY, but source from EEPROM */
ES_MEMCPY:
    /* Wait for any previous EEPROM write to finish {{{ */
    sbic  _SFR_IO_ADDR(EECR), EEWE
    rjmp  ES_MEMCPY
    push  ARG_REG1
    /* }}} */
ES_MEMCPY_LOOP:
    dec   ARG_REG1
    brmi  ES_MEMCPY_END
    /* EEPROM read, INC Y {{{ */
    /* Set EEPROM address */
    out   _SFR_IO_ADDR(EEARH), YH
    out   _SFR_IO_ADDR(EEARL), YL
    adiw  YL, 1
    /* Set Read Enable and read */
    sbi   _SFR_IO_ADDR(EECR), EERE
    in    TMP_REG1, _SFR_IO_ADDR(EEDR)
    /* }}} */
    st    Z+, TMP_REG1
    rjmp  ES_MEMCPY_LOOP

ES_MEMCPY_END:
    pop   ARG_REG1
    ret
/* }}} */
.end
