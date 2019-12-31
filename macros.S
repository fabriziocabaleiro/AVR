/* vim: set filetype=S foldmethod=marker: */
/* INCLUDES {{{1 */
.NOLIST
#ifndef __AVR_ATmega8__
#   define __AVR_ATmega8__
#endif
#include <avr/io.h>
#include <avr/interrupt.h>
#include "defs.h"
#include "enc28j60.h"
#include "timer.h"
#include "eeprom_data.h"
#include "dht11.h"
.LIST

/* Push and Pop {{{2 ---------------------------------------------------------*/
.macro DEBUG_PUSH
#ifndef NDEBUG
    push  a1
    push  t1
    push  t2
    push  t3
    push  xl
    push  xh
    push  yl
    push  yh
    push  zl
    push  zh
#endif
.endm

.macro DEBUG_POP
#ifndef NDEBUG
    pop   zh
    pop   zl
    pop   yh
    pop   yl
    pop   xh
    pop   xl
    pop   t3
    pop   t2
    pop   t1
    pop   a1
#endif
.endm

/* Print Char {{{2 -----------------------------------------------------------*/
.macro PRINT_CHAR x
#ifndef NDEBUG
    ldi   a1, \x
    rcall UART_TRANSMIT
#endif
.endm

.macro PRINT_CHAR_SAFE x
#ifndef NDEBUG
    push  a1
    ldi   a1, \x
    rcall UART_TRANSMIT
    pop   a1
#endif
.endm

/* Print Register {{{2 -------------------------------------------------------*/
.macro PRINT_REG x
#ifndef NDEBUG
    mov   a1, \x
    rcall UART_TRANSMIT_HEX
#endif
.endm

.macro PRINT_REG_SAFE x
#ifndef NDEBUG
    /* UART_TRANSMIT_HEX modifies t1 and t2 */
    push  a1
    push  t1
    push  t2
    mov   a1, \x
    rcall UART_TRANSMIT_HEX
    pop   t2
    pop   t1
    pop   a1
#endif
.endm

/* Print String {{{2 ---------------------------------------------------------*/
.macro PRINT_STR x
#ifndef NDEBUG
    ldi   zl, lo8(\x)
    ldi   zh, hi8(\x)
    rcall UART_TRANSMIT_STR
#endif
.endm

.macro PRINT_STR_SAFE x
#ifndef NDEBUG
    push  zl
    push  zh
    ldi   zl, lo8(\x)
    ldi   zh, hi8(\x)
    rcall UART_TRANSMIT_STR
    pop   zh
    pop   zl
#endif
.endm

/* Print new line {{{2 -------------------------------------------------------*/
.macro PRINT_NEWLINE
#ifndef NDEBUG
    ldi   a1, '\r'
    rcall UART_TRANSMIT
    ldi   a1, '\n'
    rcall UART_TRANSMIT
#endif
.endm

.macro PRINT_NEWLINE_SAFE
#ifndef NDEBUG
    push  a1
    ldi   a1, '\r'
    rcall UART_TRANSMIT
    ldi   a1, '\n'
    rcall UART_TRANSMIT
    pop   a1
#endif
.endm
