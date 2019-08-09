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
#define UDP_SRC_PORT 7070
#define UDP_DST_PORT 7070
#define UDP_PKT_LEN    14
#define UDP_HEADER_LEN  8

#define TMP_REG4 ARG_REG2

/* GLOBAL {{{1 ---------------------------------------------------------------*/
.global UDP_HANDLE_PKT
.global UDP_PREPARE_PACKET

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
    /* Read UDP header {{{3 */
    ldi   COUNTER_REG, UDP_HEADER_LEN
    ldi   ZL, lo8(SRAM_UDP_HEADER)
    ldi   ZH, hi8(SRAM_UDP_HEADER)
READ_HEADER:
    ETH_READ_NEXT_BYTE
    st    Z+, RTV_L_REG
    dec   COUNTER_REG
    brne  READ_HEADER

    /* Set common argument for EEPROM_SRAM_CMP {{{3 */
    ldi   ZL, lo8(SRAM_UDP_HEADER)
    ldi   ZH, hi8(SRAM_UDP_HEADER)
    ldi   ARG_REG1, 4

    /* DHCP {{{3 */
    ldi   YL, lo8(EEPROM_DHCP_SRC_DST_PORT)
    ldi   YH, hi8(EEPROM_DHCP_SRC_DST_PORT)
    rcall EEPROM_SRAM_CMP
    sbrs  RTV_L_REG, 0
    rcall DHCP_HANDLE_PKT

    /* Register a device IP to send messages to {{{3 */
    ldi   YL, lo8(EEPROM_COMM_SRC_DST_PORT)
    ldi   YH, hi8(EEPROM_COMM_SRC_DST_PORT)
    rcall EEPROM_SRAM_CMP
    sbrs  RTV_L_REG, 0
    rcall COMM_REGISTER_IP /* }}}3 */

    ETH_READ_BUFFER_END
    pop   YH
    pop   YL
    ret

/* Prepare UDP packet {{{2 -----------------------------------------------------
 * Note: UDP header and payload in IPv4 payload
 * Z, pointer to start writing the UDP packet to.
 * Y, pointer to the data that is going to be read from
 * ARG_REG1 bytes of data to send
 * This routine should write no more than 200 bytes of data */
UDP_PREPARE_PACKET:
    /* Calculate return value, which is length of data plus 4 */
    mov   RTV_L_REG, ARG_REG1
    ldi   TMP_REG2, UDP_HEADER_LEN
    add   RTV_L_REG, TMP_REG2
    mov   ARG_REG1, RTV_L_REG
    /* Write Source port */
    ldi   TMP_REG2, hi8(UDP_SRC_PORT)
    st    Z+, TMP_REG2
    ldi   TMP_REG2, lo8(UDP_SRC_PORT)
    st    Z+, TMP_REG2
    /* Write Destination port */
    ldi   TMP_REG2, hi8(UDP_DST_PORT)
    st    Z+, TMP_REG2
    ldi   TMP_REG2, lo8(UDP_DST_PORT)
    st    Z+, TMP_REG2
    /* Write length */
    clr   TMP_REG2
    st    Z+, TMP_REG2
    st    Z+, ARG_REG1
    /* Checksum, if not use, then zero */
    clr   TMP_REG2
    st    Z+, TMP_REG2
    st    Z+, TMP_REG2
    /* Copy the data pointed by Y into Z */
UDP_PREPARE_PACKET_LOOP:
    ld    TMP_REG2, Y+
    st    Z+, TMP_REG2
    dec   ARG_REG1
    brne  UDP_PREPARE_PACKET_LOOP

    ret

.end
