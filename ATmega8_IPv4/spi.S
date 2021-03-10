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
#include "spi.h"
.LIST

/* MACROS {{{1 ---------------------------------------------------------------*/

/* GLOBAL {{{1 ---------------------------------------------------------------*/
.global SPI_MASTER_INIT
.global SPI_MASTER_TRANSMIT

/* TEXT {{{1 -----------------------------------------------------------------*/
.section .text

/* SPI_MASTER_INIT {{{2 --------------------------------------------------------
 * Initialize SPI.
 *
 * Set SS, so slave is not listening.
 * Set pins as output:
 * - MOSI
 * - SCK
 * - SS (This must be handle by user code)
 * Set bits on register:
 * - SPE:   Enable SPI.
 * - MSTR:  Set as master.
 * - SPR0:  SCK to F_osc/16. If set to higher speed, then I get ping responding
 *   with duplicated packets, maybe due to hardware.
 *
 * With better hardware we could also set
 * - SPI2X: Double SPI speed.
 * ---------------------------------------------------------------------------*/
SPI_MASTER_INIT:
    SPI_END_ETH
    ldi t2, ((1 << SPI_MOSI_BIT) | \
             (1 << SPI_SCK_BIT)  | \
             (1 << SPI_SS_ETH))
    out _SFR_IO_ADDR(SPI_MOSI_DDR), t2
    ldi t2, (1 << SPE)|(1 << MSTR)|(1 << SPR0)
    out _SFR_IO_ADDR(SPCR), t2
    /* sbis  _SFR_IO_ADDR(SPSR), SPI2X */
    ret

/* SPI_MASTER_TRANSMIT {{{2 ----------------------------------------------------
 * Transmit a1.
 *
 * Caller needs to clear SS before calling this routine, also need to set SS
 * after transmitting all bytes.
 *
 * a1: Byte to transmit.
 *
 * After routine:
 * a4: Byte transmitted by slave.
 ******************************************************************************/
SPI_MASTER_TRANSMIT:
    /* Start transmission of data on (a1) */
    out   _SFR_IO_ADDR(SPDR), a1
    /* Wait for transmission complete */
0:  sbis  _SFR_IO_ADDR(SPSR), SPIF
    rjmp  0b
    /* Get received message */
    in    a4, _SFR_IO_ADDR(SPDR)
    ret

.end
