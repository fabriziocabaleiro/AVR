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
#ifndef _ARP_H_
#define _ARP_H_

/* ARP packet {{{1
 *******************************************************************************
         Internet Protocol (IPv4) over Ethernet ARP packet
   +-----------------------------------------------------------------+
   |          First byte            |          Second byte           |
   +-----------------------------------------------------------------+
0  |                   Hardware type (HTYPE)                         |
   +-----------------------------------------------------------------+
2  |                   Protocol type (PTYPE)                         |
   +--------------------------------+--------------------------------+
4  | Hardware address length (HLEN) | Protocol address length (PLEN) |
   +--------------------------------+--------------------------------+
6  |                       Operation (OPER)                          |
   +-----------------------------------------------------------------+
8  |         Sender hardware address (SHA) (first 2 bytes)           |
   +-----------------------------------------------------------------+
10 |                       (next 2 bytes)                            |
   +-----------------------------------------------------------------+
12 |                       (last 2 bytes)                            |
   +-----------------------------------------------------------------+
14 |         Sender protocol address (SPA) (first 2 bytes)           |
   +-----------------------------------------------------------------+
16 |                       (last 2 bytes)                            |
   +-----------------------------------------------------------------+
18 |         Target hardware address (THA) (first 2 bytes)           |
   +-----------------------------------------------------------------+
20 |                        (next 2 bytes)                           |
   +-----------------------------------------------------------------+
22 |                        (last 2 bytes)                           |
   +-----------------------------------------------------------------+
24 |          Target protocol address (TPA) (first 2 bytes)          |
   +-----------------------------------------------------------------+
26 |                       (last 2 bytes)                            |
   +-----------------------------------------------------------------+
*/

/* ARP packet structure {{{1 -------------------------------------------------*/
#define ARP_HTYPE          0
#define ARP_PTYPE          2
#define ARP_HLEN           4
#define ARP_PLEN           5
/* Operation, 1 request, 2 reply */
#define ARP_OPER           6
/* Sender MAC addr */
#define ARP_SHA            8
/* Sender IP addr */
#define ARP_SPA           14
/* Receiver MAC addr */
#define ARP_THA           18
/* Receiver IP addr */
#define ARP_TPA           24

#define ARP_OPER_REQUEST   1
#define ARP_OPER_REPLY     2
/* }}}1 */

#endif
