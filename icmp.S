/* vim: set filetype=S foldmethod=marker: */
.NOLIST
#include <avr/io.h>
#include "defs.h"
#include "icmp.h"
#include "enc28j60.h"
#include "ipv4.h"
.LIST

.global ICMP_HANDLE_PKT

#define IPV4_TOTAL_LENGTH_REG R1
#pragma GCC poison R1

/*******************************************************************************
 * Handle ICMP packet {{{
 * Z has been set to SRAM_IPV4_HEADER in the previous routine
 * Not supporting ping with total length greater than 255
 ******************************************************************************/
ICMP_HANDLE_PKT:
    push  COUNTER_REG
    push  ZL
    push  ZH
    push  YL
    push  YH

    /* Read message type, if not ICMP_MSG_TYPE_ECHO, then ignore packet */
    rcall ETH_READ_BUFFER_START
    ETH_READ_NEXT_BYTE
    cpi   RETURN_VALUE, ICMP_MSG_TYPE_ECHO
    brne  ICMP_HANDLE_PKT_EXIT_SUCCESS

    /* Before reading ICMP ECHO payload, modify IPv4 Header, swapping Src and
     * Dst IP addresses */
    ldi   COUNTER_REG, IPV4_ADDR_LEN
SWAP_IP_ADDR:
    ldd   TMP_REG1, Z + IPV4_SRC_ADDR
    ldd   TMP_REG2, Z + IPV4_DST_ADDR
    std   Z + IPV4_DST_ADDR, TMP_REG1
    std   Z + IPV4_SRC_ADDR, TMP_REG2
    adiw  ZL, 1
    dec   COUNTER_REG
    brne  SWAP_IP_ADDR

    /* Read IPv4 payload */
    /* Calculate IPv4 payload length */
    lds   COUNTER_REG, (SRAM_IPV4_HEADER + IPV4_TOTAL_LENGTH + 1)
    lds   TMP_REG1, SRAM_IPV4_IHL_IN_BYTES
    sub   COUNTER_REG, TMP_REG1
    /* Plus 1 as we already read ICMP MSG TYPE */
    ldi   ZL, lo8(SRAM_IPV4_PAYLOAD + 1)
    ldi   ZH, hi8(SRAM_IPV4_PAYLOAD + 1)
READ_PAYLOAD:
    ETH_READ_NEXT_BYTE
    st    Z+, RETURN_VALUE
    dec   COUNTER_REG
    brne  READ_PAYLOAD
    ETH_READ_BUFFER_END

    /* Write Ethernet header into transmit buffer */
    rcall ETH_WRITE_BUFFER_PACKET_HEADER

    /* Write IPv4 Header into transmit buffer */
    ldi   ZL, lo8(SRAM_IPV4_HEADER)
    ldi   ZH, hi8(SRAM_IPV4_HEADER)
    lds   ARG_REG1, SRAM_IPV4_IHL_IN_BYTES
    /* Taking the change to store IPv4 Total Length */
    ldd   IPV4_TOTAL_LENGTH_REG, Z + IPV4_TOTAL_LENGTH + 1
    rcall ETH_WRITE_Z_TO_TRANSMIT_BUFFER

    /* We read the first byte of the ICMP packet to check if it was
     * ICMP_MSG_TYPE_ECHO, then skipped the first byte when coping the ICMP
     * packet into SRAM, now, we are modifying what we read to be sent as ICMP
     * reply, setting first byte for reply */
    ldi   TMP_REG1, ICMP_MSG_TYPE_ECHO_REPLY
    sts   SRAM_IPV4_PAYLOAD, TMP_REG1

    /* Calculate ICMP packet size (IPv4 total length - IHL (in bytes)) */
    lds   TMP_REG1, SRAM_IPV4_IHL_IN_BYTES
    sub   IPV4_TOTAL_LENGTH_REG, TMP_REG1
    mov   ARG_REG1, IPV4_TOTAL_LENGTH_REG
    ldi   ZL, lo8(SRAM_IPV4_PAYLOAD)
    ldi   ZH, hi8(SRAM_IPV4_PAYLOAD)

    /* Could check that received checksum is correct, but, why should I care? */
    /* Clear received checksum */
    clr   TMP_REG2
    std   Z + IPV4_ICMP_CHECKSUM + 0, TMP_REG2
    std   Z + IPV4_ICMP_CHECKSUM + 1, TMP_REG2
    /* ARG_REG1 & Z must be not changed by INTERNET_CHECKSUM_RFC1071 */
    rcall INTERNET_CHECKSUM_RFC1071
    std   Z + IPV4_ICMP_CHECKSUM + 0, YH
    std   Z + IPV4_ICMP_CHECKSUM + 1, YL

    rcall ETH_WRITE_Z_TO_TRANSMIT_BUFFER
    rcall ETH_WRITE_BUFFER_PACKET_PAYLOAD_FINISH

ICMP_HANDLE_PKT_EXIT_SUCCESS:
    ldi   RETURN_VALUE, 0
IPV4_RESPONSE_IF_PING_END:
    pop   YH
    pop   YL
    pop   ZH
    pop   ZL
    pop   COUNTER_REG
    ret
/* }}} */

#undef IPV4_TOTAL_LENGTH_REG

.end
