/* vim: set filetype=S foldmethod=marker: */
/* INCLUDES {{{1 */
.NOLIST
#include <avr/io.h>
#include "defs.h"
#include "timer.h"
#include "macros.S"
.LIST

/* MACORS {{{1 ---------------------------------------------------------------*/
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

#define EVENT_LEN   1

/* GLOBAL {{{1 ---------------------------------------------------------------*/
.global TIMER_INIT
.global TIMER1_COMPA_vect

.global SRAM_TIMER1_SECONDS
.global SRAM_TIMER1_EVENTS

/* DATA  {{{1 ----------------------------------------------------------------*/
.section .data
/* uint32 big endian */
SRAM_TIMER1_SECONDS: .skip TIMER1_SECONDS_LEN
/* SRAM_TIMER1_EVENTS must be right after SRAM_TIMER1_SECONDS, check XXX */
SRAM_TIMER1_EVENTS:  .skip EVENT_LEN

/* TEXT {{{1 -----------------------------------------------------------------*/
.section .text
/* INIT {{{2 -------------------------------------------------------------------
 * With a prescaler of 1024 and a OCR1A of 7812, then we will have a match every
 * 8 seconds for a clock of 1Mhz */
TIMER_INIT:
    /* Set CTC with top OCR1A, prescaler clk_io/1024 */
    in    t1, _SFR_IO_ADDR(TCCR1B)
    sbr   t1, (1 << WGM12)|(1 << CS12)|(1 << CS10)
    out   _SFR_IO_ADDR(TCCR1B), t1

    /* Set OCR1A */
    ldi   t1, hi8(OCR1A_VAL)
    out   _SFR_IO_ADDR(OCR1AH), t1
    ldi   t1, lo8(OCR1A_VAL)
    out   _SFR_IO_ADDR(OCR1AL), t1

    /* Enable interrupt */
    in    t1, _SFR_IO_ADDR(TIMSK)
    sbr   t1, (1 << OCIE1A)
    out   _SFR_IO_ADDR(TIMSK), t1

    ldi   ZL, lo8(SRAM_TIMER1_SECONDS)
    ldi   ZH, hi8(SRAM_TIMER1_SECONDS)
    ldi   x1, (TIMER1_SECONDS_LEN + EVENT_LEN)
    rcall BZERO

    ret

/* TIMER1_COMPA_vect {{{2 ------------------------------------------------------
 * With a prescaler of 1024 and a OCR1A of OCR1A_VAL, we will have a match every
 * second. */
TIMER1_COMPA_vect:
    push  t1
    in    t1, _SFR_IO_ADDR(SREG)
    push  t1
    push  t2
    push  YL
    push  YH

    /* Increment seconds uint32 Big endian */
    ldi   YL, lo8(SRAM_TIMER1_SECONDS + TIMER1_SECONDS_LEN)
    ldi   YH, hi8(SRAM_TIMER1_SECONDS + TIMER1_SECONDS_LEN)
    ldi   t2, TIMER1_SECONDS_LEN
0:  ld    t1, -Y
    inc   t1
    st    Y, t1
    brne  0f
    dec   t2
    brne  0b
0:

    /* XXX: ldd instead of "lds t1, SRAM_TIMER1_EVENTS" for smaller footprint */
    ldi   YL, lo8(SRAM_TIMER1_SECONDS)
    ldi   YH, hi8(SRAM_TIMER1_SECONDS)
    ldd   t1, Y + TIMER1_SECONDS_LEN

    ldd   t2, Y + (TIMER1_SECONDS_LEN - 1) /* Load last byte from uint32 */
    sbrs  t2, 0
    sbr   t1, (1 << TIMER1_EVENTS_2S)

    sbr   t1, (1 << TIMER1_EVENTS_SECOND)
    std   Y + (TIMER1_SECONDS_LEN), t1

    DEBUG(rcall PRINT_CURRENT_TIME)

    pop   YH
    pop   YL
    pop   t2
    pop   t1
    out   _SFR_IO_ADDR(SREG), t1
    pop   t1

    reti

#ifndef NDEBUG
PRINT_CURRENT_TIME:
    ldi   t1, 4
    PRINT_STR_SAFE STR_TIMER_CURRENT_TIME
0:  ld    t2, Y+
    PRINT_REG_SAFE t2
    dec   t1
    brne  0b
    PRINT_NEWLINE_SAFE
    ret
#endif
.end
