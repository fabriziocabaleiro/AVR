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

/* Initialize USART {{{2  ------------------------------------------------------
   Asynchronous normal mode
   UBRR => Baud rate 4800, error 0.2%
 */
UART_INIT:
    out   _SFR_IO_ADDR(UBRRH), zero
    ldi   t1, UBRRL_VAL
    out   _SFR_IO_ADDR(UBRRL), t1

    /* Enable transmit */
    ldi   t1, (1 << TXEN)
    out   _SFR_IO_ADDR(UCSRB), t1
    ret

/* Uart Transmit {{{2 ----------------------------------------------------------
 * x1 Byte to be transmitted
 */
UART_TRANSMIT:
    /* Wait for empty transmit buffer */
0:  sbis  _SFR_IO_ADDR(UCSRA), UDRE
    rjmp  0b
    out   _SFR_IO_ADDR(UDR), x1
    ret

/* Uart Transmit register as hexadecimal {{{2 ----------------------------------
 */
UART_TRANSMIT_HEX:
    clr   t2
    swap  x1

    /* Wait for empty transmit buffer */
0:  sbis  _SFR_IO_ADDR(UCSRA), UDRE
    rjmp  0b
    mov   t1, x1
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
    swap  x1
    rjmp  0b

/* Uart Transmit string {{{2  --------------------------------------------------
 * Z points to a string
 */
UART_TRANSMIT_STR:
    push  x1
    /* Wait for empty transmit buffer */
0:  sbis  _SFR_IO_ADDR(UCSRA), UDRE
    rjmp  0b
    /* Read next byte, check if end of string, if not, write to UART, else jump
     * to the end */
    lpm   x1, Z+
    tst   x1
    breq  0f
    out   _SFR_IO_ADDR(UDR), x1
    rjmp  0b
0:  pop   x1
    ret

.end
#endif
