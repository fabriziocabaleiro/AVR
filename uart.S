/* vim: set filetype=S foldmethod=marker: */
/* INCLUDES {{{1 */
#ifndef NDEBUG
.NOLIST
#include <avr/io.h>
#include "defs.h"
.LIST

/* MACORS {{{1 ---------------------------------------------------------------*/
#ifndef F_CPU
#   error "CPU frequency not specified, cannot calculate UBRRH:UBRRL"
#endif

/* Values originally obtained from Atmega8 datasheet section "Examples of Baud
 * Rate Setting", but for 4M and 8M they didn't work, so adjusted by try and
 * error */
#if   F_CPU == 1000000
#   define  UBRRL_VAL           12
#elif F_CPU == 2000000
#   define  UBRRL_VAL           25
#elif F_CPU == 4000000
#   define  UBRRL_VAL           54
#elif F_CPU == 8000000
#   define  UBRRL_VAL          110
#else
#   error "Unsupported F_CPU value"
#endif

/* GLOBAL {{{1 ---------------------------------------------------------------*/
.global UART_INIT
.global UART_TRANSMIT
.global UART_TRANSMIT_HEX
.global UART_TRANSMIT_STR

/* DATA  {{{1 ----------------------------------------------------------------*/
.section .data

/* TEXT {{{1 -----------------------------------------------------------------*/
.section .text

/* UART_INIT {{{2 --------------------------------------------------------------
 * Initialize UART.
 * Asynchronous normal mode.
 * UBRR => Baud rate 4800, error 0.2%
 * ---------------------------------------------------------------------------*/
UART_INIT:
    out   _SFR_IO_ADDR(UBRRH), zero
    ldi   t1, UBRRL_VAL
    out   _SFR_IO_ADDR(UBRRL), t1

    /* Enable transmit */
    ldi   t1, (1 << TXEN)
    out   _SFR_IO_ADDR(UCSRB), t1
    ret

/* UART_TRANSMIT {{{2 ----------------------------------------------------------
 * Transmit a1 through UART.
 *
 * a1: Byte to be transmitted
 *
 * After routine:
 * a1: unchanged.
 * ---------------------------------------------------------------------------*/
UART_TRANSMIT:
    /* Wait for empty transmit buffer */
0:  sbis  _SFR_IO_ADDR(UCSRA), UDRE
    rjmp  0b
    out   _SFR_IO_ADDR(UDR), a1
    ret

/* UART_TRANSMIT_HEX {{{2 ------------------------------------------------------
 * Transmit register as hexadecimal through UART.
 *
 * a1: Byte to transmit as hexadecimal.
 *
 * After routine:
 * a1: unchanged.
 * ---------------------------------------------------------------------------*/
UART_TRANSMIT_HEX:
    clr   t2
    swap  a1

    /* Wait for empty transmit buffer */
0:  sbis  _SFR_IO_ADDR(UCSRA), UDRE
    rjmp  0b
    mov   t1, a1
    andi  t1, 0x0F
    cpi   t1, 10
    brsh  1f
    subi  t1, -48 /* + '0' */
    rjmp  2f
1:  subi  t1, -55 /* + 'A' - 10 */
2:  out   _SFR_IO_ADDR(UDR), t1

    sbrc  t2, 0
    ret
    sbr   t2, 0x01
    swap  a1
    rjmp  0b

/* UART_TRANSMIT_STR {{{2 ------------------------------------------------------
 * Transmit string through UART.
 *
 * z: Pointer to string in FLASH.
 *
 * After routine:
 * z: undefined.
 *
 * Note: Only z can be used with lpm.
 * ---------------------------------------------------------------------------*/
UART_TRANSMIT_STR:
    /* Wait for empty transmit buffer */
0:  sbis  _SFR_IO_ADDR(UCSRA), UDRE
    rjmp  0b
    /* Read next byte, check if end of string, if not, write to UART, else jump
     * to the end */
    lpm   a1, z+
    tst   a1
    breq  0f
    out   _SFR_IO_ADDR(UDR), a1
    rjmp  0b
0:  ret

.end
#endif
