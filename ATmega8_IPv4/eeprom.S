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

/* GLOBAL {{{1 ---------------------------------------------------------------*/
.global EEPROM_READ_N_INC
.global EEPROM_WRITE_N_INC

/* DATA  {{{1 ----------------------------------------------------------------*/
.section .data

/* TEXT {{{1 -----------------------------------------------------------------*/
.section .text

/* EEPROM_READ_N_INC {{{2 ------------------------------------------------------
 * Read the byte pointed by x.
 *
 * x: Pointer to EEPROM memory.
 *
 * After routine:
 * x += 1
 * a4: Byte pointed by x.
 * ---------------------------------------------------------------------------*/
EEPROM_READ_N_INC:
    /* Wait for previous write to finish */
0:  sbic  _SFR_IO_ADDR(EECR), EEWE
    rjmp  0b
    /* Set address */
    out   _SFR_IO_ADDR(EEARL), xl
    out   _SFR_IO_ADDR(EEARH), xh
    /* Set Read Enable and read */
    sbi   _SFR_IO_ADDR(EECR), EERE
    in    a4, _SFR_IO_ADDR(EEDR)
    adiw  xl, 1 /* Increment x for continuous EEPROM reading */
    ret

/* EEPROM_WRITE_N_INC {{{2 -----------------------------------------------------
 * Write a1 to the EEPROM memory pointed by z.
 *
 * z: Pointer to EEPROM memory.
 *
 * After routine:
 * z += 1
 * a1: unchanged.
 * ---------------------------------------------------------------------------*/
EEPROM_WRITE_N_INC:
    /* Wait for previous write to finish */
0:  sbic  _SFR_IO_ADDR(EECR), EEWE
    rjmp  0b
    /* Set address */
    out   _SFR_IO_ADDR(EEARL), zl
    out   _SFR_IO_ADDR(EEARH), zh
    /* Set data */
    out    _SFR_IO_ADDR(EEDR), a1
    /* Set master write enable and write enable */
    sbi   _SFR_IO_ADDR(EECR), EEMWE
    sbi   _SFR_IO_ADDR(EECR), EEWE
    adiw  zl, 1 /* Increment z for continuous EEPROM writing */
    ret

.end
