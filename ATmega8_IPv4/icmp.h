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
#ifndef _ICMP_H_
#define _ICMP_H_

/* https://tools.ietf.org/html/rfc792 ------------------------------------------
 *
 * ICMP packet:
 *
 *    0               1               2               3
 *    0 1 2 3 4 5 6 7 0 1 2 3 4 5 6 7 0 1 2 3 4 5 6 7 0 1 2 3 4 5 6 7
 *   +---------------+---------------+-------------------------------+
 * 0 |     Type      |      Code     |          Checksum             |
 *   +---------------+---------------+-------------------------------+
 * 4 |           Identifier          |        Sequence Number        |
 *   +-------------------------------+-------------------------------+
 *
 * ---------------------------------------------------------------------------*/

/* Summary of Message Types --------------------------------------------------*/
#define ICMP_MSG_TYPE_ECHO_REPLY                0
#define ICMP_MSG_TYPE_DESTINATION_UNREACHABLE   3
#define ICMP_MSG_TYPE_SOURCE_QUENCH             4
#define ICMP_MSG_TYPE_REDIRECT                  5
#define ICMP_MSG_TYPE_ECHO                      8
#define ICMP_MSG_TYPE_TIME_EXCEEDED            11
#define ICMP_MSG_TYPE_PARAMETER_PROBLEM        12
#define ICMP_MSG_TYPE_TIMESTAMP                13
#define ICMP_MSG_TYPE_TIMESTAMP_REPLY          14
#define ICMP_MSG_TYPE_INFORMATION_REQUEST      15
#define ICMP_MSG_TYPE_INFORMATION_REPLY        16

#endif
