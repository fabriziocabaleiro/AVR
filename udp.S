/* vim: set filetype=S foldmethod=marker: */
.NOLIST
#include <avr/io.h>
#include "defs.h"
#include "udp.h"
#include "enc28j60.h"
.LIST

.global UDP_HANDLE_PKT
.global UDP_PREPARE_PACKET

#define READ_NEXT_BYTE rcall SPI_MASTER_TRANSMIT

#define UDP_SRC_PORT 7070
#define UDP_DST_PORT 7070
#define UDP_PKT_LEN    14

// #define TMP_REG3 ARG_REG1
#define TMP_REG4 ARG_REG2


/*******************************************************************************
 * Handle received UDP packet {{{
 ******************************************************************************/
UDP_HANDLE_PKT:
    rcall ETH_READ_BUFFER_START
    READ_NEXT_BYTE
    mov   TMP_REG1, RETURN_VALUE
    READ_NEXT_BYTE
    mov   TMP_REG2, RETURN_VALUE
    READ_NEXT_BYTE
    mov   TMP_REG3, RETURN_VALUE
    READ_NEXT_BYTE
    mov   TMP_REG4, RETURN_VALUE
    /* TODO: store correctly rest of UDP header */
    READ_NEXT_BYTE
    READ_NEXT_BYTE
    READ_NEXT_BYTE
    READ_NEXT_BYTE

    /* check if DHCP */
    cpi   TMP_REG1, hi8(INTERNET_SERVICE_BOOTPS_67_UDP)
    brne  NO_DHCP
    cpi   TMP_REG2, lo8(INTERNET_SERVICE_BOOTPS_67_UDP)
    brne  NO_DHCP
    cpi   TMP_REG3, hi8(INTERNET_SERVICE_BOOTPC_68_TCP)
    brne  NO_DHCP
    cpi   TMP_REG4, lo8(INTERNET_SERVICE_BOOTPC_68_TCP)
    brne  NO_DHCP
    rcall DHCP_HANDLE_PKT
    ret
NO_DHCP:
    ETH_READ_BUFFER_END
    ret
/* }}} */

/*******************************************************************************
 * Prepare UDP packet {{{
 * Note: UDP header and payload in IPv4 payload
 * Z, pointer to start writing the UDP packet to.
 * Y, pointer to the data that is going to be read from
 * ARG_REG1 bytes of data to send
 * This routine should write no more than 200 bytes of data
 ******************************************************************************/
UDP_PREPARE_PACKET:
    /* Calculate return value, which is length of data plus 4 */
    mov   RETURN_VALUE, ARG_REG1
    ldi   TMP_REG2, UDP_HEADER_LEN
    add   RETURN_VALUE, TMP_REG2
    mov   ARG_REG1, RETURN_VALUE
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
/* }}} */
