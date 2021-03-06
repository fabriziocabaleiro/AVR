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
#include "icmp.h"
#include "enc28j60.h"
#include "ipv4.h"
.LIST

/* MACROS {{{1 ---------------------------------------------------------------*/
#define ICMP_TOM         0 /* Type of message */
#define ICMP_CODE        1
#define ICMP_CHECKSUM    2
#define ICMP_HEADER      4
#define ICMP_PAYLOAD     8 /* Optional */

/* GLOBAL {{{1 ---------------------------------------------------------------*/
.global ICMP_HANDLE_PKT

/* TEXT {{{1 -----------------------------------------------------------------*/
.section .text

/* ICMP_HANDLE_PKT {{{2 --------------------------------------------------------
 * Handle ICMP packet
 * Not supporting ping with total length greater than 255
 *
 * y: Pointer to SRAM_IPV4.
 *
 * After routine:
 * y: unchanged.
 * ---------------------------------------------------------------------------*/
ICMP_HANDLE_PKT:
    /* Read message type, if not ICMP_MSG_TYPE_ECHO, then ignore packet */
    rcall ETH_READ_BUFFER_START
    ETH_READ_NEXT_BYTE
    cpi   a4, ICMP_MSG_TYPE_ECHO
    brne  9f /* branch to ret */

    /* Swap Src and Dst IP addresses */
    /* Swapping IP addresses directly is faster, but generates bigger code */
    ldd   a1, y + IPV4_TOTAL_LENGTH + 1
    rcall IPV4_PREPARE_INCOMING_HEADER_FOR_RESPONSE

    /* Set ICMP msg type to echo reply, get the rest of IPv4 payload */
    ldi   a1, ICMP_MSG_TYPE_ECHO_REPLY
    ldi   zl, lo8(SRAM_IPV4_PAYLOAD)
    ldi   zh, hi8(SRAM_IPV4_PAYLOAD)
    st    z+, a1
    ldd   a1, y + (IPV4_PAYLOAD_LENGTH_IN_BYTES + 1)
    rcall MEMCPY_SPI_SRAM

    ETH_READ_BUFFER_END

    /* Write Ethernet header into transmit buffer */
    rcall ETH_WRITE_BUFFER_PACKET_HEADER

    /* Write IPv4 Header into transmit buffer */
    ldi   zl, lo8(SRAM_IPV4_HEADER)
    ldi   zh, hi8(SRAM_IPV4_HEADER)
    ldd   a1, y + IPV4_IHL_IN_BYTES
    rcall ETH_WRITE_TO_TRANSMIT_BUFFER

    /* Should we check that received checksum is correct ? */
    /* Set checksum for reply */
    ldd   a1, y + (IPV4_PAYLOAD_LENGTH_IN_BYTES + 1)
    ldi   zl, lo8(SRAM_IPV4_PAYLOAD)
    ldi   zh, hi8(SRAM_IPV4_PAYLOAD)
    /* Clear received checksum */
    std   z + ICMP_CHECKSUM + 0, zero
    std   z + ICMP_CHECKSUM + 1, zero
    /* a1 & z must be not changed by INTERNET_CHECKSUM_RFC1071 */
    ldi   a2, 0
    rcall INTERNET_CHECKSUM_RFC1071
    std   z + ICMP_CHECKSUM + 0, a3
    std   z + ICMP_CHECKSUM + 1, a4

    /* Write IPv4 payload and finalize ETH transmission */
    rcall ETH_WRITE_TO_TRANSMIT_BUFFER
    rcall ETH_WRITE_BUFFER_PACKET_PAYLOAD_FINISH

9:  ret

.end
