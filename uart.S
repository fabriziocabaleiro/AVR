/* vim: set filetype=S foldmethod=marker: */
/* INCLUDES {{{1 */
#ifndef NDEBUG
.NOLIST
#include <avr/io.h>
#include "defs.h"
.LIST

/* MACORS {{{1 ---------------------------------------------------------------*/

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
   UBRR = 12 @1MHz => Baud rate 4800, error 0.2%
 */
UART_INIT:
    out   _SFR_IO_ADDR(UBRRH), ZERO_REG
    ldi   TMP_REG1, 12
    out   _SFR_IO_ADDR(UBRRL), TMP_REG1

    /* Enable transmit */
    ldi   TMP_REG1, (1 << TXEN)
    out   _SFR_IO_ADDR(UCSRB), TMP_REG1
    ret

/* xxxxxxxxxxx {{{2  -----------------------------------------------------------
 */
UART_TRANSMIT:
    /* Wait for empty transmit buffer */
0:  sbis  _SFR_IO_ADDR(UCSRA), UDRE
    rjmp  0b
    out   _SFR_IO_ADDR(UDR), ARG_REG1
    ret

/* xxxxxxxxxxx {{{2  -----------------------------------------------------------
 */
UART_TRANSMIT_HEX:
    clr   TMP_REG2
    swap  ARG_REG1

    /* Wait for empty transmit buffer */
0:  sbis  _SFR_IO_ADDR(UCSRA), UDRE
    rjmp  0b
    mov   TMP_REG1, ARG_REG1
    andi  TMP_REG1, 0x0F
    cpi   TMP_REG1, 10
    brsh  1f
    subi  TMP_REG1, -48 /* + '0' */
    rjmp  2f
1:  subi  TMP_REG1, -55 /* + 'A' - 10 */
2:  out   _SFR_IO_ADDR(UDR), TMP_REG1

    sbrc  TMP_REG2, 0
    ret
    sbr   TMP_REG2, 0x01
    swap  ARG_REG1
    rjmp  0b

/* xxxxxxxxxxx {{{2  -----------------------------------------------------------
 * Z points to a string
 */
UART_TRANSMIT_STR:
    push  ARG_REG1
    /* Wait for empty transmit buffer */
0:  sbis  _SFR_IO_ADDR(UCSRA), UDRE
    rjmp  0b
    /* Read next byte, check if end of string, if not, write to UART, else jump
     * to the end */
    lpm   ARG_REG1, Z+
    tst   ARG_REG1
    breq  0f
    out   _SFR_IO_ADDR(UDR), ARG_REG1
    rjmp  0b
0:  pop   ARG_REG1
    ret

.end
#endif
