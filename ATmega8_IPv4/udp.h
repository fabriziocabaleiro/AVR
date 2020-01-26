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
#ifndef _UDP_H_
#define _UDP_H_

#include "services.h"

/*
    0               1               2               3
    1 2 3 4 5 6 7 8 1 2 3 4 5 6 7 8 1 2 3 4 5 6 7 8 1 2 3 4 5 6 7 8
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 0 |          SOURCE PORT          |       DESTINATION PORT        |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 4 |            LENGTH             |       CHECKSUM (OPT)          |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
*/

#define UDP_HEADER_SRC_PORT 0
#define UDP_HEADER_DST_PORT 2
#define UDP_HEADER_LENGTH   4
#define UDP_HEADER_CHK_SUM  6

#define UDP_HEADER_LEN      8

#endif
