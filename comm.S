/* vim: set filetype=S foldmethod=marker: */
.NOLIST
#include <avr/io.h>
#include "defs.h"
#include "dht11.h"
.LIST

.global SEND_PACKET

.section .data
SRAM_COMM_MAC_DST:  .skip 6
SRAM_COMM_TYPE_LEN: .skip 2
SRAM_COMM_PKT_LEN:  .skip 1

.section .text

/*******************************************************************************
 * Send a packet to the MAC Address in SRAM_MAC_ADDR_OTHER {{{
 * Z points to the data
 * ARG_REG1 is the length
 ******************************************************************************/
SEND_PACKET:
    push  COUNTER_REG
    push  XL
    push  XH
    push  YL
    push  YH

#if 1 /* Waiting for fix */
    /* TODO: put this somewhere else */
    ldi   TMP_REG2, hi8(ETHER_TYPE_IPV4)
    sts   SRAM_COMM_TYPE_LEN + 0, TMP_REG2
    ldi   TMP_REG2, lo8(ETHER_TYPE_IPV4)
    sts   SRAM_COMM_TYPE_LEN + 1, TMP_REG2
    /* TODO: Set the mac address better */
    ldi   YH, hi8(SRAM_MAC_ADDR_OTHER)
    ldi   YL, lo8(SRAM_MAC_ADDR_OTHER)
    ldi   XH, hi8(SRAM_COMM_MAC_DST)
    ldi   XL, lo8(SRAM_COMM_MAC_DST)
    ldi   COUNTER_REG, MAC_SIZE_IN_BYTES
TMP_LABEL_002:
    ld    TMP_REG2, Y+
    st    X+, TMP_REG2
    dec   COUNTER_REG
    brne  TMP_LABEL_002
#endif
    
    /* Set MAC Dst and Type/Len pointers */
    ldi   TMP_REG2, hi8(SRAM_COMM_MAC_DST)
    sts   SRAM_ENC_MAC_DST_PTR + 0, TMP_REG2
    ldi   TMP_REG2, lo8(SRAM_COMM_MAC_DST)
    sts   SRAM_ENC_MAC_DST_PTR + 1, TMP_REG2

    ldi   TMP_REG2, hi8(SRAM_COMM_TYPE_LEN)
    sts   SRAM_ENC_TYPE_LEN_PTR + 0, TMP_REG2
    ldi   TMP_REG2, lo8(SRAM_COMM_TYPE_LEN)
    sts   SRAM_ENC_TYPE_LEN_PTR + 1, TMP_REG2

    /* Write Ethernet Header */
    rcall ETH_WRITE_BUFFER_PACKET_HEADER

    /* Prepare UDP packet, write it into IPv4 payload */
    ldi   ZH, hi8(SRAM_IPV4_PAYLOAD)
    ldi   ZL, lo8(SRAM_IPV4_PAYLOAD)
    ldi   YH, hi8(SRAM_DHT11_PAYLOAD)
    ldi   YL, lo8(SRAM_DHT11_PAYLOAD)
    ldi   ARG_REG1, (DHT11_PAYLOAD_LEN + MQ135_PAYLOAD_LEN)
    rcall UDP_PREPARE_PACKET

    push  RETURN_VALUE /* Save ipv4 payload size */

    /* IPv4 default header size is 20, add UDP length to it */
    ldi   ARG_REG1, 20
    add   ARG_REG1, RETURN_VALUE
    rcall IPV4_PREPARE_DEFAULT_HEADER_20_40_BYTES

    /* Write IPv4 header into enc28j60 */
    ldi   ZL, lo8(SRAM_IPV4_HEADER)
    ldi   ZH, hi8(SRAM_IPV4_HEADER)
    ldi   ARG_REG1, 20
    rcall ETH_WRITE_Z_TO_TRANSMIT_BUFFER

    /* Write IPv4 payload into enc28j60 */
    ldi   ZH, hi8(SRAM_IPV4_PAYLOAD)
    ldi   ZL, lo8(SRAM_IPV4_PAYLOAD)
    pop   ARG_REG1 /* Saved ipv4 payload size */
    rcall ETH_WRITE_Z_TO_TRANSMIT_BUFFER

    /* Send the packet */
    rcall ETH_WRITE_BUFFER_PACKET_PAYLOAD_FINISH

    pop   YH
    pop   YL
    pop   XH
    pop   XL
    pop   COUNTER_REG
    ret

/* }}} */

.end
