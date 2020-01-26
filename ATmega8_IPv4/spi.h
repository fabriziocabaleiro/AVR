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
#ifndef _SPI_H_
#define _SPI_H_

/*------+------+------+----------------+
| SPI2X | SPR1 | SPR0 |  SCK Frequency |
+-------+------+------+----------------+
|   0   |   0  |   0  |  f osc / 4     |
|   0   |   0  |   1  |  f osc / 16    |
|   0   |   1  |   0  |  f osc / 64    |
|   0   |   1  |   1  |  f osc / 128   |
|   1   |   0  |   0  |  f osc / 2     |
|   1   |   0  |   1  |  f osc / 8     |
|   1   |   1  |   0  |  f osc / 32    |
|   1   |   1  |   1  |  f osc / 64    |
+-------+------+------+---------------*/

#define SPI_SS_DDR    DDRB
#define SPI_MOSI_BIT  PB3
#define SPI_MOSI_DDR  DDRB
#define SPI_MISO_BIT  PB4
#define SPI_MISO_DDR  DDRB
#define SPI_SCK_BIT   PB5
#define SPI_SCK_DDR   DDRB

#endif
