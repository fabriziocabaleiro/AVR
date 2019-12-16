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

/* GLOBAL {{{1 ---------------------------------------------------------------*/
.global DHCP_HANDLE_PKT
.global DHCP_INIT
.global DHCP

/* DATA  {{{1 ----------------------------------------------------------------*/
.section .data
SRAM_DHCP_SERVER_IP_ADDR:         .skip DHCP_OPTION_DHCP_SERVER_ID_LEN
SRAM_DHCP_XID_LAST_BYTE:          .skip 1
SRAM_DHCP_STATE:                  .skip 1
SRAM_DHCP_ADDRESS_TIME:           .skip DHCP_OPTION_ADDRESS_TIME_LEN
SRAM_DHCP_SECONDS:                .skip DHCP_OPTION_ADDRESS_TIME_LEN
SRAM_DHCP_SUBNET_MASK:            .skip DHCP_OPTION_SUBNET_MASK_LEN
SRAM_DHCP_DOMAIN_SERVER:          .skip DHCP_DOMAIN_SERVER_LEN
/* Pointer to T1/T2 subtrahend. Bit 7 used as flag */
SRAM_DHCP_TIMER_SUBTRAHEND_PTR_L: .skip 1

/* TEXT {{{1 -----------------------------------------------------------------*/
.section .text

/* DHCP {{{2 -------------------------------------------------------------------
 * This routine is called periodically
 * This routine checks the current DHCP state, then sends the required packages
 * in order to have a valid IP address. */
DHCP:
    push  ZL
    push  ZH
    push  YL
    push  YH
    push  s1 /* Pkt size low */
    push  s2 /* Pkt size high */
    push  s3 /* DHCP state */
    /* Load common packet size {{{3
     * All DHCP packages but DHCPREQUEST will have the same packet size */
    ldi   t1, lo8(DHCP_IP_COMMON_PKT_SIZE)
    mov   s1, t1
    ldi   t1, hi8(DHCP_IP_COMMON_PKT_SIZE)
    mov   s2, t1
    /* Switch on SRAM_DHCP_STATE {{{3 */
    /* Load current DHCP state */
    lds   s3, SRAM_DHCP_STATE
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
     * At this point, subtrahend_ptr is not used, then we can use it to hold a
     * counter and send request every N seconds */
    rcall DHCP_WAITING_IN_STATE
    brne  DHCP_IN_INIT_STATE_EXIT

    /* In this state we send a discover and jump directly to selecting state.
     * Also we store the local time in which we sent the discover packet */
    /* TODO: do we store the local time as mentioned above? */
    rcall DHCP_XID_INCREMENT
    rcall DHCP_SEND
    ldi   t1, (1 << DHCP_STATE_SELECTING)
    sts   SRAM_DHCP_STATE, t1
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
    sts   SRAM_DHCP_STATE, t1
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
    sts   SRAM_DHCP_STATE, t1
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
    /* Check if Y still pointing to T1 */
    lds   t1, SRAM_DHCP_TIMER_SUBTRAHEND_PTR_L
    cbr   t1, (1 << DHCP_TIMER_LAP)
    cpi   t1, EEPROM_DHCP_TIMERS_T2
    brlo  STILL_IN_T1
    cpi   t1, EEPROM_DHCP_TIMERS_END
    brlo  STILL_IN_T2
    /* Beyond T2, which means no more timers, go to DHCP init state */
    ldi   t1, (1 << DHCP_STATE_INIT)
    sts   SRAM_DHCP_STATE, t1
    rjmp  DHCP_EXIT_SUCCESS
STILL_IN_T2: /* change state */
    ldi   t1, (1 << DHCP_STATE_REBIDING)
    sts   SRAM_DHCP_STATE, t1
STILL_IN_T1: /* nothing to do */
DHCP_IN_RENEWING_STATE_EXIT:
    rjmp  DHCP_EXIT_SUCCESS

DHCP_IN_INIT_REBOOT_STATE: /* {{{3 */
    rcall DHCP_XID_INCREMENT
    rcall DHCP_SEND
    ldi   t1, (1 << DHCP_STATE_REBOOTING)
    sts   SRAM_DHCP_STATE, t1
    rjmp  DHCP_EXIT_SUCCESS

DHCP_IN_REBOOTING_STATE: /* {{{3 */
    rcall DHCP_WAITING_IN_STATE
    brne  DHCP_IN_REBOOTING_STATE_EXIT
    ldi   t1, (1 << DHCP_STATE_INIT)
    sts   SRAM_DHCP_STATE, t1
DHCP_IN_REBOOTING_STATE_EXIT:
    rjmp  DHCP_EXIT_SUCCESS /* }}}3 */

DHCP_EXIT_SUCCESS:
    pop   s3
    pop   s2
    pop   s1
    pop   YH
    pop   YL
    pop   ZH
    pop   ZL
    ret

/* DHCP_INIT {{{2 --------------------------------------------------------------
 * This routine initialize DHCP */
DHCP_INIT:
    /* SRAM_DHCP_XID_LAST_BYTE will have random initial value */
    /* Check if our current IP in the EEPROM was set */
    ldi   YL, lo8(EEPROM_IP_ADDR)
    ldi   YH, hi8(EEPROM_IP_ADDR)
    ldi   t3, IPV4_ADDR_LEN
0:  rcall EEPROM_READ_N_INC
    tst   x4
    brne  VALID_IP
    dec   t3
    brne  0b
    /* IP address is 0.0.0.0 (invalid IP) */
    ldi   t1, (1 << DHCP_STATE_INIT)
    rjmp  STORE_STATE
VALID_IP:
    ldi   t1, (1 << DHCP_STATE_INIT_REBOOT)
STORE_STATE:
    sts   SRAM_DHCP_STATE, t1
    ret

/* DHCP SEND packet {{{2 -----------------------------------------------------*/
DHCP_SEND:
    DEBUG(PRINT_STR STR_DHCP_SEND_START)
    DEBUG(rcall PRINT_STATE)
    /* Ethernet Header {{{3 */
    ldi   t2, (1 << ENC_MAC_DST_PTR_BROADCAST_BIT)
    sts   SRAM_ENC_MAC_DST_PTR, t2
    ldi   t2, (1 << ENC_TYPE_LEN_PTR_IPv4)
    sts   SRAM_ENC_TYPE_LEN_PTR, t2
    rcall ETH_WRITE_BUFFER_PACKET_HEADER
    /* }}}3 */
    rcall ETH_SET_LISTEN_ON_SPI
    rcall ETH_SET_FLAG_KEEP_OPEN_AFTER_WRITE
    /* IPv4 Header {{{3
     * This header has src as 0.0.0.0, dst as 255.255.255.255, checksum and
     * total length have to be setup
     */
    /* Read default IPv4 header plus part of UDP header from EEPROM {{{4 */
#if EEPROM_IP_HEADER_END != EEPROM_UDP_DHCP_PORT
#   error "Optimization requires EEPROM_IP_HEADER_END == EEPROM_UDP_DHCP_PORT"
#endif
    ldi   ZL, lo8(SRAM_IPV4_HEADER)
    ldi   ZH, hi8(SRAM_IPV4_HEADER)
    /* Write to SRAM, so total length and checksum can be set */
    ldi   YL, lo8(EEPROM_IP_HEADER)
    ldi   YH, hi8(EEPROM_IP_HEADER)
    ldi   x1, (EEPROM_UDP_DHCP_PORT_END - EEPROM_IP_HEADER)
    rcall ES_MEMCPY
    /* Set Z back to SRAM_IPV4_HEADER */
    sbiw  ZL, (EEPROM_UDP_DHCP_PORT_END - EEPROM_IP_HEADER)

    /* Set non default IPv4 header fields {{{4 */
    /* IP TOTAL LENGTH {{{5 */
    std   Z + (IPV4_TOTAL_LENGTH + 0), s2
    std   Z + (IPV4_TOTAL_LENGTH + 1), s1

    /* Src and Dst IP addresses for RENEWING {{{5 */
    sbrs  s3, DHCP_STATE_RENEWING
    rjmp  DEFAULT_SRC_DST_ADDRESSES
    /* Copy Src IP address */
    adiw  ZL, IPV4_SRC_ADDR
    ldi   x1, IPV4_ADDR_LEN
    ldi   YL, lo8(EEPROM_IP_ADDR)
    ldi   YH, hi8(EEPROM_IP_ADDR)
    rcall ES_MEMCPY
    /* Copy DHCP server IP address */
    ldi   YL, lo8(SRAM_DHCP_SERVER_IP_ADDR)
    ldi   YH, hi8(SRAM_DHCP_SERVER_IP_ADDR)
    rcall MEMCPY
    /* Set Z back to SRAM_IPV4_HEADER */
    sbiw  ZL, (IPV4_ADDR_LEN * 2)
DEFAULT_SRC_DST_ADDRESSES:

    /* Internet Checksum {{{5 */
    ldi   x1, (EEPROM_IP_HEADER_END - EEPROM_IP_HEADER)
    ldi   x2, 0
    rcall INTERNET_CHECKSUM_RFC1071
    std   Z + (IPV4_H_CHECKSUM + 0), x3
    std   Z + (IPV4_H_CHECKSUM + 1), x4

    /* Transmit IPv4 Header plus part of UDP {{{4 */
    ldi   x1, (EEPROM_UDP_DHCP_PORT_END - EEPROM_IP_HEADER)
    rcall ETH_WRITE_Z_TO_TRANSMIT_BUFFER

    /* UDP Header {{{3 */
    /* SRC/DST already written */
    /* Write UDP Length {{{4 */
    /* DHCP PKT SIZE was set to IP size, so, substract DHCP_IP_HEADER_SIZE to
     * get the UDP size */
    sbiw  s1, DHCP_IP_HEADER_SIZE
    mov   x1, s2
    rcall SPI_MASTER_TRANSMIT
    mov   x1, s1
    rcall SPI_MASTER_TRANSMIT

    /* UDP Checksum, Zero for ignore {{{4 */
    clr   x1
    rcall SPI_MASTER_TRANSMIT
    rcall SPI_MASTER_TRANSMIT

    /* DHCP Body {{{3 */
    /* Write first 8 bytes: OP, HTYPE, HLEN, HOPS AND XID (3 of 4 bytes) {{{4 */
    ldi   YL, lo8(EEPROM_DHCP_HEADER)
    ldi   YH, hi8(EEPROM_DHCP_HEADER)
    ldi   x1, (EEPROM_DHCP_HEADER_END - EEPROM_DHCP_HEADER)
    rcall SPI_EEPROM_TRANSMIT

    /* Last byte of XID {{{4 */
    lds   x1, SRAM_DHCP_XID_LAST_BYTE
    DEBUG(rcall PRINT_CURRENT_XID)
    rcall SPI_MASTER_TRANSMIT

    /* set SECS and FLAGS to Zero {{{4 */
    clr   x1
    ldi   t3, 4
0:  rcall SPI_MASTER_TRANSMIT
    dec   t3
    brne  0b

    /* CIADDR {{{4
    Field      DHCPDISCOVER          DHCPREQUEST           DHCPDECLINE,
               DHCPINFORM                                  DHCPRELEASE
    -----      ------------          -----------           -----------
    'ciaddr'   0 (DHCPDISCOVER)      0 or client's         0 (DHCPDECLINE)
               client's              network address       client's network
               network address       (BOUND/RENEW/REBIND)  address
               (DHCPINFORM)                                (DHCPRELEASE)
    */
    ldi   YL, lo8(EEPROM_IP_ADDR)
    ldi   YH, hi8(EEPROM_IP_ADDR)
    ldi   t3, IPV4_ADDR_LEN
CIADDR_TO_ZERO_OR_MY_IP:
    clr   x4
    /* IP ADDR is zero for DISCOVER, as it is unset, then, safe to read from
     * EEPROM. At request we already wrote the offer to EEPROM, so, don't use
     * EEPROM value, then, at BOUND/RENEW/REBIND use EEPROM value.
     * Ignoring DHCPDECLINE as logic for declining is not implemented */
#if EEPROM_IP_ADDR_END != EEPROM_MAC_ADDR
    /* if the code reduction optimization is off, then, optimize power by
     * skipping eeprom read, else, do eeprom read to increment Y as required by
     * CHADDR */
    sbrs  s3, DHCP_STATE_REQUESTING /* right after DHCPOFFER */
    rcall EEPROM_READ_N_INC
#else
    rcall EEPROM_READ_N_INC
    sbrs  s3, DHCP_STATE_REQUESTING /* right after DHCPOFFER */
#endif
    mov   x1, x4
    rcall SPI_MASTER_TRANSMIT
    dec   t3
    brne  CIADDR_TO_ZERO_OR_MY_IP

    /* YIADDR, SIADDR and GIADDR to Zero  {{{4 */
    clr   x1
    ldi   t3, 12
YIADDR_SIADDR_GIADDR_TO_ZERO:
    rcall SPI_MASTER_TRANSMIT
    dec   t3
    brne  YIADDR_SIADDR_GIADDR_TO_ZERO

    /* CHADDR, write own MAC {{{4 */
#if EEPROM_IP_ADDR_END != EEPROM_MAC_ADDR
#   warning "Optimization expecting EEPROM_IP_ADDR_END == EEPROM_MAC_ADDR"
    /* This two instructions can be avoided if
     * EEPROM_IP_ADDR_END == EEPROM_MAC_ADDR
     * and no modifications to Y are done after writing CIADDR */
    ldi   YL, lo8(EEPROM_MAC_ADDR)
    ldi   YH, hi8(EEPROM_MAC_ADDR)
#endif
    ldi   x1, MAC_ADDR_LEN
    rcall SPI_EEPROM_TRANSMIT

    /* header has 16 bytes for mac, as using only 6, there are 10 bytes to {{{4
     * write as zero, then we have 192 bytes of zero (option overload/BOOTS
     * legacy) */
    clr   x1
    ldi   t3, 202
DHCP_LEGACY_TO_ZERO_LOOP:
    rcall SPI_MASTER_TRANSMIT
    dec   t3
    brne  DHCP_LEGACY_TO_ZERO_LOOP

    /* Write magic cookie and beginning of option msg {{{4 */
    ldi   YL, lo8(EEPROM_DHCP_MAGIC_COOKIE)
    ldi   YH, hi8(EEPROM_DHCP_MAGIC_COOKIE)
#if EEPROM_DHCP_MAGIC_COOKIE_END != EEPROM_DHCP_OPTION_MSG_N_LEN
#   error "Optimization requires EEPROM_DHCP_MAGIC_COOKIE_END == EEPROM_DHCP_OPTION_MSG_N_LEN"
#endif
    ldi   x1, (EEPROM_DHCP_OPTION_MSG_N_LEN_END - EEPROM_DHCP_MAGIC_COOKIE)
    rcall SPI_EEPROM_TRANSMIT

    /* DHCP Options {{{4 */
    /* DHCP MSG TYPE {{{5 */
    /* MSG type and length is written from EEPROM */
    /* all messages from client but discover will have a request msg type */
    ldi   x1, DHCP_OPTION_DHCP_MSG_TYPE_DHCP_DISCOVER
    sbrs  s3, DHCP_STATE_INIT
    ldi   x1, DHCP_OPTION_DHCP_MSG_TYPE_DHCP_REQUEST
    rcall SPI_MASTER_TRANSMIT

    /* DHCP packets that don't require more options {{{5
     * BEWARE s3 gets modified here */
    andi  s3, (1 << DHCP_STATE_INIT)        | \
              (1 << DHCP_STATE_INIT_REBOOT) | \
              (1 << DHCP_STATE_REBOOTING)   | \
              (1 << DHCP_STATE_RENEWING)    | \
              (1 << DHCP_STATE_REBIDING)
    brne  DHCP_END_OP

DHCP_REQUEST_OPS: /* DHCP Request options {{{5 */
#if EEPROM_DHCP_REQUEST_OPS_END != EEPROM_IP_ADDR
#   error "DHCP request required EEPROM_DHCP_REQUEST_OPS_END == EEPROM_IP_ADDR"
#endif
    /* Hostname and IP address {{{6 */
    ldi   YL, lo8(EEPROM_DHCP_REQUEST_OPS)
    ldi   YH, hi8(EEPROM_DHCP_REQUEST_OPS)
    ldi   x1, (EEPROM_IP_ADDR_END - EEPROM_DHCP_REQUEST_OPS)
    rcall SPI_EEPROM_TRANSMIT

    /* DHCP server IP address {{{6 */
    ldi   x1, DHCP_OPTION_DHCP_SERVER_ID
    rcall SPI_MASTER_TRANSMIT
    ldi   x1, DHCP_OPTION_DHCP_SERVER_ID_LEN
    rcall SPI_MASTER_TRANSMIT

    ldi   ZL, lo8(SRAM_DHCP_SERVER_IP_ADDR)
    ldi   ZH, hi8(SRAM_DHCP_SERVER_IP_ADDR)
    ldi   x1, DHCP_OPTION_DHCP_SERVER_ID_LEN
    rcall ETH_WRITE_Z_TO_TRANSMIT_BUFFER

DHCP_END_OP: /* End Options */
    ldi   x1, DHCP_OPTION_END
    rcall SPI_MASTER_TRANSMIT
    /* }}}3 */
    ETH_END_LISTEN_ON_SPI
    rcall ETH_UNSET_FLAG_KEEP_OPEN_AFTER_WRITE
    rcall ETH_WRITE_BUFFER_PACKET_PAYLOAD_FINISH
    ret

/* Handle dhcp packet {{{2 -----------------------------------------------------
 * BEWARE, EXPECTING ETH MODULE LISTENING TO SPI */
DHCP_HANDLE_PKT:
    push YL
    push YH

    DEBUG(PRINT_STR_SAFE STR_DHCP_HANDLE_START)
    /* Check OP, HTYPE, HLEN, HOPS and XID  {{{3 */
    ETH_READ_NEXT_BYTE
    cpi   x4, DHCP_OP_BOOTREPLY
    brne  DHCP_HANDLE_EXIT_SUCCESS

    /* Compare beginning of header */
    ldi   YL, lo8(EEPROM_DHCP_HEADER + 1)
    ldi   YH, hi8(EEPROM_DHCP_HEADER + 1)
    ldi   x1, 6
    rcall EN_MEMCMP
    brne  DHCP_HANDLE_EXIT_SUCCESS

    /* Check last byte of the XID */
    ETH_READ_NEXT_BYTE
    lds   t1, SRAM_DHCP_XID_LAST_BYTE
    DEBUG(rcall PRINT_INCOMING_N_EXPECTED_XID)
    cp    t1, x4
    brne  DHCP_HANDLE_EXIT_SUCCESS

    /* Jump to YIADDR {{{3 */
#if USE_MOVE_RDPT
    ETH_READ_BUFFER_END
    ldi   x1, 0
    ldi   x2, 8 /* SECS + FLAGS + CIADDR */
    rcall ETH_MOVE_RDPT
    rcall ETH_READ_BUFFER_START
#else
    ldi   t3, 8
0:  ETH_READ_NEXT_BYTE
    dec   t3
    brne  0b
#endif

    /* Read offered IP and write it into EEPROM {{{3 */
    ldi   t3, IPV4_ADDR_LEN
    ldi   YL, lo8(EEPROM_IP_ADDR)
    ldi   YH, hi8(EEPROM_IP_ADDR)
UPDATE_EEPROM_IP_ADDR:
    ETH_READ_NEXT_BYTE
    mov   x1, x4
    rcall EEPROM_WRITE_N_INC
    dec   t3
    brne  UPDATE_EEPROM_IP_ADDR

    /* Jump from siaddr ip addr to magic cookie {{{3 */
#if USE_MOVE_RDPT
    ETH_READ_BUFFER_END
    ldi   x1, 0
    ldi   x2, 216
    rcall ETH_MOVE_RDPT
    rcall ETH_READ_BUFFER_START
#else
    ldi   t3, 216
0:  ETH_READ_NEXT_BYTE
    dec   t3
    brne  0b
#endif

    /* Check magic cookie {{{3 */
    ldi   YL, lo8(EEPROM_DHCP_MAGIC_COOKIE)
    ldi   YH, hi8(EEPROM_DHCP_MAGIC_COOKIE)
    ldi   x1, (EEPROM_DHCP_MAGIC_COOKIE_END - EEPROM_DHCP_MAGIC_COOKIE)
    rcall EN_MEMCMP
    brne  DHCP_HANDLE_EXIT_FAILURE
    /* Jump to start reading options (skipping exit block) */
    rjmp  START_READING_DHCP_OPTIONS

DHCP_HANDLE_EXIT_SUCCESS: /* {{{3 */
NO_MORE_OPTIONS:
    ldi  x4, 0
DHCP_HANDLE_EXIT:
    ETH_READ_BUFFER_END
    pop  YH
    pop  YL
    ret
DHCP_HANDLE_EXIT_FAILURE:
    DEBUG(PRINT_STR_SAFE STR_FAILURE)
    ldi  x4, 1
    rjmp DHCP_HANDLE_EXIT

START_READING_DHCP_OPTIONS: /* {{{3 */
KEEP_READING_DHCP_OPTIONS:
    ETH_READ_NEXT_BYTE
    /* Check if end of options */
    cpi   x4, DHCP_OPTION_END
    breq  NO_MORE_OPTIONS
    /* Check if padding, which doesn't have length. Go to read next byte */
    cpi   x4, DHCP_OPTION_PAD
    breq  KEEP_READING_DHCP_OPTIONS
    /* DHCP message {{{4 */
    cpi   x4, DHCP_OPTION_DHCP_MSG_TYPE
    brne  TRY_DHCP_OPTION_DHCP_SERVER_ID
    /* DHCP message, we care about dhcp offer */
    ETH_READ_NEXT_BYTE /* read size of option, must be 1 */
    ETH_READ_NEXT_BYTE
    cpi   x4, DHCP_OPTION_DHCP_MSG_TYPE_DHCP_OFFER
    brne  TRY_DHCP_ACK
    ldi   t1, (1 << DHCP_STATE_REQUESTING)
    sts   SRAM_DHCP_STATE, t1
    rjmp  KEEP_READING_DHCP_OPTIONS
TRY_DHCP_ACK:
    cpi   x4, DHCP_OPTION_DHCP_MSG_TYPE_DHCP_ACK
    brne  KEEP_READING_DHCP_OPTIONS
    DEBUG(PRINT_STR_SAFE STR_OPT_ACK)
    /* Set states {{{5 */
    ldi   t1, (1 << DHCP_STATE_BOUND)
    sts   SRAM_DHCP_STATE, t1
    ldi   t1, (1 << DHCP_TIMER_LAP) | EEPROM_DHCP_TIMERS
    sts   SRAM_DHCP_TIMER_SUBTRAHEND_PTR_L, t1
    /* }}}5 */
    rjmp  KEEP_READING_DHCP_OPTIONS

TRY_DHCP_OPTION_DHCP_SERVER_ID: /* {{{4 */
    cpi   x4, DHCP_OPTION_DHCP_SERVER_ID
    brne  TRY_DHCP_OPTION_ADDRESS_TIME
    ETH_READ_NEXT_BYTE /* must be 4 */
    ldi   t3, DHCP_OPTION_DHCP_SERVER_ID_LEN
    ldi   YL, lo8(SRAM_DHCP_SERVER_IP_ADDR)
    ldi   YH, hi8(SRAM_DHCP_SERVER_IP_ADDR)
STORE_DHCP_SERVER_IP_ADDR:
    ETH_READ_NEXT_BYTE
    st    Y+, x4
    dec   t3
    brne  STORE_DHCP_SERVER_IP_ADDR
    rjmp  KEEP_READING_DHCP_OPTIONS

TRY_DHCP_OPTION_ADDRESS_TIME: /* {{{4 */
    cpi   x4, DHCP_OPTION_ADDRESS_TIME
    brne  TRY_DHCP_OPTION_SUBNET_MASK
    ETH_READ_NEXT_BYTE /* must be 4 */
    ldi   t3, DHCP_OPTION_ADDRESS_TIME_LEN
    ldi   YL, lo8(SRAM_DHCP_ADDRESS_TIME)
    ldi   YH, hi8(SRAM_DHCP_ADDRESS_TIME)
STORE_DHCP_ADDRESS_TIME:
    ETH_READ_NEXT_BYTE
    st    Y+, x4
    dec   t3
    brne  STORE_DHCP_ADDRESS_TIME
    rjmp  KEEP_READING_DHCP_OPTIONS

TRY_DHCP_OPTION_SUBNET_MASK: /* {{{4 */
    cpi   x4, DHCP_OPTION_SUBNET_MASK
    brne  TRY_DHCP_OPTION_DOMAIN_SERVER
    ETH_READ_NEXT_BYTE /* must be 4 */
    ldi   t3, DHCP_OPTION_SUBNET_MASK_LEN
    ldi   YL, lo8(SRAM_DHCP_SUBNET_MASK)
    ldi   YH, hi8(SRAM_DHCP_SUBNET_MASK)
STORE_DHCP_OPTION_SUBNET_MASK:
    ETH_READ_NEXT_BYTE
    st    Y+, x4
    dec   t3
    brne  STORE_DHCP_OPTION_SUBNET_MASK
    rjmp  KEEP_READING_DHCP_OPTIONS

TRY_DHCP_OPTION_DOMAIN_SERVER: /* {{{4 */
    cpi   x4, DHCP_OPTION_DOMAIN_SERVER
    brne  IGNORE_DHCP_OP
    ETH_READ_NEXT_BYTE
    mov   t3, x4
    ldi   YL, lo8(SRAM_DHCP_DOMAIN_SERVER)
    ldi   YH, hi8(SRAM_DHCP_DOMAIN_SERVER)
    /* BEWARE NOT TO CALL ANY ROUTINE THAT CHANGES t1 */
    /* TODO: break this constraint */
    ldi   t1, DHCP_DOMAIN_SERVER_LEN
STORE_DHCP_OPTION_DOMAIN_SERVER:
    ETH_READ_NEXT_BYTE
    tst   t1
    breq  SKIP_DHCP_OPTION_DOMAIN_SERVER_ST
    st    Y+, x4
    dec   t1
SKIP_DHCP_OPTION_DOMAIN_SERVER_ST:
    dec   t3
    brne  STORE_DHCP_OPTION_DOMAIN_SERVER
    rjmp  KEEP_READING_DHCP_OPTIONS

IGNORE_DHCP_OP: /* {{{4 */
    ETH_READ_NEXT_BYTE /* read size of option */
    mov   t3, x4
DHCP_OP_READ_CONTENT:
    ETH_READ_NEXT_BYTE
    dec   t3
    brne  DHCP_OP_READ_CONTENT
    rjmp  KEEP_READING_DHCP_OPTIONS

/* Timer handlers {{{2 ---------------------------------------------------------
 * Carry will be set when timer expires */
DHCP_TIMERS:
    lds   YL, SRAM_DHCP_TIMER_SUBTRAHEND_PTR_L
    sbrc  YL, DHCP_TIMER_LAP
    rjmp  DHCP_SET_COUNTDOWN
    rjmp  DHCP_COUNTDOWN
DHCP_SET_COUNTDOWN: /* {{{3 */
    /* Clear lap bit, increment pointer by 1 {{{4 */
    cbr   YL, (1 << DHCP_TIMER_LAP)
    sts   SRAM_DHCP_TIMER_SUBTRAHEND_PTR_L, YL

    /* Copy lease time to dhcp seconds {{{4 */
    ldi   ZL, lo8(SRAM_DHCP_ADDRESS_TIME)
    ldi   ZH, hi8(SRAM_DHCP_ADDRESS_TIME)
    ldi   t3, 4
DHCP_SET_COUNTDOWN_LOOP:
    ld    t2, Z+
    std   Z + (SRAM_DHCP_SECONDS - SRAM_DHCP_ADDRESS_TIME - 1), t2
    dec   t3
    brne  DHCP_SET_COUNTDOWN_LOOP
    /* }}} */
DHCP_COUNTDOWN: /* {{{3 */
    /* Start from least significant byte.
     * Subtract 1 from first byte, then subtract zero.
     * All subtraction are with carry
     */
    /* Loading 1 address beyond because of ld with pre-decrement */
    ldi   ZL, lo8(SRAM_DHCP_SECONDS + 4)
    ldi   ZH, hi8(SRAM_DHCP_SECONDS + 4)
    ldi   t3, 4
    clr   YH
    rcall EEPROM_READ_N_INC
    clc
DHCP_TIMERS_DEC:
    ld    t1, -Z
    sbc   t1, x4
    clr   x4
    st    Z, t1
    dec   t3
    brne  DHCP_TIMERS_DEC
    /* }}} */
    /* After subtraction, Check if underflow, if so, set DHCP_TIMER_LAP. DHCP
     * packet will be sent and next time DHCP_TIMERS is called, the timer will
     * be reset */
    brcc  DHCP_TIMERS_EXIT
    lds   t1, SRAM_DHCP_TIMER_SUBTRAHEND_PTR_L
    inc   t1
    sbr   t1, (1 << DHCP_TIMER_LAP)
    sts   SRAM_DHCP_TIMER_SUBTRAHEND_PTR_L, t1
DHCP_TIMERS_EXIT:
    ret

/* Simple counter to add waiting time {{{2 -----------------------------------*/
DHCP_WAITING_IN_STATE:
    lds   t1, SRAM_DHCP_TIMER_SUBTRAHEND_PTR_L
    inc   t1
    sts   SRAM_DHCP_TIMER_SUBTRAHEND_PTR_L, t1
    andi  t1, DHCP_TIMER_ANDI
    ret

/* Increment XID LSB {{{2 ----------------------------------------------------*/
DHCP_XID_INCREMENT:
    lds   t1, SRAM_DHCP_XID_LAST_BYTE
    inc   t1
    sts   SRAM_DHCP_XID_LAST_BYTE, t1
    ret

/* Debugging functionality {{{2 ----------------------------------------------*/
#ifndef NDEBUG
PRINT_CURRENT_XID:
    DEBUG_PUSH
    PRINT_STR STR_LOCAL_XID
    PRINT_REG x1
    PRINT_NEWLINE
    DEBUG_POP
    ret

PRINT_INCOMING_N_EXPECTED_XID:
    DEBUG_PUSH
    PRINT_STR STR_LOCAL_XID
    PRINT_REG t1
    PRINT_NEWLINE
    PRINT_STR STR_INCOMING_XID
    PRINT_REG x4
    PRINT_NEWLINE
    DEBUG_POP
    ret

PRINT_STATE:
    DEBUG_PUSH
    PRINT_STR STR_STATE
    lds   x1, SRAM_DHCP_STATE
    PRINT_REG x1
    PRINT_NEWLINE
    DEBUG_POP
    ret
#endif

.end
