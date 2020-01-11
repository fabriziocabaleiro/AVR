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

/* TEXT {{{1 -----------------------------------------------------------------*/
.section .text

/* COMM init {{{2 --------------------------------------------------------------
 * Initialize communication */
COMM_INIT:
    ldi   zl, lo8(SRAM_COMM_TABLE)
    ldi   zh, hi8(SRAM_COMM_TABLE)
    ldi   a1, (COMM_DST_TBL_LEN + DHT11_PAYLOAD_LEN + MQ135_PAYLOAD_LEN + 1)
    rcall BZERO
    ret

/* Send a packet to IP registered in COMM table {{{2 ---------------------------
 * a1 is the UDP length */
SEND_PACKET:
    push  s1 /* Counter for all entries of comm table */
    push  s2 /* Save a1 to be used later within loop */

    ldi   s1, COMM_DST_TBL_SIZE
    mov   s2, a1
    ldi   xl, lo8(SRAM_COMM_TABLE)
    ldi   xh, hi8(SRAM_COMM_TABLE)
    /* For all entries of the COMM table */
SEND_PACKET_FOR_ALL_ENTRIES:
    ldi   a1, IPV4_ADDR_LEN
    clr   a2
    rcall R_MEMCMP
    breq  SEND_PACKET_NEXT_ENTRY
    push  xl
    push  xh
    /* Set MAC Dst pointer {{{3 */
    rcall ARP_GET_MAC_ADDR_PTR
    brne  IP_NOT_IN_ARP_TABLE
    sts   SRAM_ENC_MAC_DST_PTR + 0, a4
    sts   SRAM_ENC_MAC_DST_PTR + 1, a3

    /* Set Type/Len pointer {{{3 */
    ldi   t1, (EEPROM_TYPE_LEN_IPV4 - EEPROM_TYPE_LEN)
    sts   SRAM_ENC_TYPE_LEN_OFFSET, t1
    /* }}}3 */
    /* Write Ethernet Header */
    rcall ETH_WRITE_BUFFER_PACKET_HEADER

    /* Set Dst IP address {{{3 */
    ldi   zl, lo8(SRAM_IPV4_DST_IP_ADDR)
    ldi   zh, hi8(SRAM_IPV4_DST_IP_ADDR)
    ldi   a1, IPV4_ADDR_LEN
    rcall MEMCPY

    /* Set Src and Dst UDP port {{{3 */
    ldi   zl, lo8(SRAM_UDP_HEADER + UDP_HEADER_SRC_PORT)
    ldi   zh, hi8(SRAM_UDP_HEADER + UDP_HEADER_SRC_PORT)
    ldi   a1, (IPV4_PORT_LEN * 2)
    rcall MEMCPY

    /* Set UDP packet length {{{3 */
    st    z+, zero
    mov   t1, s2
    subi  t1, -(UDP_HEADER_LEN) /* UDP payload + UDP header */
    st    z+, t1

    /* Prepare UDP packet {{{3 */
    ldi   xh, hi8(SRAM_COMM_PAYLOAD)
    ldi   xl, lo8(SRAM_COMM_PAYLOAD)
    ldi   zh, hi8(SRAM_IPV4_PAYLOAD)
    ldi   zl, lo8(SRAM_IPV4_PAYLOAD)
    mov   a1, s2
    rcall UDP_PREPARE_PACKET

    /* Prepare IPv4 header {{{3 */
    ldi   a2, (IPV4_DEFAULT_HEADER_LEN + UDP_HEADER_LEN)
    add   a2, s2
    rcall IPV4_PREPARE_DEFAULT_HEADER_20_40_BYTES

    /* Write IPv4 header into Ethernet module {{{3 */
    ldi   zl, lo8(SRAM_IPV4_HEADER)
    ldi   zh, hi8(SRAM_IPV4_HEADER)
    ldi   a1, IPV4_DEFAULT_HEADER_LEN
    rcall ETH_WRITE_Z_TO_TRANSMIT_BUFFER

    /* Write IPv4 payload into Ethernet module {{{3 */
    ldi   zh, hi8(SRAM_IPV4_PAYLOAD)
    ldi   zl, lo8(SRAM_IPV4_PAYLOAD)
    mov   a1, s2
    subi  a1, -(UDP_HEADER_LEN) /* UDP payload + UDP header */
    rcall ETH_WRITE_Z_TO_TRANSMIT_BUFFER
    /* }}}3 */
    /* Send the packet */
    rcall ETH_WRITE_BUFFER_PACKET_PAYLOAD_FINISH

IP_NOT_IN_ARP_TABLE:
    pop   xh
    pop   xl
SEND_PACKET_NEXT_ENTRY:
    dec   s1
    breq  SEND_PACKET_EXIT
    adiw  xl, COMM_DST_TBL_ENTRY
    rjmp  SEND_PACKET_FOR_ALL_ENTRIES

SEND_PACKET_EXIT:
    pop   s2
    pop   s1
    ret

/* Register an IP to send packages to {{{2 -------------------------------------
 * Use Round Robin to write destination entries into the table */
COMM_REGISTER_IP:
    /* Select the entry on the table to register using ROUND ROBIN */
    ldi   zl, lo8(SRAM_COMM_TABLE)
    ldi   zh, hi8(SRAM_COMM_TABLE)
    ldd   t1, z + COMM_DST_TBL_LEN
    subi  t1, -(COMM_DST_TBL_ENTRY)
    cpi   t1, COMM_DST_TBL_LEN
    brne  0f
    clr   t1
0:  std   z + COMM_DST_TBL_LEN, t1
    add   zl, t1
    adc   zh, zero

    /* From start of entry till COMM_DST_IPV4_TIME */
    /* TODO: S_MEMCPY */
    ldi   t3, COMM_DST_IPV4_TIME
COMM_REGISTER_IP_LOOP:
    ETH_READ_NEXT_BYTE
    st    z+, a4
    dec   t3
    brne  COMM_REGISTER_IP_LOOP
    ETH_READ_BUFFER_END

    ret

.end
