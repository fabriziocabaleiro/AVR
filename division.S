/* vim: set filetype=S foldmethod=marker: */
/* INCLUDES {{{1 */
.NOLIST
#include <avr/io.h>
#include <avr/interrupt.h>
#include "defs.h"
#include "enc28j60.h"
.LIST

/* GLOBAL {{{1 ---------------------------------------------------------------*/
.global DIV_RIGHT_SHIFT

/* TEXT {{{1 -----------------------------------------------------------------*/
.section .text
/* Divide by right shift {{{2
 * Y points to src data
 * Z points to dst data
 * ARG_REG1 number of right shift, i.e. ARG_REG1 = 1 means division by 2
 * ARG_REG2 number of bytes in the division
 */
DIV_RIGHT_SHIFT:
    push  YL
    push  YH
    push  COUNTER_REG
    clc /* Clear carry for first ror */
    mov   TMP_REG2, ARG_REG1
DIV_SHIFTS_LOOP:
    mov   COUNTER_REG, ARG_REG2
DIV_BYTES_LOOP:
    ld    TMP_REG1, Y+
    ror   TMP_REG1
    st    Z+, TMP_REG1
    dec   COUNTER_REG
    brne  DIV_BYTES_LOOP
    /* Set pointer back to origin and use dst address as src */
    sub   ZL, ARG_REG2
    sbci  ZH, 0
    mov   YL, ZL
    mov   YH, ZH
    dec   TMP_REG2
    brne  DIV_SHIFTS_LOOP
    pop   COUNTER_REG
    pop   YH
    pop   YL

    ret

.end
