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
#include "udp.h"
#include "enc28j60.h"
#include "eeprom_data.h"
.LIST

/* MACROS {{{1 ---------------------------------------------------------------*/
#define UDP_PKT_LEN    14
#define UDP_HEADER_LEN  8

/* GLOBAL {{{1 ---------------------------------------------------------------*/
.global UDP_HANDLE_PKT
.global UDP_PREPARE_PACKET
.global SRAM_UDP_HEADER

/* DATA  {{{1 ----------------------------------------------------------------*/
.section .data
SRAM_UDP_HEADER:
SRAM_UDP_SRC_PORT: .skip 2
SRAM_UDP_DST_PORT: .skip 2
SRAM_UDP_PKT_LEN:  .skip 2
SRAM_UDP_CHKSUM:   .skip 2

/* TEXT {{{1 -----------------------------------------------------------------*/
.section .text

/* UDP_HANDLE_PKT {{{2 ---------------------------------------------------------
 * The UDP handler will copy the UDP header into SRAM and deliver the packet to
 * the corresponding handler based on the Src/Dst UDP port.
 *
 * UDP header is going to be copy from SPI.
 * ---------------------------------------------------------------------------*/
UDP_HANDLE_PKT:
    rcall ETH_READ_BUFFER_START
    /* Read UDP header */
    ldi   zl, lo8(SRAM_UDP_HEADER)
    ldi   zh, hi8(SRAM_UDP_HEADER)
    ldi   a1, UDP_HEADER_LEN
    rcall MEMCPY_SPI_SRAM

    /* Set common argument for MEMCMP_SRAM_EEPROM */
    sbiw  zl, UDP_HEADER_LEN
    ldi   a1, 4

    /* DHCP */
    ldi   xl, lo8(EEPROM_DHCP_SRC_DST_PORT)
    ldi   xh, hi8(EEPROM_DHCP_SRC_DST_PORT)
    rcall MEMCMP_SRAM_EEPROM
    brne  0f
    rcall DHCP_HANDLE_PKT
    rjmp  9f

    /* COMM */
0:  adiw  xl, EEPROM_COMM_SRC_DST_PORT - EEPROM_DHCP_SRC_DST_PORT
    rcall MEMCMP_SRAM_EEPROM
    brne  9f
    rcall COMM_REGISTER_IP

9:  ETH_READ_BUFFER_END
    ret

/* UDP_PREPARE_PACKET {{{2 -----------------------------------------------------
 * Copy/Set UDP header and copy UDP payload.
 *
 * x: Pointer to UDP payload (read from).
 * z: Pointer to write to, e.g. IPv4 payload.
 * ---------------------------------------------------------------------------*/
UDP_PREPARE_PACKET:
    /* Save x for later */
    push  xl
    push  xh

    /* Write UDP header */
    ldi   xl, lo8(SRAM_UDP_HEADER)
    ldi   xh, hi8(SRAM_UDP_HEADER)
    /* Write Src, Dst and Length. Chksum will be written next */
    ldi   a1, (UDP_HEADER_CHK_SUM - UDP_HEADER_SRC_PORT)
    rcall MEMCPY_SRAM_SRAM

    /* Clear checksum */
    st    z+, zero
    st    z+, zero

    /* Copy payload */
    pop   xh
    pop   xl
    lds   a1, SRAM_UDP_PKT_LEN + 1
    rcall MEMCPY_SRAM_SRAM

    ret

.end
