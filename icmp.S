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

/* GLOBAL {{{1 ---------------------------------------------------------------*/
.global ICMP_HANDLE_PKT

/* TEXT {{{1 -----------------------------------------------------------------*/
/* Handle ICMP packet {{{2 -----------------------------------------------------
 * Z has been set to SRAM_IPV4_HEADER in the previous routine
 * Not supporting ping with total length greater than 255 */
ICMP_HANDLE_PKT:
    push  s1
    push  ZL
    push  ZH
    push  YL
    push  YH

    /* Read message type, if not ICMP_MSG_TYPE_ECHO, then ignore packet {{{3 */
    rcall ETH_READ_BUFFER_START
    ETH_READ_NEXT_BYTE
    cpi   x4, ICMP_MSG_TYPE_ECHO
    brne  ICMP_HANDLE_PKT_EXIT

    /* Swap Src and Dst IP addresses {{{3 */
    ldi   t3, IPV4_ADDR_LEN
    adiw  ZL, IPV4_SRC_ADDR
SWAP_IP_ADDR:
    ld    t1, Z
    ldd   t2, Z + (IPV4_DST_ADDR - IPV4_SRC_ADDR)
    std   Z + (IPV4_DST_ADDR - IPV4_SRC_ADDR), t1
    st    Z+, t2
    dec   t3
    brne  SWAP_IP_ADDR

    /* Read IPv4 payload {{{3 */
    /* Calculate IPv4 payload length */
    lds   t3, (SRAM_IPV4_HEADER + IPV4_TOTAL_LENGTH + 1)
    lds   t1, SRAM_IPV4_IHL_IN_BYTES
    sub   t3, t1
    /* Plus 1 as we already read ICMP MSG TYPE */
    ldi   ZL, lo8(SRAM_IPV4_PAYLOAD + 1)
    ldi   ZH, hi8(SRAM_IPV4_PAYLOAD + 1)
    /* TODO: SPI_MEMCPY ? */
READ_PAYLOAD:
    ETH_READ_NEXT_BYTE
    st    Z+, x4
    dec   t3
    brne  READ_PAYLOAD
    ETH_READ_BUFFER_END

    /* Write Ethernet header into transmit buffer {{{3 */
    rcall ETH_WRITE_BUFFER_PACKET_HEADER

    /* Write IPv4 Header into transmit buffer {{{3 */
    ldi   ZL, lo8(SRAM_IPV4_HEADER)
    ldi   ZH, hi8(SRAM_IPV4_HEADER)
    lds   x1, SRAM_IPV4_IHL_IN_BYTES
    /* Taking the change to store IPv4 Total Length */
    ldd   s1, Z + IPV4_TOTAL_LENGTH + 1
    rcall ETH_WRITE_Z_TO_TRANSMIT_BUFFER

    /* Prepare ICMP packet {{{3 */
    /* We read the first byte of the ICMP packet to check if it was
     * ICMP_MSG_TYPE_ECHO, then skipped the first byte when coping the ICMP
     * packet into SRAM, now, we are modifying what we read to be sent as ICMP
     * reply, setting first byte for reply */
    ldi   t1, ICMP_MSG_TYPE_ECHO_REPLY
    sts   SRAM_IPV4_PAYLOAD, t1

    /* Calculate ICMP packet size (IPv4 total length - IHL (in bytes)) */
    lds   t1, SRAM_IPV4_IHL_IN_BYTES
    sub   s1, t1
    mov   x1, s1
    ldi   ZL, lo8(SRAM_IPV4_PAYLOAD)
    ldi   ZH, hi8(SRAM_IPV4_PAYLOAD)

    /* Could check that received checksum is correct, but, why should I care? */
    /* Clear received checksum */
    std   Z + IPV4_ICMP_CHECKSUM + 0, zero
    std   Z + IPV4_ICMP_CHECKSUM + 1, zero
    /* x1 & Z must be not changed by INTERNET_CHECKSUM_RFC1071 */
    ldi   x2, 0
    rcall INTERNET_CHECKSUM_RFC1071
    std   Z + IPV4_ICMP_CHECKSUM + 0, x3
    std   Z + IPV4_ICMP_CHECKSUM + 1, x4

    /* Write IPv4 payload and finalize ETH transmission {{{3 */
    rcall ETH_WRITE_Z_TO_TRANSMIT_BUFFER
    rcall ETH_WRITE_BUFFER_PACKET_PAYLOAD_FINISH
    /* }}}3 */
ICMP_HANDLE_PKT_EXIT:
    pop   YH
    pop   YL
    pop   ZH
    pop   ZL
    pop   s1
    ret

.end
