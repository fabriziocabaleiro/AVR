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

#define TMP_REG4 ARG_REG2

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
    push  YL
    push  YH

    rcall ETH_READ_BUFFER_START
    /* Read UDP header */
    ldi   COUNTER_REG, UDP_HEADER_LEN
    ldi   ZL, lo8(SRAM_UDP_HEADER)
    ldi   ZH, hi8(SRAM_UDP_HEADER)
READ_HEADER:
    ETH_READ_NEXT_BYTE
    st    Z+, RTV_L_REG
    dec   COUNTER_REG
    brne  READ_HEADER

    /* Set common argument for ES_MEMCMP */
    ldi   ZL, lo8(SRAM_UDP_HEADER)
    ldi   ZH, hi8(SRAM_UDP_HEADER)
    ldi   ARG_REG1, 4

    /* DHCP */
    ldi   YL, lo8(EEPROM_DHCP_SRC_DST_PORT)
    ldi   YH, hi8(EEPROM_DHCP_SRC_DST_PORT)
    rcall ES_MEMCMP
    brne  TRY_COMM
    rcall DHCP_HANDLE_PKT
    rjmp  UDP_HANDLE_PKT_END

    /* COMM */
TRY_COMM:
    /* TODO: ADIW instead of 2 x LDI */
    ldi   YL, lo8(EEPROM_COMM_SRC_DST_PORT)
    ldi   YH, hi8(EEPROM_COMM_SRC_DST_PORT)
    rcall ES_MEMCMP
    brne  UDP_HANDLE_PKT_END
    rcall COMM_REGISTER_IP

UDP_HANDLE_PKT_END:
    ETH_READ_BUFFER_END
    pop   YH
    pop   YL
    ret

/* Prepare UDP packet {{{2 -----------------------------------------------------
 * Note: UDP header and payload in IPv4 payload
 * Z, pointer to start writing the UDP packet to.
 * Y, pointer to the data that is going to be read from
 * This routine should write no more than 200 bytes of data */
UDP_PREPARE_PACKET:
    push  YL
    push  YH

    ldi   YL, lo8(SRAM_UDP_HEADER)
    ldi   YH, hi8(SRAM_UDP_HEADER)
    /* Write Src, Dst and Length. Chksum will be written next */
    ldi   ARG_REG1, (UDP_HEADER_CHK_SUM - UDP_HEADER_SRC_PORT)
    rcall MEMCPY

    /* Clear checksum */
    st    Z+, ZERO_REG
    st    Z+, ZERO_REG

    /* Copy payload */
    pop   YH
    pop   YL
    lds   ARG_REG1, SRAM_UDP_PKT_LEN + 1
    rcall MEMCPY

    ret

.end
