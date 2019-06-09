/* vim: set filetype=S foldmethod=marker: */
.NOLIST
#include <avr/io.h>
#include "defs.h"
.LIST

.global TIMER_INIT
.global TIMER1_COMPA_vect

#ifndef F_CPU
#   error "CPU frequency not specified, cannot calculate timer parameters"
#endif

#if   F_CPU == 1000000
#   define  OCR1A_VAL           976
#elif F_CPU == 2000000
#   define  OCR1A_VAL          1953
#elif F_CPU == 4000000
#   define  OCR1A_VAL          3906
#elif F_CPU == 8000000
#   define  OCR1A_VAL          7812
#else
#   error "Unsupported F_CPU value"
#endif
/*******************************************************************************
 *  {{{
 * With a prescaler of 1024 and a OCR1A of 7812, then we will have a match every
 * 8 seconds for a clock of 1Mhz
 ******************************************************************************/
TIMER_INIT:
    /* Set CTC with top OCR1A, prescaler clk_io/1024 */
    in    TMP_REG1, _SFR_IO_ADDR(TCCR1B)
    sbr   TMP_REG1, (1 << WGM12)|(1 << CS12)|(1 << CS10)
    out   _SFR_IO_ADDR(TCCR1B), TMP_REG1

    /* Set OCR1A */
    ldi   TMP_REG1, hi8(OCR1A_VAL)
    out   _SFR_IO_ADDR(OCR1AH), TMP_REG1
    ldi   TMP_REG1, lo8(OCR1A_VAL)
    out   _SFR_IO_ADDR(OCR1AL), TMP_REG1

    /* Enable interrupt */
    in    TMP_REG1, _SFR_IO_ADDR(TIMSK)
    sbr   TMP_REG1, (1 << OCIE1A)
    out   _SFR_IO_ADDR(TIMSK), TMP_REG1

    clr   TMP_REG1
    sts   TIMER1_SECONDS + 0, TMP_REG1
    sts   TIMER1_SECONDS + 1, TMP_REG1
    sts   TIMER1_SECONDS + 2, TMP_REG1
    sts   TIMER1_SECONDS + 3, TMP_REG1

    ret
/* }}} */
/*******************************************************************************
 * TIMER1_COMPA_vect {{{
 * With a prescaler of 1024 and a OCR1A of 7812, then we will have a match every
 * 8 seconds for a clock of 1Mhz
 ******************************************************************************/
TIMER1_COMPA_vect:
    push  TMP_REG1
    in    TMP_REG1, _SFR_IO_ADDR(SREG)
    push  TMP_REG1
    push  TMP_REG2
    push  YL
    push  YH

    ldi   YL, lo8(TIMER1_SECONDS)
    ldi   YH, hi8(TIMER1_SECONDS)
    ldi   TMP_REG2, TIMER1_SECONDS_LEN
INC_SECONDS:
    ld    TMP_REG1, Y+
    inc   TMP_REG1
    sts   TIMER1_SECONDS, TMP_REG1
    brne  TIMER1_SET_EVENTS
    /* if overflow, then increment next byte */
    dec   TMP_REG2
    breq  TIMER1_SET_EVENTS
    rjmp  INC_SECONDS

TIMER1_SET_EVENTS:

    lds   TMP_REG1, TIMER1_EVENTS
    sbr   TMP_REG1, (1 << TIMER1_EVENTS_SECOND)
    sts   TIMER1_EVENTS, TMP_REG1

    pop   YH
    pop   YL
    pop   TMP_REG2
    pop   TMP_REG1
    out   _SFR_IO_ADDR(SREG), TMP_REG1
    pop   TMP_REG1

    reti
/* }}} */
