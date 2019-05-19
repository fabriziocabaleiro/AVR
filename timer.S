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
    sts   TIMER1_SECONDS, TMP_REG1
    sts   TIMER1_MINUTES, TMP_REG1
    sts   TIMER1_HOURS,   TMP_REG1

    ret
/* }}} */

/*******************************************************************************
 *  {{{
 * With a prescaler of 1024 and a OCR1A of 7812, then we will have a match every
 * 8 seconds for a clock of 1Mhz
 ******************************************************************************/
TIMER1_COMPA_vect:
    push  TMP_REG1
    in    TMP_REG1, _SFR_IO_ADDR(SREG)
    push  TMP_REG1

    lds   TMP_REG1, TIMER1_SECONDS
    cpi   TMP_REG1, 59
    breq  INC_MINUTE
    inc   TMP_REG1
    sts   TIMER1_SECONDS, TMP_REG1
    rjmp  TIMER1_COMPA_vect_EXIT

INC_MINUTE:
    clr   TMP_REG1
    sts   TIMER1_SECONDS, TMP_REG1
    lds   TMP_REG1, TIMER1_MINUTES
    cpi   TMP_REG1, 59
    breq  INC_HOUR
    inc   TMP_REG1
    sts   TIMER1_MINUTES, TMP_REG1
    rjmp  TIMER1_COMPA_vect_EXIT
    
INC_HOUR:
    clr   TMP_REG1
    sts   TIMER1_MINUTES, TMP_REG1
    lds   TMP_REG1, TIMER1_HOURS
    inc   TMP_REG1
    cpi   TMP_REG1, 24
    brne  WITHIN_DAY
    clr   TMP_REG1
WITHIN_DAY:
    sts   TIMER1_HOURS, TMP_REG1
    
TIMER1_COMPA_vect_EXIT:
    pop   TMP_REG1
    out   _SFR_IO_ADDR(SREG), TMP_REG1
    pop   TMP_REG1

    reti
/* }}} */
