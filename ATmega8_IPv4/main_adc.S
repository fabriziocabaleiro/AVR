/* LICENSE {{{ -----------------------------------------------------------------
 * IPv4 stack for AVR (ATmega8) microcontroller.
 * Copyright (C) 2020 Fabrizio Cabaleiro
 * 
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, version 2.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 * 
 * You should have received a copy of the GNU General Public License along with
 * this program. If not, see <https://www.gnu.org/licenses/>.
 * ------------------------------------------------------------------------}}}*/
/* INCLUDES {{{1 -------------------------------------------------------------*/
.NOLIST
#ifndef __AVR_ATmega8__
#   define __AVR_ATmega8__
#endif
#include <avr/io.h>
#include <avr/interrupt.h>
#include "macros.S"
.LIST

/* GLOBAL {{{1 ---------------------------------------------------------------*/
.global main

/* DATA  {{{1 ----------------------------------------------------------------*/
.section .data

/* TEXT {{{1 -----------------------------------------------------------------*/
.section .text

/* main {{{2 -------------------------------------------------------------------
 * Initialize everything.
 * ---------------------------------------------------------------------------*/
main:
    /* Keep register with zero value to avoid using clr over and over */
    clr   zero

    /* Set global interrupt enable, sleep mode and sleep enable
     * Interrupt on INT0: falling edge */
    in    t1, _SFR_IO_ADDR(MCUCR)
    sbr   t1, ((1 << SE)|(1 << ISC01))
    out   _SFR_IO_ADDR(MCUCR), t1

    rcall TIMER_INIT
    DEBUG(rcall UART_INIT)

    DEBUG(PRINT_STR STR_START)
    sei


/* LOOP {{{2 -------------------------------------------------------------------
 * Main loop.
 * ---------------------------------------------------------------------------*/
LOOP:
    sleep
    lds   t1, SRAM_TIMER1_EVENTS
    sbrs  t1, TIMER1_EVENTS_SECOND
    rjmp  LOOP
    cbr   t1, (1 << TIMER1_EVENTS_SECOND)
    sts   SRAM_TIMER1_EVENTS, t1

#ifndef NDEBUG
    lds   t1, SRAM_ADC0 + 0
    PRINT_REG t1
    lds   t1, SRAM_ADC0 + 1
    PRINT_REG t1
    PRINT_NEWLINE
#endif

    rcall ADC_ENABLE_N_START
    rjmp  LOOP
