/* vim: set filetype=S foldmethod=marker: */
/* INCLUDES {{{1 */
.NOLIST
#include <avr/io.h>
#include <avr/interrupt.h>
#include "defs.h"
#include "dhcp.h"
#include "ipv4.h"
#include "enc28j60.h"
#include "timer.h"
#include "eeprom_data.h"
#include "macros.S"
.LIST

/* MACORS {{{1 ---------------------------------------------------------------*/
#define DHCP_TIMER_ANDI         0x03 /* TODO: set back to 7 ? */
#define DHCP_DOMAIN_SERVER_LEN  8

/* Bit 7 used for counter underflow flag */
#if (EEPROM_DHCP_TIMERS - 8) >= 127
#   error "Optimization for EEPROM_DHCP_TIMERS won't work"
#endif

/* Define offsets to use ldd/std instead of lds/sts */
#define DHCP_SERVER_IP_ADDR         0
#define DHCP_XID_LAST_BYTE          (DHCP_SERVER_IP_ADDR + DHCP_OPTION_DHCP_SERVER_ID_LEN)
#define DHCP_ADDRESS_TIME           (DHCP_XID_LAST_BYTE  + 1)
#define DHCP_SECONDS                (DHCP_ADDRESS_TIME   + DHCP_OPTION_ADDRESS_TIME_LEN)
#define DHCP_SUBNET_MASK            (DHCP_SECONDS        + DHCP_OPTION_ADDRESS_TIME_LEN)
#define DHCP_DOMAIN_SERVER          (DHCP_SUBNET_MASK    + DHCP_OPTION_SUBNET_MASK_LEN)
#define DHCP_STATE                  (DHCP_DOMAIN_SERVER  + DHCP_DOMAIN_SERVER_LEN)
#define DHCP_TIMER_SUBTRAHEND_PTR_L (DHCP_STATE          + 1)
/* GLOBAL {{{1 ---------------------------------------------------------------*/
.global DHCP_HANDLE_PKT
.global DHCP_INIT
.global DHCP

/* DATA  {{{1 ----------------------------------------------------------------*/
.section .data
SRAM_DHCP_DATA:
SRAM_DHCP_SERVER_IP_ADDR:         .skip DHCP_OPTION_DHCP_SERVER_ID_LEN
SRAM_DHCP_XID_LAST_BYTE:          .skip 1
SRAM_DHCP_ADDRESS_TIME:           .skip DHCP_OPTION_ADDRESS_TIME_LEN
SRAM_DHCP_SECONDS:                .skip DHCP_OPTION_ADDRESS_TIME_LEN
SRAM_DHCP_SUBNET_MASK:            .skip DHCP_OPTION_SUBNET_MASK_LEN
SRAM_DHCP_DOMAIN_SERVER:          .skip DHCP_DOMAIN_SERVER_LEN
/* SRAM_DHCP_STATE must be right before SRAM_DHCP_TIMER_SUBTRAHEND_PTR_L */
SRAM_DHCP_STATE:                  .skip 1
/* Pointer to T1/T2 subtrahend. Bit 7 used as flag */
SRAM_DHCP_TIMER_SUBTRAHEND_PTR_L: .skip 1

/* TEXT {{{1 -----------------------------------------------------------------*/
.section .text

/* DHCP {{{2 -------------------------------------------------------------------
 * This routine is called periodically
 * This routine checks the current DHCP state, then sends the required packages
 * in order to have a valid IP address. */
DHCP:
    push  xl
    push  xh
    push  yl
    push  yh
    push  zl
    push  zh
    push  s1 /* Pkt size low */
    push  s2 /* Pkt size high */
    push  s3 /* DHCP state */
    /* Set Y to start of dhcp data section */
    ldi   yl, lo8(SRAM_DHCP_DATA)
    ldi   yh, hi8(SRAM_DHCP_DATA)
    /* Load common packet size {{{3
     * All DHCP packages but DHCPREQUEST will have the same packet size */
    ldi   t1, lo8(DHCP_IP_COMMON_PKT_SIZE)
    mov   s1, t1
    ldi   t1, hi8(DHCP_IP_COMMON_PKT_SIZE)
    mov   s2, t1
    /* Switch on SRAM_DHCP_STATE {{{3 */
    /* Load current DHCP state */
    ldd   s3, y + DHCP_STATE
    sbrc  s3, DHCP_STATE_INIT
    rjmp  DHCP_IN_INIT_STATE
    sbrc  s3, DHCP_STATE_SELECTING
    rjmp  DHCP_IN_SELECTING_STATE
    sbrc  s3, DHCP_STATE_REQUESTING
    rjmp  DHCP_IN_REQUESTING_STATE
    sbrc  s3, DHCP_STATE_BOUND
    rjmp  DHCP_IN_BOUND_STATE
    sbrc  s3, DHCP_STATE_RENEWING
    rjmp  DHCP_IN_RENEWING_STATE
    sbrc  s3, DHCP_STATE_REBIDING
    rjmp  DHCP_IN_REBIDING_STATE
    sbrc  s3, DHCP_STATE_INIT_REBOOT
    rjmp  DHCP_IN_INIT_REBOOT_STATE
    sbrc  s3, DHCP_STATE_REBOOTING
    rjmp  DHCP_IN_REBOOTING_STATE
    /* We expect any of the previous RJMPs to be executed, so, we never should
     * fall over this line, but, if we do, then it would be treat as init state,
     * which seems sensible */
DHCP_IN_INIT_STATE: /* {{{3 */
    /* Try to send a REQUEST every 16 seconds
     * At this point, SRAM_DHCP_TIMER_SUBTRAHEND_PTR_L is not used, then we can
     * use it to hold a counter and send request every N seconds */
    rcall DHCP_WAITING_IN_STATE
    brne  DHCP_IN_INIT_STATE_EXIT

    /* In this state we send a discover and jump directly to selecting state. */
    rcall DHCP_XID_INCREMENT
    rcall DHCP_SEND
    ldi   t1, (1 << DHCP_STATE_SELECTING)
    std   y + DHCP_STATE, t1
DHCP_IN_INIT_STATE_EXIT:
    rjmp  DHCP_EXIT_SUCCESS

DHCP_IN_SELECTING_STATE: /* {{{3 */
    /* In selecting state we wait to receive an offer, when the server sends the
     * offer, the dhcp handler will jump to requesting state.
     * If an offer doesn't arrive in some time, then, go back to init state.
     */
    rcall DHCP_WAITING_IN_STATE
    brne  KEEP_WAITING_OFFER
    ldi   t1, (1 << DHCP_STATE_INIT)
    std   y + DHCP_STATE, t1
KEEP_WAITING_OFFER:
    rjmp  DHCP_EXIT_SUCCESS

DHCP_IN_REQUESTING_STATE: /* {{{3 */
    /* Request size is different from common size */
    adiw  s1, DHCP_REQUEST_EXTRA_OPS_SIZE
    rcall DHCP_SEND
    rjmp  DHCP_EXIT_SUCCESS

DHCP_IN_BOUND_STATE: /* {{{3 */
    rcall DHCP_TIMERS
    brcc  DHCP_IN_BOUND_STATE_EXIT
    /* Change DHCP state */
    ldi   t1, (1 << DHCP_STATE_RENEWING)
    std   y + DHCP_STATE, t1
    mov   s3, t1
    rjmp  DHCP_TIMER_LAP_COMPLETED
DHCP_IN_BOUND_STATE_EXIT:
    rjmp  DHCP_EXIT_SUCCESS

DHCP_IN_RENEWING_STATE: /* DHCP_IN_REBIDING_STATE {{{3 */
DHCP_IN_REBIDING_STATE:
    /* read: DHCPREQUEST generated during RENEWING state (rfc2131) */
    rcall DHCP_TIMERS
    brcc  DHCP_IN_RENEWING_STATE_EXIT
DHCP_TIMER_LAP_COMPLETED:
    rcall DHCP_XID_INCREMENT
    rcall DHCP_SEND
    /* Check if x still pointing to T1 */
    ldd   t1, y + DHCP_TIMER_SUBTRAHEND_PTR_L
    cbr   t1, (1 << DHCP_TIMER_LAP)
    cpi   t1, EEPROM_DHCP_TIMERS_T2
    brlo  STILL_IN_T1
    cpi   t1, EEPROM_DHCP_TIMERS_END
    brlo  STILL_IN_T2
    /* Beyond T2, which means no more timers, go to DHCP init state */
    ldi   t1, (1 << DHCP_STATE_INIT)
    std   y + DHCP_STATE, t1
    rjmp  DHCP_EXIT_SUCCESS
STILL_IN_T2: /* change state */
    ldi   t1, (1 << DHCP_STATE_REBIDING)
    std   y + DHCP_STATE, t1
STILL_IN_T1: /* nothing to do */
DHCP_IN_RENEWING_STATE_EXIT:
    rjmp  DHCP_EXIT_SUCCESS

DHCP_IN_INIT_REBOOT_STATE: /* {{{3 */
    rcall DHCP_XID_INCREMENT
    rcall DHCP_SEND
    ldi   t1, (1 << DHCP_STATE_REBOOTING)
    std   y + DHCP_STATE, t1
    rjmp  DHCP_EXIT_SUCCESS

DHCP_IN_REBOOTING_STATE: /* {{{3 */
    rcall DHCP_WAITING_IN_STATE
    brne  DHCP_IN_REBOOTING_STATE_EXIT
    ldi   t1, (1 << DHCP_STATE_INIT)
    std   y + DHCP_STATE, t1
DHCP_IN_REBOOTING_STATE_EXIT:
    rjmp  DHCP_EXIT_SUCCESS /* }}}3 */

DHCP_EXIT_SUCCESS:
    pop   s3
    pop   s2
    pop   s1
    pop   zh
    pop   zl
    pop   yh
    pop   yl
    pop   xh
    pop   xl
    ret

/* DHCP_INIT {{{2 --------------------------------------------------------------
 * This routine initialize DHCP */
DHCP_INIT:
    /* SRAM_DHCP_XID_LAST_BYTE will have random initial value */
    /* Check if our current IP in the EEPROM was set */
    ldi   xl, lo8(EEPROM_IP_ADDR)
    ldi   xh, hi8(EEPROM_IP_ADDR)
    ldi   t3, IPV4_ADDR_LEN
0:  rcall EEPROM_READ_N_INC
    tst   a4
    brne  0f /* a4 != zero -> valid IP address */
    dec   t3
    brne  0b
    /* IP address is 0.0.0.0 (invalid IP) */
    ldi   t1, (1 << DHCP_STATE_INIT)
    rjmp  1f
0:  ldi   t1, (1 << DHCP_STATE_INIT_REBOOT)
1:  sts   SRAM_DHCP_STATE, t1
    ret

/* DHCP SEND packet {{{2 -----------------------------------------------------*/
DHCP_SEND:
    DEBUG(PRINT_STR STR_DHCP_SEND_START)
    DEBUG(rcall PRINT_STATE)
    /* Ethernet Header {{{3 */
    ldi   t2, (1 << ENC_MAC_DST_PTR_BROADCAST_BIT)
    sts   SRAM_ENC_MAC_DST_PTR, t2
    ldi   t2, (EEPROM_TYPE_LEN_IPV4 - EEPROM_TYPE_LEN)
    sts   SRAM_ENC_TYPE_LEN_OFFSET, t2
    rcall ETH_WRITE_BUFFER_PACKET_HEADER
    /* }}}3 */
    rcall ETH_SET_LISTEN_ON_SPI
    /* IPv4 Header {{{3
     * This header has src as 0.0.0.0, dst as 255.255.255.255, checksum and
     * total length have to be setup
     */
    /* Read default IPv4 header plus part of UDP header from EEPROM {{{4 */
#if EEPROM_IP_HEADER_END != EEPROM_UDP_DHCP_PORT
#   error "Optimization requires EEPROM_IP_HEADER_END == EEPROM_UDP_DHCP_PORT"
#endif
    ldi   zl, lo8(SRAM_IPV4_HEADER)
    ldi   zh, hi8(SRAM_IPV4_HEADER)
    /* Write to SRAM, so total length and checksum can be set */
    ldi   xl, lo8(EEPROM_IP_HEADER)
    ldi   xh, hi8(EEPROM_IP_HEADER)
    ldi   a1, (EEPROM_UDP_DHCP_PORT_END - EEPROM_IP_HEADER)
    rcall E_MEMCPY
    /* Set z back to SRAM_IPV4_HEADER */
    sbiw  zl, (EEPROM_UDP_DHCP_PORT_END - EEPROM_IP_HEADER)

    /* Set non default IPv4 header fields {{{4 */
    /* IP TOTAL LENGTH {{{5 */
    std   z + (IPV4_TOTAL_LENGTH + 0), s2
    std   z + (IPV4_TOTAL_LENGTH + 1), s1

    /* Src and Dst IP addresses for RENEWING {{{5 */
    sbrs  s3, DHCP_STATE_RENEWING
    rjmp  DEFAULT_SRC_DST_ADDRESSES
    /* Copy Src IP address */
    adiw  zl, IPV4_SRC_ADDR
    ldi   a1, IPV4_ADDR_LEN
    ldi   xl, lo8(EEPROM_IP_ADDR)
    ldi   xh, hi8(EEPROM_IP_ADDR)
    rcall E_MEMCPY
    /* Copy DHCP server IP address */
    ldi   xl, lo8(SRAM_DHCP_SERVER_IP_ADDR)
    ldi   xh, hi8(SRAM_DHCP_SERVER_IP_ADDR)
    rcall MEMCPY
    /* Set z back to SRAM_IPV4_HEADER */
    sbiw  zl, (IPV4_ADDR_LEN * 2)
DEFAULT_SRC_DST_ADDRESSES:

    /* Internet Checksum {{{5 */
    ldi   a1, (EEPROM_IP_HEADER_END - EEPROM_IP_HEADER)
    ldi   a2, 0
    rcall INTERNET_CHECKSUM_RFC1071
    std   z + (IPV4_H_CHECKSUM + 0), a3
    std   z + (IPV4_H_CHECKSUM + 1), a4

    /* Transmit IPv4 Header plus part of UDP {{{4 */
    ldi   a1, (EEPROM_UDP_DHCP_PORT_END - EEPROM_IP_HEADER)
    rcall ETH_WRITE_Z_TO_TRANSMIT_BUFFER
    rcall ETH_SET_LISTEN_ON_SPI

    /* UDP Header {{{3 */
    /* SRC/DST already written */
    /* Write UDP Length {{{4 */
    /* DHCP PKT SIZE was set to IP size, so, subtract DHCP_IP_HEADER_SIZE to
     * get the UDP size */
    sbiw  s1, DHCP_IP_HEADER_SIZE
    mov   a1, s2
    rcall SPI_MASTER_TRANSMIT
    mov   a1, s1
    rcall SPI_MASTER_TRANSMIT

    /* UDP Checksum, Zero for ignore {{{4 */
    ldi   a1, 2
    rcall SPI_MASTER_TRANSMIT_ZEROS

    /* DHCP Body {{{3 */
    /* Write first 8 bytes: OP, HTYPE, HLEN, HOPS AND XID (3 of 4 bytes) {{{4 */
    ldi   xl, lo8(EEPROM_DHCP_HEADER)
    ldi   xh, hi8(EEPROM_DHCP_HEADER)
    ldi   a1, (EEPROM_DHCP_HEADER_END - EEPROM_DHCP_HEADER)
    rcall SPI_EEPROM_TRANSMIT

    /* Last byte of XID {{{4 */
    ldd   a1, y + DHCP_XID_LAST_BYTE
    DEBUG(rcall PRINT_CURRENT_XID)
    rcall SPI_MASTER_TRANSMIT

    /* set SECS and FLAGS to Zero {{{4 */
    ldi   a1, 4
    rcall SPI_MASTER_TRANSMIT_ZEROS

    /* CIADDR {{{4
    Field      DHCPDISCOVER          DHCPREQUEST           DHCPDECLINE,
               DHCPINFORM                                  DHCPRELEASE
    -----      ------------          -----------           -----------
    'ciaddr'   0 (DHCPDISCOVER)      0 or client's         0 (DHCPDECLINE)
               client's              network address       client's network
               network address       (BOUND/RENEW/REBIND)  address
               (DHCPINFORM)                                (DHCPRELEASE)
    */
    ldi   xl, lo8(EEPROM_IP_ADDR)
    ldi   xh, hi8(EEPROM_IP_ADDR)
    ldi   t3, IPV4_ADDR_LEN
0:  clr   a4
    /* IP ADDR is zero for DISCOVER, as it is unset, then, safe to read from
     * EEPROM. At request we already wrote the offer to EEPROM, so, don't use
     * EEPROM value, then, at BOUND/RENEW/REBIND use EEPROM value.
     * Ignoring DHCPDECLINE as logic for declining is not implemented */
#if EEPROM_IP_ADDR_END != EEPROM_MAC_ADDR
    /* if the code reduction optimization is off, then, optimize power by
     * skipping eeprom read, else, do eeprom read to increment x as required by
     * CHADDR */
    /* TODO: REVIEW */
    sbrs  s3, DHCP_STATE_REQUESTING /* right after DHCPOFFER */
    rcall EEPROM_READ_N_INC
#else
    rcall EEPROM_READ_N_INC
    sbrs  s3, DHCP_STATE_REQUESTING /* right after DHCPOFFER */
#endif
    mov   a1, a4
    rcall SPI_MASTER_TRANSMIT
    dec   t3
    brne  0b

    /* YIADDR, SIADDR and GIADDR to Zero  {{{4 */
    ldi   a1, 12
    rcall SPI_MASTER_TRANSMIT_ZEROS

    /* CHADDR, write own MAC {{{4 */
#if EEPROM_IP_ADDR_END != EEPROM_MAC_ADDR
#   warning "Optimization expecting EEPROM_IP_ADDR_END == EEPROM_MAC_ADDR"
    /* This two instructions can be avoided if
     * EEPROM_IP_ADDR_END == EEPROM_MAC_ADDR
     * and no modifications to x are done after writing CIADDR */
    ldi   xl, lo8(EEPROM_MAC_ADDR)
    ldi   xh, hi8(EEPROM_MAC_ADDR)
#endif
    ldi   a1, MAC_ADDR_LEN
    rcall SPI_EEPROM_TRANSMIT

    /* header has 16 bytes for mac, as using only 6, there are 10 bytes to {{{4
     * write as zero, then we have 192 bytes of zero (option overload/BOOTS
     * legacy) */
    ldi   a1, 202
    rcall SPI_MASTER_TRANSMIT_ZEROS

    /* Write magic cookie and beginning of option msg {{{4 */
    ldi   xl, lo8(EEPROM_DHCP_MAGIC_COOKIE)
    ldi   xh, hi8(EEPROM_DHCP_MAGIC_COOKIE)
#if EEPROM_DHCP_MAGIC_COOKIE_END != EEPROM_DHCP_OPTION_MSG_N_LEN
#   error "Optimization requires EEPROM_DHCP_MAGIC_COOKIE_END == EEPROM_DHCP_OPTION_MSG_N_LEN"
#endif
    ldi   a1, (EEPROM_DHCP_OPTION_MSG_N_LEN_END - EEPROM_DHCP_MAGIC_COOKIE)
    rcall SPI_EEPROM_TRANSMIT

    /* DHCP Options {{{4 */
    /* DHCP MSG TYPE {{{5 */
    /* MSG type and length is written from EEPROM */
    /* all messages from client but discover will have a request msg type */
    ldi   a1, DHCP_OPTION_DHCP_MSG_TYPE_DHCP_DISCOVER
    sbrs  s3, DHCP_STATE_INIT
    ldi   a1, DHCP_OPTION_DHCP_MSG_TYPE_DHCP_REQUEST
    rcall SPI_MASTER_TRANSMIT

    /* DHCP packets that don't require more options {{{5
     * BEWARE s3 gets modified here */
    andi  s3, (1 << DHCP_STATE_INIT)        | \
              (1 << DHCP_STATE_INIT_REBOOT) | \
              (1 << DHCP_STATE_REBOOTING)   | \
              (1 << DHCP_STATE_RENEWING)    | \
              (1 << DHCP_STATE_REBIDING)
    brne  DHCP_END_OP

    /* DHCP Request options {{{5 */
#if EEPROM_DHCP_REQUEST_OPS_END != EEPROM_IP_ADDR
#   error "DHCP request required EEPROM_DHCP_REQUEST_OPS_END == EEPROM_IP_ADDR"
#endif
    /* Hostname and IP address {{{6 */
    ldi   xl, lo8(EEPROM_DHCP_REQUEST_OPS)
    ldi   xh, hi8(EEPROM_DHCP_REQUEST_OPS)
    ldi   a1, (EEPROM_IP_ADDR_END - EEPROM_DHCP_REQUEST_OPS)
    rcall SPI_EEPROM_TRANSMIT

    /* DHCP server IP address {{{6 */
    ldi   a1, DHCP_OPTION_DHCP_SERVER_ID
    rcall SPI_MASTER_TRANSMIT
    ldi   a1, DHCP_OPTION_DHCP_SERVER_ID_LEN
    rcall SPI_MASTER_TRANSMIT

    ldi   zl, lo8(SRAM_DHCP_SERVER_IP_ADDR)
    ldi   zh, hi8(SRAM_DHCP_SERVER_IP_ADDR)
    ldi   a1, DHCP_OPTION_DHCP_SERVER_ID_LEN
    rcall ETH_WRITE_Z_TO_TRANSMIT_BUFFER
    rcall ETH_SET_LISTEN_ON_SPI

DHCP_END_OP: /* End Options */
    ldi   a1, DHCP_OPTION_END
    rcall SPI_MASTER_TRANSMIT
    /* }}}3 */
    ETH_END_LISTEN_ON_SPI
    rcall ETH_WRITE_BUFFER_PACKET_PAYLOAD_FINISH
    ret

/* Handle dhcp packet {{{2 -----------------------------------------------------
 * BEWARE, EXPECTING ETH MODULE LISTENING TO SPI */
DHCP_HANDLE_PKT:
    push xl
    push xh

    DEBUG(PRINT_STR_SAFE STR_DHCP_HANDLE_START)
    /* Check OP, HTYPE, HLEN, HOPS and XID  {{{3 */
    ETH_READ_NEXT_BYTE
    cpi   a4, DHCP_OP_BOOTREPLY
    brne  DHCP_HANDLE_EXIT_SUCCESS

    /* Compare beginning of header */
    ldi   xl, lo8(EEPROM_DHCP_HEADER + 1)
    ldi   xh, hi8(EEPROM_DHCP_HEADER + 1)
    ldi   a1, 6
    rcall SE_MEMCMP
    brne  DHCP_HANDLE_EXIT_SUCCESS

    /* Check last byte of the XID */
    ETH_READ_NEXT_BYTE
    lds   t1, SRAM_DHCP_XID_LAST_BYTE
    DEBUG(rcall PRINT_INCOMING_N_EXPECTED_XID)
    cp    t1, a4
    brne  DHCP_HANDLE_EXIT_SUCCESS

    /* Jump to YIADDR {{{3 */
#if USE_MOVE_RDPT
    ETH_READ_BUFFER_END
    ldi   a1, 0
    ldi   a2, 8 /* SECS + FLAGS + CIADDR */
    rcall ETH_MOVE_RDPT
    rcall ETH_READ_BUFFER_START
#else
    ldi   a1, 8
    rcall SPI_MASTER_TRANSMIT_ZEROS
#endif

    /* Read offered IP and write it into EEPROM {{{3 */
    ldi   t3, IPV4_ADDR_LEN
    ldi   xl, lo8(EEPROM_IP_ADDR)
    ldi   xh, hi8(EEPROM_IP_ADDR)
UPDATE_EEPROM_IP_ADDR:
    ETH_READ_NEXT_BYTE
    mov   a1, a4
    rcall EEPROM_WRITE_N_INC
    dec   t3
    brne  UPDATE_EEPROM_IP_ADDR

    /* Jump from siaddr ip addr to magic cookie {{{3 */
#if USE_MOVE_RDPT
    ETH_READ_BUFFER_END
    ldi   a1, 0
    ldi   a2, 216
    rcall ETH_MOVE_RDPT
    rcall ETH_READ_BUFFER_START
#else
    ldi   a1, 216
    rcall SPI_MASTER_TRANSMIT_ZEROS
#endif

    /* Check magic cookie {{{3 */
    ldi   xl, lo8(EEPROM_DHCP_MAGIC_COOKIE)
    ldi   xh, hi8(EEPROM_DHCP_MAGIC_COOKIE)
    ldi   a1, (EEPROM_DHCP_MAGIC_COOKIE_END - EEPROM_DHCP_MAGIC_COOKIE)
    rcall SE_MEMCMP
    brne  DHCP_HANDLE_EXIT_FAILURE
    /* Jump to start reading options (skipping exit block) */
    rjmp  START_READING_DHCP_OPTIONS

DHCP_HANDLE_EXIT_FAILURE:
    DEBUG(PRINT_STR_SAFE STR_FAILURE)

DHCP_HANDLE_EXIT_SUCCESS: /* {{{3 */
    ETH_READ_BUFFER_END
    DEBUG(rcall PRINT_VARIABLES)
    pop   xh
    pop   xl
    ret

START_READING_DHCP_OPTIONS: /* {{{3 */
KEEP_READING_DHCP_OPTIONS:
    ldi   xl, lo8(SRAM_DHCP_DATA)
    ldi   xh, hi8(SRAM_DHCP_DATA)
    ETH_READ_NEXT_BYTE
    /* Check if end of options */
    cpi   a4, DHCP_OPTION_END
    breq  DHCP_HANDLE_EXIT_SUCCESS
    /* Check if padding, which doesn't have length. Go to read next byte */
    cpi   a4, DHCP_OPTION_PAD
    breq  KEEP_READING_DHCP_OPTIONS
    /* DHCP message {{{4 */
    cpi   a4, DHCP_OPTION_DHCP_MSG_TYPE
    brne  TRY_DHCP_OPTIONS
    /* DHCP message, we care about dhcp offer */
    ETH_READ_NEXT_BYTE /* read size of option, must be 1 */
    ETH_READ_NEXT_BYTE
    adiw  xl, DHCP_STATE
    cpi   a4, DHCP_OPTION_DHCP_MSG_TYPE_DHCP_OFFER
    brne  TRY_DHCP_ACK
    ldi   t1, (1 << DHCP_STATE_REQUESTING)
    st    x, t1
    rjmp  KEEP_READING_DHCP_OPTIONS
TRY_DHCP_ACK:
    cpi   a4, DHCP_OPTION_DHCP_MSG_TYPE_DHCP_ACK
    brne  KEEP_READING_DHCP_OPTIONS
    DEBUG(PRINT_STR_SAFE STR_OPT_ACK)
    ldi   t1, (1 << DHCP_STATE_BOUND)
    st    x+, t1
    ldi   t1, (1 << DHCP_TIMER_LAP) | EEPROM_DHCP_TIMERS
    st    x, t1
    rjmp  KEEP_READING_DHCP_OPTIONS
    /* Read generic options that don't require much processing */
TRY_DHCP_OPTIONS:
    /* Server ID */
    cpi   a4, DHCP_OPTION_DHCP_SERVER_ID
    brne  0f
    ldi   t1, DHCP_OPTION_DHCP_SERVER_ID_LEN
    rjmp  1f
    /* Address time */
0:  cpi   a4, DHCP_OPTION_ADDRESS_TIME
    brne  0f
    adiw  xl, DHCP_ADDRESS_TIME
    ldi   t1, DHCP_OPTION_ADDRESS_TIME_LEN
    rjmp  1f
    /* Subnet mask */
0:  cpi   a4, DHCP_OPTION_SUBNET_MASK
    brne  0f
    adiw  xl, DHCP_SUBNET_MASK
    ldi   t1, DHCP_OPTION_SUBNET_MASK_LEN
    rjmp  1f
    /* Domain server */
0:  cpi   a4, DHCP_OPTION_DOMAIN_SERVER
    brne  0f
    adiw  xl, DHCP_DOMAIN_SERVER
    ldi   t1, DHCP_DOMAIN_SERVER_LEN
    rjmp  1f
    /* Read option, but don't store it */
0:  ldi   t1, 0
1:  ETH_READ_NEXT_BYTE /* Read length */
    mov   t3, a4
    clr   t2 /* Counts from 0 to length */
0:  ETH_READ_NEXT_BYTE
    cp    t2, t1
    inc   t2
    brsh  1f /* If t2 >= t1, then skip modifying SRAM */
    st    x+, a4
1:  dec   t3
    brne  0b
    rjmp  KEEP_READING_DHCP_OPTIONS

/* Timer handlers {{{2 ---------------------------------------------------------
 * Carry will be set when timer expires */
DHCP_TIMERS:
    ldd   xl, y + DHCP_TIMER_SUBTRAHEND_PTR_L
    sbrs  xl, DHCP_TIMER_LAP
    rjmp  DHCP_COUNTDOWN
DHCP_SET_COUNTDOWN:
    /* Clear lap bit, increment pointer by 1 */
    cbr   xl, (1 << DHCP_TIMER_LAP)
    std   y + DHCP_TIMER_SUBTRAHEND_PTR_L, xl

    /* Copy lease time to dhcp seconds */
    ldi   xl, lo8(SRAM_DHCP_ADDRESS_TIME)
    ldi   xh, hi8(SRAM_DHCP_ADDRESS_TIME)
    ldi   zl, lo8(SRAM_DHCP_SECONDS)
    ldi   zh, hi8(SRAM_DHCP_SECONDS)
    ldi   a1, 4
    rcall MEMCPY

DHCP_COUNTDOWN:
    /* Subtract the value pointed by x in the EEPROM to the uint32 big endian
     * value in SRAM_DHCP_SECONDS */
    /* Loading 1 address beyond because of ld with pre-decrement */
    /* Could be replaced with SUB_UINT32_BIG_ENDIAN, but as subtraction not
     * needed anywhere else, then just do it here */
    ldi   zl, lo8(SRAM_DHCP_SECONDS + 4)
    ldi   zh, hi8(SRAM_DHCP_SECONDS + 4)
    ldi   t3, 4
    clr   xh
    rcall EEPROM_READ_N_INC
    clc
0:  ld    t1, -z
    sbc   t1, a4
    clr   a4
    st    z, t1
    dec   t3
    brne  0b
    /* After subtraction, Check if underflow, if so, set DHCP_TIMER_LAP. DHCP
     * packet will be sent and next time DHCP_TIMERS is called, the timer will
     * be reset */
    brcc  DHCP_TIMERS_EXIT
    ldd   t1, y + DHCP_TIMER_SUBTRAHEND_PTR_L
    inc   t1
    sbr   t1, (1 << DHCP_TIMER_LAP)
    std   y + DHCP_TIMER_SUBTRAHEND_PTR_L, t1
DHCP_TIMERS_EXIT:
    ret

/* Simple counter to add waiting time {{{2 -------------------------------------
 * Beware that SRAM_DHCP_TIMER_SUBTRAHEND_PTR_L may be used uninitialized, but
 * should not be a problem */ 
DHCP_WAITING_IN_STATE:
    ldd   t1, y + DHCP_TIMER_SUBTRAHEND_PTR_L
    inc   t1
    std   y + DHCP_TIMER_SUBTRAHEND_PTR_L, t1
    andi  t1, DHCP_TIMER_ANDI
    ret

/* Increment XID LSB {{{2 ----------------------------------------------------*/
DHCP_XID_INCREMENT:
    ldd   t1, y + DHCP_XID_LAST_BYTE
    inc   t1
    std   y + DHCP_XID_LAST_BYTE, t1
    ret

/* Debugging functionality {{{2 ----------------------------------------------*/
#ifndef NDEBUG
PRINT_CURRENT_XID:
    DEBUG_PUSH
    PRINT_STR STR_LOCAL_XID
    PRINT_REG a1
    PRINT_NEWLINE
    DEBUG_POP
    ret

PRINT_INCOMING_N_EXPECTED_XID:
    DEBUG_PUSH
    PRINT_STR STR_LOCAL_XID
    PRINT_REG t1
    PRINT_NEWLINE
    PRINT_STR STR_INCOMING_XID
    PRINT_REG a4
    PRINT_NEWLINE
    DEBUG_POP
    ret

PRINT_STATE:
    DEBUG_PUSH
    PRINT_STR STR_STATE
    ldd   a1, y + DHCP_STATE
    PRINT_REG a1
    PRINT_NEWLINE
    DEBUG_POP
    ret

PRINT_VARIABLES:
    DEBUG_PUSH
    PRINT_STR STR_DHCP_VARS
    ldi   xl, lo8(SRAM_DHCP_DATA)
    ldi   xh, hi8(SRAM_DHCP_DATA)

    PRINT_STR STR_DHCP_SERVER_IP_ADDR
    ldi   t3, DHCP_OPTION_DHCP_SERVER_ID_LEN
0:  ld    a1, x+
    rcall UART_TRANSMIT_HEX
    dec   t3
    brne  0b
    PRINT_NEWLINE

    PRINT_STR STR_DHCP_XID_LAST_BYTE
    ldi   t3, 1
0:  ld    a1, x+
    rcall UART_TRANSMIT_HEX
    dec   t3
    brne  0b
    PRINT_NEWLINE

    PRINT_STR STR_DHCP_ADDRESS_TIME
    ldi   t3, DHCP_OPTION_ADDRESS_TIME_LEN
0:  ld    a1, x+
    rcall UART_TRANSMIT_HEX
    dec   t3
    brne  0b
    PRINT_NEWLINE

    PRINT_STR STR_DHCP_SECONDS
    ldi   t3, DHCP_OPTION_ADDRESS_TIME_LEN
0:  ld    a1, x+
    rcall UART_TRANSMIT_HEX
    dec   t3
    brne  0b
    PRINT_NEWLINE

    PRINT_STR STR_DHCP_SUBNET_MASK
    ldi   t3, DHCP_OPTION_SUBNET_MASK_LEN
0:  ld    a1, x+
    rcall UART_TRANSMIT_HEX
    dec   t3
    brne  0b
    PRINT_NEWLINE

    PRINT_STR STR_DHCP_DOMAIN_SERVER
    ldi   t3, DHCP_DOMAIN_SERVER_LEN
0:  ld    a1, x+
    rcall UART_TRANSMIT_HEX
    dec   t3
    brne  0b
    PRINT_NEWLINE

    PRINT_STR STR_DHCP_STATE
    ldi   t3, 1
0:  ld    a1, x+
    rcall UART_TRANSMIT_HEX
    dec   t3
    brne  0b
    PRINT_NEWLINE

    PRINT_STR STR_DHCP_TIMER_SUBTRAHEND_PTR_L
    ldi   t3, 1
0:  ld    a1, x+
    rcall UART_TRANSMIT_HEX
    dec   t3
    brne  0b
    PRINT_NEWLINE

    DEBUG_POP
    ret
#endif

.end
