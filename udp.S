/* vim: set filetype=S foldmethod=marker: */
/* INCLUDES {{{1 */
.NOLIST
#include <avr/io.h>
#include "defs.h"
#include "udp.h"
#include "enc28j60.h"
#include "eeprom_data.h"
.LIST

/* MACORS {{{1 ---------------------------------------------------------------*/
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

/* Handle received UDP packet {{{2 -------------------------------------------*/
UDP_HANDLE_PKT:
    push  xl
    push  xh

    rcall ETH_READ_BUFFER_START
    /* Read UDP header */
    ldi   t3, UDP_HEADER_LEN
    ldi   zl, lo8(SRAM_UDP_HEADER)
    ldi   zh, hi8(SRAM_UDP_HEADER)
READ_HEADER:
    ETH_READ_NEXT_BYTE
    st    z+, a4
    dec   t3
    brne  READ_HEADER

    /* Set common argument for E_MEMCMP */
    ldi   zl, lo8(SRAM_UDP_HEADER)
    ldi   zh, hi8(SRAM_UDP_HEADER)
    ldi   a1, 4

    /* DHCP */
    ldi   xl, lo8(EEPROM_DHCP_SRC_DST_PORT)
    ldi   xh, hi8(EEPROM_DHCP_SRC_DST_PORT)
    rcall E_MEMCMP
    brne  TRY_COMM
    rcall DHCP_HANDLE_PKT
    rjmp  UDP_HANDLE_PKT_END

    /* COMM */
TRY_COMM:
    /* TODO: ADIW instead of 2 x LDI */
    ldi   xl, lo8(EEPROM_COMM_SRC_DST_PORT)
    ldi   xh, hi8(EEPROM_COMM_SRC_DST_PORT)
    rcall E_MEMCMP
    brne  UDP_HANDLE_PKT_END
    rcall COMM_REGISTER_IP

UDP_HANDLE_PKT_END:
    ETH_READ_BUFFER_END
    pop   xh
    pop   xl
    ret

/* Prepare UDP packet {{{2 -----------------------------------------------------
 * Note: UDP header and payload in IPv4 payload
 * z, pointer to start writing the UDP packet to.
 * x, pointer to the data that is going to be read from
 * This routine should write no more than 200 bytes of data */
UDP_PREPARE_PACKET:
    push  xl
    push  xh

    /* Write UDP header */
    ldi   xl, lo8(SRAM_UDP_HEADER)
    ldi   xh, hi8(SRAM_UDP_HEADER)
    /* Write Src, Dst and Length. Chksum will be written next */
    ldi   a1, (UDP_HEADER_CHK_SUM - UDP_HEADER_SRC_PORT)
    rcall MEMCPY

    /* Clear checksum */
    st    z+, zero
    st    z+, zero

    /* Copy payload */
    pop   xh
    pop   xl
    lds   a1, SRAM_UDP_PKT_LEN + 1
    rcall MEMCPY

    ret

.end
