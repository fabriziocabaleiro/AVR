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
    push  ARG_REG1
    push  TMP_REG1
    push  TMP_REG2
    push  ZL
    push  ZH
#endif
.endm

.macro DEBUG_POP
#ifndef NDEBUG
    pop   ZH
    pop   ZL
    pop   TMP_REG2
    pop   TMP_REG1
    pop   ARG_REG1
#endif
.endm

/* Print Char {{{2 -----------------------------------------------------------*/
.macro PRINT_CHAR x
#ifndef NDEBUG
    ldi   ARG_REG1, \x
    rcall UART_TRANSMIT
#endif
.endm

.macro PRINT_CHAR_SAFE x
#ifndef NDEBUG
    push  ARG_REG1
    ldi   ARG_REG1, \x
    rcall UART_TRANSMIT
    pop   ARG_REG1
#endif
.endm

/* Print Register {{{2 -------------------------------------------------------*/
.macro PRINT_REG x
#ifndef NDEBUG
    mov   ARG_REG1, \x
    rcall UART_TRANSMIT_HEX
#endif
.endm

.macro PRINT_REG_SAFE x
#ifndef NDEBUG
    /* UART_TRANSMIT_HEX modifies TMP_REG1 and TMP_REG2 */
    push  ARG_REG1
    push  TMP_REG1
    push  TMP_REG2
    mov   ARG_REG1, \x
    rcall UART_TRANSMIT_HEX
    pop   TMP_REG2
    pop   TMP_REG1
    pop   ARG_REG1
#endif
.endm

/* Print String {{{2 ---------------------------------------------------------*/
.macro PRINT_STR x
#ifndef NDEBUG
    ldi   ZL, lo8(\x)
    ldi   ZH, hi8(\x)
    rcall UART_TRANSMIT_STR
#endif
.endm

.macro PRINT_STR_SAFE x
#ifndef NDEBUG
    push  ZL
    push  ZH
    ldi   ZL, lo8(\x)
    ldi   ZH, hi8(\x)
    rcall UART_TRANSMIT_STR
    pop   ZH
    pop   ZL
#endif
.endm

/* Print new line {{{2 -------------------------------------------------------*/
.macro PRINT_NEWLINE
#ifndef NDEBUG
    ldi   ARG_REG1, '\r'
    rcall UART_TRANSMIT
    ldi   ARG_REG1, '\n'
    rcall UART_TRANSMIT
#endif
.endm

.macro PRINT_NEWLINE_SAFE
#ifndef NDEBUG
    push  ARG_REG1
    ldi   ARG_REG1, '\r'
    rcall UART_TRANSMIT
    ldi   ARG_REG1, '\n'
    rcall UART_TRANSMIT
    pop   ARG_REG1
#endif
.endm
