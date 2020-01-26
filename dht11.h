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
#ifndef _DHT11_H_
#define _DHT11_H_
#define DHT11_PAYLOAD_LEN  5 /* 40 Bits */

/* Payload offsets */
#define DHT11_DATA_RH_INT  0 /* Relative humidity integer part */
#define DHT11_DATA_RH_FRAC 1 /* Relative humidity fractional part */
#define DHT11_DATA_T_INT   2 /* Temperature integer part */
#define DHT11_DATA_T_FRAC  3 /* Temperature fractional part */
#define DHT11_DATA_CHKSUM  4 /* Checksum */
#endif
