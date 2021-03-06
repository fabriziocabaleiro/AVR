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
#include <avr/io.h>
#include "defs.h"
#include "eeprom_data.h"
.LIST

/* MACROS {{{1 ---------------------------------------------------------------*/
#define ASCII_ZERO 48

/* GLOBAL {{{1 ---------------------------------------------------------------*/
.global HTTP_HANDLE_PKT

/* DATA  {{{1 ----------------------------------------------------------------*/
.section .data

/* TEXT {{{1 -----------------------------------------------------------------*/
.section .text

/* HTTP_HANDLE_PKT {{{2 --------------------------------------------------------
 * Handle HTTP packet.
 *
 * z: Pointer to TCP payload (SRAM_TCP_PAYLOAD).
 *
 * After routine:
 * a4: output HTTP length in bytes
 * z: undefined.
 * ---------------------------------------------------------------------------*/
HTTP_HANDLE_PKT:
    ldi   xl, lo8(EEPROM_HTTP_RESPONSE)
    ldi   xh, hi8(EEPROM_HTTP_RESPONSE)
    ldi   a1, (EEPROM_HTTP_RESPONSE_END - EEPROM_HTTP_RESPONSE)
    rcall MEMCPY_EEPROM_SRAM
    /* Set back z to beginning of HTTP payload */
    sbiw  zl, (EEPROM_HTTP_RESPONSE_END - EEPROM_HTTP_RH_OFFSET)

    /* RH */
    ldi   xl, lo8(SRAM_DHT11_PAYLOAD)
    ldi   xh, hi8(SRAM_DHT11_PAYLOAD)

    rcall FILL_8_DOT_8_VALUE

    /* Temperature */
    adiw  zl, 4
    rcall FILL_8_DOT_8_VALUE

    /* Set return value to payload size */
    ldi   a4, (EEPROM_HTTP_RESPONSE_END - EEPROM_HTTP_RESPONSE)

    ret

/* FILL_8_DOT_8_VALUE {{{2 -----------------------------------------------------
 * Fill 8.8 value into xx.x placeholder on HTTP body.
 *
 * x: Pointer to 8.8 input value.
 * z: Pointer to xx.x placeholder.
 *
 * After routine:
 * x += 2
 * z += 4
 * ---------------------------------------------------------------------------*/
FILL_8_DOT_8_VALUE:
    /* RH */
    ld    a1, x+
    ldi   a2, 10
    rcall SDIV
    subi  a4, -ASCII_ZERO /* + '0' */
    subi  a3, -ASCII_ZERO /* + '0' */
    st    z+, a4
    st    z+, a3

    /* Skip the dot xx.x */
    adiw  zl, 1

    /* Decimal part from DHT11 ranges from 0 to 9, so just add '0' */
    ld    a1, x+
    subi  a1, -ASCII_ZERO /* + '0' */
    st    z+, a1

    ret

.end
