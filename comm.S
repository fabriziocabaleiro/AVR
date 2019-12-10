/* vim: set filetype=S foldmethod=marker: */
/* INCLUDES {{{1 -------------------------------------------------------------*/
.NOLIST
#include <avr/io.h>
#include "defs.h"
#include "dht11.h"
#include "ipv4.h"
#include "enc28j60.h"
#include "timer.h"
#include "udp.h"
#include "eeprom_data.h"
.LIST

/* MACORS {{{1 ---------------------------------------------------------------*/
#define TIMER_LEN               1
#define COMM_DST_TBL_ENTRY      (IPV4_ADDR_LEN +                               \
                                 IPV4_PORT_LEN +                               \
                                 IPV4_PORT_LEN +                               \
                                 TIMER_LEN +                                  \
                                 TIMER_LEN)
#define COMM_DST_TBL_SIZE       4
#define COMM_DST_TBL_LEN        (COMM_DST_TBL_ENTRY * COMM_DST_TBL_SIZE)

#define COMM_DST_IPV4_ADDR      0
#define COMM_DST_IPV4_SRC_PORT  (COMM_DST_IPV4_ADDR + IPV4_ADDR_LEN)
#define COMM_DST_IPV4_DST_PORT  (COMM_DST_IPV4_SRC_PORT + IPV4_PORT_LEN)
#define COMM_DST_IPV4_TIMER     (COMM_DST_IPV4_DST_PORT + IPV4_PORT_LEN)
#define COMM_DST_IPV4_TIME      (COMM_DST_IPV4_TIMER + TIMER_LEN)

/* GLOBAL {{{1 ---------------------------------------------------------------*/
.global SEND_PACKET
.global COMM_REGISTER_IP
.global COMM_INIT

.global SRAM_COMM_PAYLOAD

/* DATA  {{{1 ----------------------------------------------------------------*/
.section .data
SRAM_COMM_RR_ITERATOR: .skip 1
SRAM_COMM_TYPE_LEN:    .skip 2
SRAM_COMM_TABLE:       .skip (COMM_DST_TBL_LEN)
SRAM_COMM_PAYLOAD:     .skip (DHT11_PAYLOAD_LEN + MQ135_PAYLOAD_LEN)

/* TEXT {{{1 -----------------------------------------------------------------*/
.section .text

/* COMM init {{{2 --------------------------------------------------------------
 * Initialize communication */
COMM_INIT:
    sts   SRAM_COMM_RR_ITERATOR, ZERO_REG
    ldi   TMP_REG2, hi8(ETHER_TYPE_IPV4)
    sts   SRAM_COMM_TYPE_LEN + 0, TMP_REG2
    ldi   TMP_REG2, lo8(ETHER_TYPE_IPV4)
    sts   SRAM_COMM_TYPE_LEN + 1, TMP_REG2
    ret

/* Send a packet to IP registered in COMM table {{{2 ---------------------------
 * Z points to the data
 * ARG_REG1 is the length */
#define ENTRY_IT_REG        R23
#define ARG_UDP_PAYLOAD_REG R14
#pragma GCC poison          R23
#pragma GCC poison          R14
SEND_PACKET:
    push  ARG_UDP_PAYLOAD_REG
    push  ENTRY_IT_REG
    push  ZL
    push  ZH
    push  YL
    push  YH

    ldi   ENTRY_IT_REG, COMM_DST_TBL_SIZE
    mov   ARG_UDP_PAYLOAD_REG, ARG_REG1
    ldi   YL, lo8(SRAM_COMM_TABLE)
    ldi   YH, hi8(SRAM_COMM_TABLE)
    /* For all entries of the COMM table */
SEND_PACKET_FOR_ALL_ENTRIES:
    ldi   ARG_REG1, IPV4_ADDR_LEN
    clr   ARG_REG2
    rcall REG_MEMCMP
    breq  SEND_PACKET_NEXT_ENTRY
    push  YL
    push  YH
    /* Set MAC Dst pointer {{{3 */
    rcall ARP_GET_MAC_ADDR_PTR
    brne  IP_NOT_IN_ARP_TABLE
    sts   SRAM_ENC_MAC_DST_PTR + 0, RTV_H_REG
    sts   SRAM_ENC_MAC_DST_PTR + 1, RTV_L_REG

    /* Set Type/Len pointer {{{3 */
    ldi   TMP_REG2, hi8(SRAM_COMM_TYPE_LEN)
    sts   SRAM_ENC_TYPE_LEN_PTR + 0, TMP_REG2
    ldi   TMP_REG2, lo8(SRAM_COMM_TYPE_LEN)
    sts   SRAM_ENC_TYPE_LEN_PTR + 1, TMP_REG2
    /* }}}3 */
    /* Write Ethernet Header */
    rcall ETH_WRITE_BUFFER_PACKET_HEADER

    /* Set Dst IP address {{{3 */
    ldi   ZL, lo8(SRAM_IP_ADDR_DST)
    ldi   ZH, hi8(SRAM_IP_ADDR_DST)
    ldi   ARG_REG1, IPV4_ADDR_LEN
    rcall MEMCPY

    /* Set Src and Dst UDP port {{{3 */
    ldi   ZL, lo8(SRAM_UDP_HEADER + UDP_HEADER_SRC_PORT)
    ldi   ZH, hi8(SRAM_UDP_HEADER + UDP_HEADER_SRC_PORT)
    ldi   ARG_REG1, (IPV4_PORT_LEN * 2)
    rcall MEMCPY

    /* Set UDP packet length {{{3 */
    st    Z+, ZERO_REG
    ldi   TMP_REG1, (DHT11_PAYLOAD_LEN + MQ135_PAYLOAD_LEN + UDP_HEADER_LEN)
    st    Z+, TMP_REG1

    /* Prepare UDP packet {{{3 */
    ldi   YH, hi8(SRAM_COMM_PAYLOAD)
    ldi   YL, lo8(SRAM_COMM_PAYLOAD)
    ldi   ZH, hi8(SRAM_IPV4_PAYLOAD)
    ldi   ZL, lo8(SRAM_IPV4_PAYLOAD)
    mov   ARG_REG1, ARG_UDP_PAYLOAD_REG
    rcall UDP_PREPARE_PACKET

    /* Prepare IPv4 header {{{3 */
    ldi   ARG_REG1, (IPV4_DEFAULT_HEADER_LEN + UDP_HEADER_LEN)
    add   ARG_REG1, ARG_UDP_PAYLOAD_REG
    rcall IPV4_PREPARE_DEFAULT_HEADER_20_40_BYTES

    /* Write IPv4 header into Ethernet module {{{3 */
    ldi   ZL, lo8(SRAM_IPV4_HEADER)
    ldi   ZH, hi8(SRAM_IPV4_HEADER)
    ldi   ARG_REG1, 20
    rcall ETH_WRITE_Z_TO_TRANSMIT_BUFFER

    /* Write IPv4 payload into Ethernet module {{{3 */
    ldi   ZH, hi8(SRAM_IPV4_PAYLOAD)
    ldi   ZL, lo8(SRAM_IPV4_PAYLOAD)
    ldi   ARG_REG1, (DHT11_PAYLOAD_LEN + MQ135_PAYLOAD_LEN + UDP_HEADER_LEN)
    rcall ETH_WRITE_Z_TO_TRANSMIT_BUFFER
    /* }}}3 */
    /* Send the packet */
    rcall ETH_WRITE_BUFFER_PACKET_PAYLOAD_FINISH

IP_NOT_IN_ARP_TABLE:
    pop   YH
    pop   YL
SEND_PACKET_NEXT_ENTRY:
    dec   ENTRY_IT_REG
    breq  SEND_PACKET_EXIT
    adiw  YL, COMM_DST_TBL_ENTRY
    rjmp  SEND_PACKET_FOR_ALL_ENTRIES

SEND_PACKET_EXIT:
    pop   YH
    pop   YL
    pop   ZH
    pop   ZL
    pop   ENTRY_IT_REG
    pop   ARG_UDP_PAYLOAD_REG
    ret

#undef ARG_UDP_PAYLOAD_REG
#undef ENTRY_IT_REG

/* Register an IP to send packages to {{{2 -------------------------------------
 * Use Round Robin to write destination entries into the table */
COMM_REGISTER_IP:
    /* Select the entry on the table to register using ROUND ROBIN */
    lds   TMP_REG1, SRAM_COMM_RR_ITERATOR
    ldi   TMP_REG2, COMM_DST_TBL_ENTRY
    mul   TMP_REG1, TMP_REG2
    ldi   YL, lo8(SRAM_COMM_TABLE)
    ldi   YH, hi8(SRAM_COMM_TABLE)
    add   YL, XMULX_RTV_L_REG
    adc   YH, XMULX_RTV_H_REG
    /* Set RR iterator to next entry */
    inc   TMP_REG1
    cpi   TMP_REG1, COMM_DST_TBL_SIZE
    brne  1f
    clr   TMP_REG1
1:  sts   SRAM_COMM_RR_ITERATOR, TMP_REG1

    /* From start of entry till COMM_DST_IPV4_TIME */
    ldi   COUNTER_REG, COMM_DST_IPV4_TIME
COMM_REGISTER_IP_LOOP:
    ETH_READ_NEXT_BYTE
    st    Y+, RTV_L_REG
    dec   COUNTER_REG
    brne  COMM_REGISTER_IP_LOOP
    ETH_READ_BUFFER_END

    ret

.end
