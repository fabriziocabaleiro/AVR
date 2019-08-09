/* vim: set filetype=S foldmethod=marker: */
/* INCLUDES {{{1 -------------------------------------------------------------*/
.NOLIST
#include <avr/io.h>
#include "defs.h"
#include "dht11.h"
#include "ipv4.h"
#include "enc28j60.h"
.LIST

/* GLOBAL {{{1 ---------------------------------------------------------------*/
.global SEND_PACKET
.global COMM_REGISTER_IP
.global COMM_INIT

.global SRAM_COMM_MAC_ADDR_DST
.global SRAM_COMM_IP_ADDR_DST
.global SRAM_COMM_UDP_PORT_DST

/* DATA  {{{1 ----------------------------------------------------------------*/
.section .data
SRAM_COMM_TYPE_LEN: .skip 2

SRAM_COMM_MAC_ADDR_DST: .skip MAC_ADDR_LEN
SRAM_COMM_IP_ADDR_DST:  .skip IPV4_ADDR_LEN /* SRAM_COMM_UDP_PORT_DST must
                                               follow SRAM_COMM_IP_ADDR_DST */
SRAM_COMM_UDP_PORT_DST: .skip IPV4_PORT_LEN

/* TEXT {{{1 -----------------------------------------------------------------*/
.section .text

/* COMM init {{{2 --------------------------------------------------------------
 * Initialize communication */
COMM_INIT:
    ldi   TMP_REG2, hi8(ETHER_TYPE_IPV4)
    sts   SRAM_COMM_TYPE_LEN + 0, TMP_REG2
    ldi   TMP_REG2, lo8(ETHER_TYPE_IPV4)
    sts   SRAM_COMM_TYPE_LEN + 1, TMP_REG2
    ret

/* Send a packet to the MAC Address in SRAM_MAC_ADDR_OTHER {{{2 ----------------
 * Z points to the data
 * ARG_REG1 is the length */
SEND_PACKET:
    push  COUNTER_REG
    push  ZL
    push  ZH
    push  YL
    push  YH

    /* Check if first byte of DST IP address is zero, if so, we assume it isn't
     * configure and skip sending a message */
    lds   TMP_REG1, SRAM_COMM_IP_ADDR_DST
    tst   TMP_REG1
    breq  SEND_PACKET_EXIT

    /* Set MAC Dst pointer */
    ldi   YL, lo8(SRAM_COMM_IP_ADDR_DST)
    ldi   YH, hi8(SRAM_COMM_IP_ADDR_DST)
    rcall ARP_GET_MAC_ADDR_PTR
    brne  SEND_PACKET_EXIT
    sts   SRAM_ENC_MAC_DST_PTR + 0, YH
    sts   SRAM_ENC_MAC_DST_PTR + 1, YL

    /* Set type/len pointer */
    ldi   TMP_REG2, hi8(SRAM_COMM_TYPE_LEN)
    sts   SRAM_ENC_TYPE_LEN_PTR + 0, TMP_REG2
    ldi   TMP_REG2, lo8(SRAM_COMM_TYPE_LEN)
    sts   SRAM_ENC_TYPE_LEN_PTR + 1, TMP_REG2

    /* Write Ethernet Header */
    rcall ETH_WRITE_BUFFER_PACKET_HEADER

    /* Prepare UDP packet, write it into IPv4 payload */
    /* TODO: break requirement of DHT11 and MQ135 data consecutive */
    ldi   ZH, hi8(SRAM_IPV4_PAYLOAD)
    ldi   ZL, lo8(SRAM_IPV4_PAYLOAD)
    ldi   YH, hi8(SRAM_DHT11_PAYLOAD)
    ldi   YL, lo8(SRAM_DHT11_PAYLOAD)
    ldi   ARG_REG1, (DHT11_PAYLOAD_LEN + MQ135_PAYLOAD_LEN)
    rcall UDP_PREPARE_PACKET

    push  RTV_L_REG /* Save ipv4 payload size */

    /* Set Dst IP address {{{ */
    ldi   YL, lo8(SRAM_COMM_IP_ADDR_DST)
    ldi   YH, hi8(SRAM_COMM_IP_ADDR_DST)
    ldi   ZL, lo8(SRAM_IP_ADDR_DST)
    ldi   ZH, hi8(SRAM_IP_ADDR_DST)
    ldi   ARG_REG1, IPV4_ADDR_LEN
    rcall MEMCPY
    /* }}} */
    /* IPv4 default header size is 20, add UDP length to it */
    ldi   ARG_REG1, 20
    add   ARG_REG1, RTV_L_REG
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

SEND_PACKET_EXIT:
    pop   YH
    pop   YL
    pop   ZH
    pop   ZL
    pop   COUNTER_REG
    ret
/* }}} */
/* Register an IP to send packages to {{{
 * Z points to the data
 * ARG_REG1 is the length */
COMM_REGISTER_IP:
    ldi   YL, lo8(SRAM_COMM_IP_ADDR_DST)
    ldi   YH, hi8(SRAM_COMM_IP_ADDR_DST)
    ldi   COUNTER_REG, IPV4_ADDR_LEN + IPV4_PORT_LEN
COMM_REGISTER_IP_LOOP:
    ETH_READ_NEXT_BYTE
    st    Y+, RTV_L_REG
    dec   COUNTER_REG
    brne  COMM_REGISTER_IP_LOOP
    ETH_READ_BUFFER_END

    /* TODO: move somewhere else */
    rcall ARP_REQUEST
    ret
/* }}} */
.end
