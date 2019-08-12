/* vim: set filetype=S foldmethod=marker: */
/* INCLUDES {{{1 */
.NOLIST
#include <avr/io.h>
#include "defs.h"
#include "icmp.h"
#include "enc28j60.h"
#include "ipv4.h"
.LIST

/* MACROS {{{1 ---------------------------------------------------------------*/
#define IPV4_TOTAL_LENGTH_REG R14
#pragma GCC poison R14

/* GLOBAL {{{1 ---------------------------------------------------------------*/
.global ICMP_HANDLE_PKT

/* TEXT {{{1 -----------------------------------------------------------------*/
/* Handle ICMP packet {{{2 -----------------------------------------------------
 * Z has been set to SRAM_IPV4_HEADER in the previous routine
 * Not supporting ping with total length greater than 255 */
ICMP_HANDLE_PKT:
    push  IPV4_TOTAL_LENGTH_REG
    push  COUNTER_REG
    push  ZL
    push  ZH
    push  YL
    push  YH

    /* Read message type, if not ICMP_MSG_TYPE_ECHO, then ignore packet {{{3 */
    rcall ETH_READ_BUFFER_START
    ETH_READ_NEXT_BYTE
    cpi   RTV_L_REG, ICMP_MSG_TYPE_ECHO
    brne  ICMP_HANDLE_PKT_EXIT

    /* Swap Src and Dst IP addresses {{{3 */
    ldi   COUNTER_REG, IPV4_ADDR_LEN
    adiw  ZL, IPV4_SRC_ADDR
SWAP_IP_ADDR:
    ld    TMP_REG1, Z
    ldd   TMP_REG2, Z + (IPV4_DST_ADDR - IPV4_SRC_ADDR)
    std   Z + (IPV4_DST_ADDR - IPV4_SRC_ADDR), TMP_REG1
    st    Z+, TMP_REG2
    dec   COUNTER_REG
    brne  SWAP_IP_ADDR

    /* Read IPv4 payload {{{3 */
    /* Calculate IPv4 payload length */
    lds   COUNTER_REG, (SRAM_IPV4_HEADER + IPV4_TOTAL_LENGTH + 1)
    lds   TMP_REG1, SRAM_IPV4_IHL_IN_BYTES
    sub   COUNTER_REG, TMP_REG1
    /* Plus 1 as we already read ICMP MSG TYPE */
    ldi   ZL, lo8(SRAM_IPV4_PAYLOAD + 1)
    ldi   ZH, hi8(SRAM_IPV4_PAYLOAD + 1)
READ_PAYLOAD:
    ETH_READ_NEXT_BYTE
    st    Z+, RTV_L_REG
    dec   COUNTER_REG
    brne  READ_PAYLOAD
    ETH_READ_BUFFER_END

    /* Write Ethernet header into transmit buffer {{{3 */
    rcall ETH_WRITE_BUFFER_PACKET_HEADER

    /* Write IPv4 Header into transmit buffer {{{3 */
    ldi   ZL, lo8(SRAM_IPV4_HEADER)
    ldi   ZH, hi8(SRAM_IPV4_HEADER)
    lds   ARG_REG1, SRAM_IPV4_IHL_IN_BYTES
    /* Taking the change to store IPv4 Total Length */
    ldd   IPV4_TOTAL_LENGTH_REG, Z + IPV4_TOTAL_LENGTH + 1
    rcall ETH_WRITE_Z_TO_TRANSMIT_BUFFER

    /* Prepare ICMP packet {{{3 */
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
    std   Z + IPV4_ICMP_CHECKSUM + 0, ZERO_REG
    std   Z + IPV4_ICMP_CHECKSUM + 1, ZERO_REG
    /* ARG_REG1 & Z must be not changed by INTERNET_CHECKSUM_RFC1071 */
    rcall INTERNET_CHECKSUM_RFC1071
    std   Z + IPV4_ICMP_CHECKSUM + 0, RTV_H_REG
    std   Z + IPV4_ICMP_CHECKSUM + 1, RTV_L_REG

    /* Write IPv4 payload and finilize ETH transmission {{{3 */
    rcall ETH_WRITE_Z_TO_TRANSMIT_BUFFER
    rcall ETH_WRITE_BUFFER_PACKET_PAYLOAD_FINISH
    /* }}}3 */
ICMP_HANDLE_PKT_EXIT:
    pop   YH
    pop   YL
    pop   ZH
    pop   ZL
    pop   COUNTER_REG
    pop   IPV4_TOTAL_LENGTH_REG
    ret

.end
