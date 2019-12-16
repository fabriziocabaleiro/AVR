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
 * x1 number of right shift, i.e. x1 = 1 means division by 2
 * x2 number of bytes in the division
 */
/* TODO: remove file */
DIV_RIGHT_SHIFT:
    push  YL
    push  YH
    push  t3
    clc /* Clear carry for first ror */
    mov   t2, x1
DIV_SHIFTS_LOOP:
    mov   t3, x2
DIV_BYTES_LOOP:
    ld    t1, Y+
    ror   t1
    st    Z+, t1
    dec   t3
    brne  DIV_BYTES_LOOP
    /* Set pointer back to origin and use dst address as src */
    sub   ZL, x2
    sbci  ZH, 0
    mov   YL, ZL
    mov   YH, ZH
    dec   t2
    brne  DIV_SHIFTS_LOOP
    pop   t3
    pop   YH
    pop   YL

    ret

.end
