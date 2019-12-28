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
/* XXX: SRAM_COMM_TABLE must be right before SRAM_COMM_RR_ITERATOR, also
 * SRAM_COMM_TABLE must be the fist one (COMM_INIT) */
SRAM_COMM_TABLE:       .skip (COMM_DST_TBL_LEN)
SRAM_COMM_RR_ITERATOR: .skip 1
SRAM_COMM_PAYLOAD:     .skip (DHT11_PAYLOAD_LEN + MQ135_PAYLOAD_LEN)
/* XXX: Order dependency in COMM_INIT */
SRAM_COMM_TYPE_LEN:    .skip 2

/* TEXT {{{1 -----------------------------------------------------------------*/
.section .text

/* COMM init {{{2 --------------------------------------------------------------
 * Initialize communication */
COMM_INIT:
    ldi   ZL, lo8(SRAM_COMM_TABLE)
    ldi   ZH, hi8(SRAM_COMM_TABLE)
    ldi   x1, (COMM_DST_TBL_LEN + DHT11_PAYLOAD_LEN + MQ135_PAYLOAD_LEN + 1 + 2)
    rcall BZERO
    sbiw  ZL, 2
    ldi   t1, hi8(ETHER_TYPE_IPV4)
    st    Z+, t1
    ldi   t1, lo8(ETHER_TYPE_IPV4)
    st    Z+, t1
    ret

/* Send a packet to IP registered in COMM table {{{2 ---------------------------
 * x1 is the UDP length */
SEND_PACKET:
    push  s1 /* Counter for all entries of comm table */
    push  s2 /* Save x1 to be used later within loop */

    ldi   s1, COMM_DST_TBL_SIZE
    mov   s2, x1
    ldi   YL, lo8(SRAM_COMM_TABLE)
    ldi   YH, hi8(SRAM_COMM_TABLE)
    /* For all entries of the COMM table */
SEND_PACKET_FOR_ALL_ENTRIES:
    ldi   x1, IPV4_ADDR_LEN
    clr   x2
    rcall REG_MEMCMP
    breq  SEND_PACKET_NEXT_ENTRY
    push  YL
    push  YH
    /* Set MAC Dst pointer {{{3 */
    rcall ARP_GET_MAC_ADDR_PTR
    brne  IP_NOT_IN_ARP_TABLE
    sts   SRAM_ENC_MAC_DST_PTR + 0, x4
    sts   SRAM_ENC_MAC_DST_PTR + 1, x3

    /* Set Type/Len pointer {{{3 */
    ldi   t2, hi8(SRAM_COMM_TYPE_LEN)
    sts   SRAM_ENC_TYPE_LEN_PTR + 0, t2
    ldi   t2, lo8(SRAM_COMM_TYPE_LEN)
    sts   SRAM_ENC_TYPE_LEN_PTR + 1, t2
    /* }}}3 */
    /* Write Ethernet Header */
    rcall ETH_WRITE_BUFFER_PACKET_HEADER

    /* Set Dst IP address {{{3 */
    ldi   ZL, lo8(SRAM_IP_ADDR_DST)
    ldi   ZH, hi8(SRAM_IP_ADDR_DST)
    ldi   x1, IPV4_ADDR_LEN
    rcall MEMCPY

    /* Set Src and Dst UDP port {{{3 */
    ldi   ZL, lo8(SRAM_UDP_HEADER + UDP_HEADER_SRC_PORT)
    ldi   ZH, hi8(SRAM_UDP_HEADER + UDP_HEADER_SRC_PORT)
    ldi   x1, (IPV4_PORT_LEN * 2)
    rcall MEMCPY

    /* Set UDP packet length {{{3 */
    st    Z+, zero
    mov   t1, s2
    subi  t1, -(UDP_HEADER_LEN) /* UDP payload + UDP header */
    st    Z+, t1

    /* Prepare UDP packet {{{3 */
    ldi   YH, hi8(SRAM_COMM_PAYLOAD)
    ldi   YL, lo8(SRAM_COMM_PAYLOAD)
    ldi   ZH, hi8(SRAM_IPV4_PAYLOAD)
    ldi   ZL, lo8(SRAM_IPV4_PAYLOAD)
    mov   x1, s2
    rcall UDP_PREPARE_PACKET

    /* Prepare IPv4 header {{{3 */
    ldi   x1, (IPV4_DEFAULT_HEADER_LEN + UDP_HEADER_LEN)
    add   x1, s2
    rcall IPV4_PREPARE_DEFAULT_HEADER_20_40_BYTES

    /* Write IPv4 header into Ethernet module {{{3 */
    ldi   ZL, lo8(SRAM_IPV4_HEADER)
    ldi   ZH, hi8(SRAM_IPV4_HEADER)
    ldi   x1, IPV4_DEFAULT_HEADER_LEN
    rcall ETH_WRITE_Z_TO_TRANSMIT_BUFFER

    /* Write IPv4 payload into Ethernet module {{{3 */
    ldi   ZH, hi8(SRAM_IPV4_PAYLOAD)
    ldi   ZL, lo8(SRAM_IPV4_PAYLOAD)
    mov   x1, s2
    subi  x1, -(UDP_HEADER_LEN) /* UDP payload + UDP header */
    rcall ETH_WRITE_Z_TO_TRANSMIT_BUFFER
    /* }}}3 */
    /* Send the packet */
    rcall ETH_WRITE_BUFFER_PACKET_PAYLOAD_FINISH

IP_NOT_IN_ARP_TABLE:
    pop   YH
    pop   YL
SEND_PACKET_NEXT_ENTRY:
    dec   s1
    breq  SEND_PACKET_EXIT
    adiw  YL, COMM_DST_TBL_ENTRY
    rjmp  SEND_PACKET_FOR_ALL_ENTRIES

SEND_PACKET_EXIT:
    pop   s2
    pop   s1
    ret

/* Register an IP to send packages to {{{2 -------------------------------------
 * Use Round Robin to write destination entries into the table */
COMM_REGISTER_IP:
    /* Select the entry on the table to register using ROUND ROBIN */
    ldi   YL, lo8(SRAM_COMM_TABLE)
    ldi   YH, hi8(SRAM_COMM_TABLE)
    ldd   t1, Y + COMM_DST_TBL_LEN
    subi  t1, -(COMM_DST_TBL_ENTRY)
    cpi   t1, COMM_DST_TBL_LEN
    brne  0f
    clr   t1
0:  std   Y + COMM_DST_TBL_LEN, t1
    add   YL, t1
    adc   YH, zero

    /* From start of entry till COMM_DST_IPV4_TIME */
    ldi   t3, COMM_DST_IPV4_TIME
COMM_REGISTER_IP_LOOP:
    ETH_READ_NEXT_BYTE
    st    Y+, x4
    dec   t3
    brne  COMM_REGISTER_IP_LOOP
    ETH_READ_BUFFER_END

    ret

.end
