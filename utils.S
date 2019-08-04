/* vim: set filetype=S foldmethod=marker: */
.NOLIST
#include <avr/io.h>
#include "defs.h"
.LIST

.global MEMCMP
.global MEMCPY

.section .data

.section .text

/* MEMCMP {{{
 * Compare memory space pointed by Y and Z
 * ARG_REG1 is the numbers of bytes to compare
 * RETURN_VALUE => 0 if memory areas are the same */
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
 * Copy from Y to Z the length of ARG_REG1 */
MEMCPY:
    push  YL
    push  YH
    push  ZL
    push  ZH
    push  ARG_REG1
    
    clr   RETURN_VALUE
MEMCPY_LOOP:
    dec   ARG_REG1
    brmi  MEMCPY_END
    ld    TMP_REG1, Y+
    st    Z+, TMP_REG1
    rjmp  MEMCPY_LOOP
    
MEMCPY_END:
    pop   ARG_REG1
    pop   ZH
    pop   ZL
    pop   YH
    pop   YL
    ret
/* }}} */
.end
