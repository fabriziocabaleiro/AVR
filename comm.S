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
                                 TIMER_LEN +                                   \
                                 TIMER_LEN)
#define COMM_DST_TBL_SIZE       4
#define COMM_DST_TBL_LEN        (COMM_DST_TBL_ENTRY * COMM_DST_TBL_SIZE)

#define COMM_DST_IPV4_ADDR      0
#define COMM_DST_IPV4_SRC_PORT  (COMM_DST_IPV4_ADDR + IPV4_ADDR_LEN)
#define COMM_DST_IPV4_DST_PORT  (COMM_DST_IPV4_SRC_PORT + IPV4_PORT_LEN)
#define COMM_DST_IPV4_TIMER     (COMM_DST_IPV4_DST_PORT + IPV4_PORT_LEN)
#define COMM_DST_IPV4_TIME      (COMM_DST_IPV4_TIMER + TIMER_LEN)

/* Data offsets */
#define COMM_TABLE         0
#define COMM_RR_ITERATOR   (COMM_DST_TBL_LEN)
#define COMM_PAYLOAD       (COMM_RR_ITERATOR + 1)
/* GLOBAL {{{1 ---------------------------------------------------------------*/
.global COMM_SEND_PKT
.global COMM_REGISTER_IP
.global COMM_INIT

.global SRAM_COMM_PAYLOAD

/* DATA  {{{1 ----------------------------------------------------------------*/
.section .data
SRAM_COMM_DATA:
SRAM_COMM_TABLE:       .skip (COMM_DST_TBL_LEN)
SRAM_COMM_RR_ITERATOR: .skip 1
SRAM_COMM_PAYLOAD:     .skip (DHT11_PAYLOAD_LEN + MQ135_PAYLOAD_LEN)

/* TEXT {{{1 -----------------------------------------------------------------*/
.section .text

/* COMM_INIT {{{2 --------------------------------------------------------------
 * Initialize all COMM data to zero.
 * ---------------------------------------------------------------------------*/
COMM_INIT:
    ldi   zl, lo8(SRAM_COMM_DATA)
    ldi   zh, hi8(SRAM_COMM_DATA)
    ldi   a1, (COMM_DST_TBL_LEN + 1 + DHT11_PAYLOAD_LEN + MQ135_PAYLOAD_LEN)
    rcall BZERO
    ret

/* COMM_SEND_PKT {{{2 ----------------------------------------------------------
 * Send a packet to each registered IP Address in SRAM_COMM_TABLE.
 *
 * a1: UDP length.
 *
 * After routine:
 * a1: undefined.
 * ---------------------------------------------------------------------------*/
COMM_SEND_PKT:
    push  s1 /* Counter for all entries of comm table */
    push  s2 /* Save a1 to be used later within loop */

    ldi   s1, COMM_DST_TBL_SIZE
    mov   s2, a1
    ldi   xl, lo8(SRAM_COMM_TABLE)
    ldi   xh, hi8(SRAM_COMM_TABLE)
    /* For all entries of the COMM table */
0:  ldi   a1, IPV4_ADDR_LEN
    clr   a2
    rcall R_MEMCMP
    breq  1f /* Try next entry */
    push  xl
    push  xh
    /* Set MAC Dst pointer */
    rcall ARP_GET_MAC_ADDR_PTR
    brne  2f /* IP not in ARP table */

    ldi   zl, lo8(SRAM_ENC_DATA)
    ldi   zh, hi8(SRAM_ENC_DATA)
    std   z + ENC_MAC_DST_PTR + 0, a4
    std   z + ENC_MAC_DST_PTR + 1, a3

    /* Set Type/Len pointer */
    ldi   t1, (EEPROM_TYPE_LEN_IPV4 - EEPROM_TYPE_LEN)
    std   z + ENC_TYPE_LEN_OFFSET, t1

    /* Write Ethernet Header */
    rcall ETH_WRITE_BUFFER_PACKET_HEADER

    /* Set Dst IP address */
    ldi   zl, lo8(SRAM_IPV4_DST_IP_ADDR)
    ldi   zh, hi8(SRAM_IPV4_DST_IP_ADDR)
    ldi   a1, IPV4_ADDR_LEN
    rcall MEMCPY

    /* Set Src and Dst UDP port */
    ldi   zl, lo8(SRAM_UDP_HEADER + UDP_HEADER_SRC_PORT)
    ldi   zh, hi8(SRAM_UDP_HEADER + UDP_HEADER_SRC_PORT)
    ldi   a1, (IPV4_PORT_LEN * 2)
    rcall MEMCPY

    /* Set UDP packet length */
    st    z+, zero
    mov   t1, s2
    subi  t1, -(UDP_HEADER_LEN) /* UDP payload + UDP header */
    st    z+, t1

    /* Prepare UDP packet */
    ldi   xh, hi8(SRAM_COMM_PAYLOAD)
    ldi   xl, lo8(SRAM_COMM_PAYLOAD)
    ldi   zh, hi8(SRAM_IPV4_PAYLOAD)
    ldi   zl, lo8(SRAM_IPV4_PAYLOAD)
    rcall UDP_PREPARE_PACKET

    /* Prepare IPv4 header */
    ldi   a2, (IPV4_DEFAULT_HEADER_LEN + UDP_HEADER_LEN)
    add   a2, s2
    rcall IPV4_PREPARE_DEFAULT_HEADER_20_40_BYTES

    /* Write IPv4 header into Ethernet module */
    ldi   zl, lo8(SRAM_IPV4_HEADER)
    ldi   zh, hi8(SRAM_IPV4_HEADER)
    ldi   a1, IPV4_DEFAULT_HEADER_LEN
    rcall ETH_WRITE_Z_TO_TRANSMIT_BUFFER

    /* Write IPv4 payload into Ethernet module */
    ldi   zh, hi8(SRAM_IPV4_PAYLOAD)
    ldi   zl, lo8(SRAM_IPV4_PAYLOAD)
    mov   a1, s2
    subi  a1, -(UDP_HEADER_LEN) /* UDP payload + UDP header */
    rcall ETH_WRITE_Z_TO_TRANSMIT_BUFFER

    /* Send the packet */
    rcall ETH_WRITE_BUFFER_PACKET_PAYLOAD_FINISH

2:  pop   xh
    pop   xl
1:  dec   s1
    breq  9f /* All entries were check, break */
    adiw  xl, COMM_DST_TBL_ENTRY
    rjmp  0b /* For all entries */

9:  pop   s2
    pop   s1
    ret

/* COMM_REGISTER_IP {{{2 -------------------------------------------------------
 * Register an IP Address to send packages to.
 * Use Round Robin to write destination entries into the table.
 * 
 * This routine will copy from SPI to SRAM_COMM_TABLE until COMM_DST_IPV4_TIME
 * ---------------------------------------------------------------------------*/
COMM_REGISTER_IP:
    /* Select the entry on the table to register using Round Robin */
    ldi   zl, lo8(SRAM_COMM_TABLE)
    ldi   zh, hi8(SRAM_COMM_TABLE)
    ldd   t1, z + COMM_RR_ITERATOR - COMM_TABLE
    subi  t1, -(COMM_DST_TBL_ENTRY)
    cpi   t1, COMM_DST_TBL_LEN
    brne  0f
    clr   t1
0:  std   z + COMM_RR_ITERATOR - COMM_TABLE, t1
    add   zl, t1
    adc   zh, zero

    /* From start of entry till COMM_DST_IPV4_TIME */
    ldi   a1, COMM_DST_IPV4_TIME
    rcall S_MEMCPY

    ret

.end
