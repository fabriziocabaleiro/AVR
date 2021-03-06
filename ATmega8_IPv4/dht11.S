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
#ifndef NDEBUG
#define NDEBUG
#endif
.NOLIST
#include <avr/io.h>
#include "dht11.h"
#include "defs.h"
#include "macros.S"
.LIST

/* MACROS {{{1 ---------------------------------------------------------------*/
/* Tested At 1MHz */

/* Start at 5 because we are going to trigger 3 times the interrupt before data
 * is coming, which are:
 * 1. MCU start signal
 * 2. DHT 80us response
 * 3. Start transmission
 *
 * By starting at 4, the last 3 bits are zero every time we need to increment
 * the pointer, we can check that by a simple AND */
#define DHT11_RESPONSE_INIT                  5
#define DHT11_RESPONSE_DATA_COMING           9

#ifndef F_CPU
#   error "CPU frequency not specified, cannot calculate timer parameters"
#endif

#if   F_CPU == 1000000
#   define  WAIT_20uS          20
#   define  INTERVAL_THRESHOLD 12
#   define  T2_PRESCALER       (1 << CS21) /* clk/8 */
#elif F_CPU == 2000000
#   define  WAIT_20uS          40
#   define  INTERVAL_THRESHOLD 24
#   define  T2_PRESCALER       (1 << CS21)
#elif F_CPU == 4000000
#   define  WAIT_20uS          80
#   define  INTERVAL_THRESHOLD 12
#   define  T2_PRESCALER       (1 << CS21)|(1 << CS20) /* clk/32 */
#elif F_CPU == 8000000
#   define  WAIT_20uS          160
#   define  INTERVAL_THRESHOLD 24
#   define  T2_PRESCALER       (1 << CS21)|(1 << CS20)
#else
#   error "Unsupported F_CPU value"
#endif

/* GLOBAL {{{1 ---------------------------------------------------------------*/
.global DHT11_INIT
.global DHT11_READ
.global INT1_vect
.global TIMER2_OVF_vect

.global SRAM_DHT11_PAYLOAD

/* DATA  {{{1 ----------------------------------------------------------------*/
.section .data
SRAM_DHT11_PAYLOAD: .skip DHT11_PAYLOAD_LEN

/* TEXT {{{1 -----------------------------------------------------------------*/
.section .text

/* DHT11_INIT {{{2 -------------------------------------------------------------
 * Setup interrupt in falling edge.
 * Setup interrupt port as Input with value Zero.
 * ---------------------------------------------------------------------------*/
DHT11_INIT:
    /* Disable interrupt */
    in    t1, _SFR_IO_ADDR(TIMSK)
    cbr   t1, (1 << TOIE2)
    out   _SFR_IO_ADDR(TIMSK), t1

    /* Set INT1 on falling edge */
    in    t1, _SFR_IO_ADDR(MCUCR)
    sbr   t1, (1 << ISC11)
    out   _SFR_IO_ADDR(MCUCR), t1

    /* Set Interrupt in INT1 */
    in    t1, _SFR_IO_ADDR(GICR)
    sbr   t1, (1 << INT1)
    out   _SFR_IO_ADDR(GICR), t1

    /* Set INT1 */
    /* This line must be hold high while the DHT11 is not in used. */
    cbi   _SFR_IO_ADDR(DDRD), PD3
    /* PORTD(3) is going to be zero, when we change DDRD(3) to output, then, it
     * will pull down the line, when changed back to input, it will be high
     * impedance */
    cbi   _SFR_IO_ADDR(PORTD), PD3
    ret

/* DHT11_READ {{{2 -------------------------------------------------------------
 * Read data from sensor.
 *
 * Data is store in SRAM_DHT11_PAYLOAD.
 *
 * Interrupt are used with falling edge.
 *
 * t3 used to count falling edge on interrupt pin, so we know when data
 *   start arriving and when a whole byte has been transmitted.
 *
 * BEWARE: Idle is the only sleep mode that support edge interrupts
 * BEWARE: Calling this routine at 1Hz causes issues, DHT11 sensor should not be
 * read more than once per second */
DHT11_READ:
    /* Setup initial Step, used when receiving stream of data */
    ldi   t3, DHT11_RESPONSE_INIT

    /* Set clock prescaler to 1024, to we can have ms easily */
    in    t2, _SFR_IO_ADDR(TCCR2)
    sbr   t2, (1 << CS22)|(1 << CS21)|(1 << CS20)
    out   _SFR_IO_ADDR(TCCR2), t2

    /* Start communication by pulling down */
    sbi   _SFR_IO_ADDR(DDRD),  PD3

    /* Clear the counter */
    out   _SFR_IO_ADDR(TCNT2), zero
    /* Pulling Down data line for at least 18ms */
0:  in    zl, _SFR_IO_ADDR(TCNT2)
    cpi   zl, WAIT_20uS
    brlo  0b

    /* Set clock prescaler to 8, which gives good precision to differentiate
     * between a ZERO or ONE sent by the DHT11 */
    in    t2, _SFR_IO_ADDR(TCCR2)
    cbr   t2, (1 << CS22)|(1 << CS21)|(1 << CS20)
    sbr   t2, T2_PRESCALER
    out   _SFR_IO_ADDR(TCCR2), t2

    /* Clear Timer 2 Overflow flag */
    in    t2, _SFR_IO_ADDR(TIFR)
    sbr   t2, (1 << TOV2)
    out   _SFR_IO_ADDR(TIFR), t2

    /* Set timer overflow interrupt enable */
    in    t2, _SFR_IO_ADDR(TIMSK)
    sbr   t2, (1 << TOIE2)
    out   _SFR_IO_ADDR(TIMSK), t2

    /* Set z to point to DHT11 payload */
    ldi   zh, hi8(SRAM_DHT11_PAYLOAD)
    ldi   zl, lo8(SRAM_DHT11_PAYLOAD)

    /* Now the DHT11 will take control of the data line, enable signal and wait
     * to change down */
    /* Set port as input, then with the pull-up, the line will go high */
    cbi   _SFR_IO_ADDR(DDRD), PD3

    /* 40 cycles, one for each bit, plus 2 falling edges at the beginning */
    ldi   t1, 42
0:  sleep
    dec   t1
    brne  0b

    /* Unset timer overflow interrupt enable */
    in    t2, _SFR_IO_ADDR(TIMSK)
    cbr   t2, (1 << TOIE2)
    out   _SFR_IO_ADDR(TIMSK), t2

    DEBUG(rcall PRINT_VARIABLES)

    ret

/* TIMER2_OVF_vect INT1_vect {{{2 ----------------------------------------------
 * Handle INT1/TIMER2_OVF interrupt.
 *
 * Get and process data in every falling edge.
 *
 * z: Pointer to DHT11 payload.
 *
 * After routine:
 * z += DHT11_PAYLOAD_LEN
 * ---------------------------------------------------------------------------*/
TIMER2_OVF_vect:
INT1_vect:
    /* Read counter and reset it */
    in    a3, _SFR_IO_ADDR(TCNT2) /* Using a3 as temporary reg */
    out   _SFR_IO_ADDR(TCNT2), zero

    inc   t3
    cpi   t3, DHT11_RESPONSE_DATA_COMING
    /* Return right away for the two falling edges before data transmission */
    brmi  1f

    /* Load data from SRAM, shift left, decode incoming data, set LSB in case of
     * a one, save data back to SRAM */
    ld    t2, z
    lsl   t2
    cpi   a3, INTERVAL_THRESHOLD
    brlo  0f
    sbr   t2, 0x01
0:  st    z, t2

    /* Increment z if we finished writing a byte */
    mov   t2, t3
    andi  t2, 0x07
    brne  1f
    adiw  zl, 1

1:  reti

#ifndef NDEBUG
PRINT_VARIABLES:
    DEBUG_PUSH
    PRINT_STR STR_DHT11_DATA
    ldi   xl, lo8(SRAM_DHT11_PAYLOAD)
    ldi   xh, hi8(SRAM_DHT11_PAYLOAD)
    ld    a1, x+
    rcall UART_TRANSMIT_HEX
    ld    a1, x
    rcall UART_TRANSMIT_HEX
    PRINT_NEWLINE
    DEBUG_POP
    ret
#endif

.end
