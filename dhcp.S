/* vim: set filetype=S foldmethod=marker: */
.NOLIST
#include <avr/io.h>
#include <avr/interrupt.h>
#include "defs.h"
#include "dhcp.h"
#include "ipv4.h"
#include "enc28j60.h"
#include "timer.h"
.LIST

.global DHCP_HANDLE_PKT
.global DHCP_INIT
.global DHCP

#define DHCP_DOMAIN_SERVER_LEN  8
#define DHCP_STATE_R            R23
#define DHCP_PKT_SIZE_L         R24
#define DHCP_PKT_SIZE_H         R25

/* Bit 7 used for counter underflow flag */
#if (EEPROM_DHCP_TIMERS - 8) >= 127
#   error "Optimization for EEPROM_DHCP_TIMERS won't work"
#endif

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

.section .text

/*******************************************************************************
 * DHCP, this routine is called periodically {{{
 *
 * This routine checks the current DHCP state, then sends the required packages
 * in order to have a valid IP address.
 ******************************************************************************/
DHCP:
    push  ZL
    push  ZH
    push  YL
    push  YH
    push  DHCP_STATE_R
    push  DHCP_PKT_SIZE_L
    push  DHCP_PKT_SIZE_H
    /* Load common packet size {{{ */
    ldi   TMP_REG1, lo8(DHCP_IP_COMMON_PKT_SIZE)
    mov   DHCP_PKT_SIZE_L, TMP_REG1
    ldi   TMP_REG1, hi8(DHCP_IP_COMMON_PKT_SIZE)
    mov   DHCP_PKT_SIZE_H, TMP_REG1
    /* }}} */
    /* Switch on SRAM_DHCP_STATE {{{ */
    /* Load current DHCP state */
    lds   DHCP_STATE_R, SRAM_DHCP_STATE
    sbrc  DHCP_STATE_R, DHCP_STATE_INIT
    rjmp  DHCP_IN_INIT_STATE
    sbrc  DHCP_STATE_R, DHCP_STATE_SELECTING
    rjmp  DHCP_IN_SELECTING_STATE
    sbrc  DHCP_STATE_R, DHCP_STATE_REQUESTING
    rjmp  DHCP_IN_REQUESTING_STATE
    sbrc  DHCP_STATE_R, DHCP_STATE_BOUND
    rjmp  DHCP_IN_BOUND_STATE
    sbrc  DHCP_STATE_R, DHCP_STATE_RENEWING
    rjmp  DHCP_IN_RENEWING_STATE
    sbrc  DHCP_STATE_R, DHCP_STATE_REBIDING
    rjmp  DHCP_IN_REBIDING_STATE
    sbrc  DHCP_STATE_R, DHCP_STATE_INIT_REBOOT
    rjmp  DHCP_IN_INIT_REBOOT_STATE
    sbrc  DHCP_STATE_R, DHCP_STATE_REBOOTING
    rjmp  DHCP_IN_REBOOTING_STATE
    /* TODO: add error check if SRAM_DHCP_STATE == 0 ? */
    /* }}} */
DHCP_IN_INIT_STATE: /* {{{ */
#if (DHCP_IP_DISCOVERY_PKT_SIZE != DHCP_IP_COMMON_PKT_SIZE) || \
    (DHCP_UDP_DISCOVERY_PKT_SIZE != DHCP_IP_COMMON_PKT_SIZE -  \
    DHCP_IP_HEADER_SIZE)
#   error "DHCP init state assumes common packet size"
#endif
    /* Try to send a REQUEST every 16 seconds, {{{
     * At this point, subtrahend_ptr is not used, then we can use it to hold a
     * counter and send request every N seconds */
    lds   TMP_REG1, SRAM_DHCP_TIMER_SUBTRAHEND_PTR_L
    inc   TMP_REG1
    sts   SRAM_DHCP_TIMER_SUBTRAHEND_PTR_L, TMP_REG1
    andi  TMP_REG1, 0x0F
    brne  DHCP_IN_INIT_STATE_EXIT
    /* }}} */
    /* Increment XID on Discover {{{ */
    lds   TMP_REG1, SRAM_DHCP_XID_LAST_BYTE
    inc   TMP_REG1
    sts   SRAM_DHCP_XID_LAST_BYTE, TMP_REG1
    /* }}} */
    /* In this state we send a discover and jump directly to selecting state.
     * Also we store the local time in which we sent the discover packet */
    rcall DHCP_SEND
    ldi   TMP_REG1, (1 << DHCP_STATE_SELECTING)
    sts   SRAM_DHCP_STATE, TMP_REG1
    /* record time {{{ */
    /* TODO: it could be improved with ldd instead of using Y and Z */
    ldi   ZL, lo8(SRAM_TIMER1_SECONDS)
    ldi   ZH, hi8(SRAM_TIMER1_SECONDS)
    ldi   YL, lo8(SRAM_DHCP_SECONDS)
    ldi   YH, hi8(SRAM_DHCP_SECONDS)
    ldi   TMP_REG1, TIMER1_SECONDS_LEN
RECORD_INIT_TIME:
    ld    TMP_REG2, Z+
    st    Y+, TMP_REG2
    dec   TMP_REG1
    brne  RECORD_INIT_TIME
    /* }}} */
DHCP_IN_INIT_STATE_EXIT:
    rjmp  DHCP_EXIT_SUCCESS
    /* }}} */
DHCP_IN_SELECTING_STATE: /* {{{ */
    /* In selecting state we wait to receive an offer, when the server sends the
     * offer, the dhcp handler will jump to requesting state.
     * If an offer doesn't arrive in some time, then, go back to init state.
     * We are going to do:
     * if(SRAM_TIMER1_SECONDS >= SRAM_DHCP_SECONDS)
     *     SRAM_TIMER1_SECONDS - SRAM_DHCP_SECONDS
     * else
     *     SRAM_TIMER1_SECONDS + COM(SRAM_DHCP_SECONDS)
     */
    lds   TMP_REG1, SRAM_TIMER1_SECONDS
    lds   TMP_REG2, SRAM_DHCP_SECONDS
    cp    TMP_REG1, TMP_REG2
    brsh  SUBTRACT_DHCP_TO_TIMER
ADD_COM_TO_TIMER:
    com   TMP_REG2
    add   TMP_REG1, TMP_REG2
    rjmp  CHECK_SELECTING_TIME
SUBTRACT_DHCP_TO_TIMER:
    sub   TMP_REG1, TMP_REG2
CHECK_SELECTING_TIME:
    cpi   TMP_REG1, 10
    brpl  KEEP_WAITING_OFFER
    ldi   TMP_REG1, (1 << DHCP_STATE_INIT)
    sts   SRAM_DHCP_STATE, TMP_REG1
KEEP_WAITING_OFFER:
    rjmp  DHCP_EXIT_SUCCESS
    /* }}} */
DHCP_IN_REQUESTING_STATE: /* {{{ */
    /* Request size is different from common size */
#if (DHCP_IP_REQUEST_PKT_SIZE == DHCP_IP_COMMON_PKT_SIZE)
#   warning "DHCP request state re-writing pkt size with the same value"
#endif
    ldi   TMP_REG1, lo8(DHCP_IP_REQUEST_PKT_SIZE)
    mov   DHCP_PKT_SIZE_L, TMP_REG1
    ldi   TMP_REG1, hi8(DHCP_IP_REQUEST_PKT_SIZE)
    mov   DHCP_PKT_SIZE_H, TMP_REG1
    rcall DHCP_SEND
    rjmp  DHCP_EXIT_SUCCESS
    /* }}} */
DHCP_IN_BOUND_STATE: /* {{{ */
    /* After subtract 0 from the 3 MSB, check the Carry, if set, then go to
     * renewing state */
    rcall DHCP_TIMERS
    brcc  DHCP_IN_BOUND_STATE_EXIT
    /* Change DHCP state */
    ldi   TMP_REG1, (1 << DHCP_STATE_RENEWING)
    sts   SRAM_DHCP_STATE, TMP_REG1
    mov   DHCP_STATE_R, TMP_REG1
    rjmp  DHCP_TIMER_LAP_COMPLETED
DHCP_IN_BOUND_STATE_EXIT:
    rjmp  DHCP_EXIT_SUCCESS
    /* }}} */
DHCP_IN_RENEWING_STATE: /* {{{ */
DHCP_IN_REBIDING_STATE:
    /* read: DHCPREQUEST generated during RENEWING state (rfc2131) */
    rcall DHCP_TIMERS
    brcc  DHCP_IN_RENEWING_STATE_EXIT
DHCP_TIMER_LAP_COMPLETED:
    /* Increase XID for renewing {{{ */
    lds   TMP_REG1, SRAM_DHCP_XID_LAST_BYTE
    inc   TMP_REG1
    sts   SRAM_DHCP_XID_LAST_BYTE, TMP_REG1
    /* }}} */
    rcall DHCP_SEND
    /* Check if Y still pointing to T1 */
    lds   TMP_REG1, SRAM_DHCP_TIMER_SUBTRAHEND_PTR_L
    cbr   TMP_REG1, (1 << DHCP_TIMER_LAP)
    cpi   TMP_REG1, EEPROM_DHCP_TIMERS_T2
    brlo  STILL_IN_T1
    cpi   TMP_REG1, EEPROM_DHCP_TIMERS_END
    brlo  STILL_IN_T2
    /* Beyond T2, which means no more timers, go to DHCP init state */
    ldi   TMP_REG1, (1 << DHCP_STATE_INIT)
    sts   SRAM_DHCP_STATE, TMP_REG1
    rjmp  DHCP_EXIT_SUCCESS
STILL_IN_T2: /* change state */
    ldi   TMP_REG1, (1 << DHCP_STATE_REBIDING)
    sts   SRAM_DHCP_STATE, TMP_REG1
STILL_IN_T1: /* nothing to do */
DHCP_IN_RENEWING_STATE_EXIT:
    rjmp  DHCP_EXIT_SUCCESS
    /* }}} */
DHCP_IN_INIT_REBOOT_STATE: /* {{{ */
    /* Increase XID for reboot {{{ */
    lds   TMP_REG1, SRAM_DHCP_XID_LAST_BYTE
    inc   TMP_REG1
    sts   SRAM_DHCP_XID_LAST_BYTE, TMP_REG1
    /* }}} */
    rcall DHCP_SEND
    ldi   TMP_REG1, (1 << DHCP_STATE_REBOOTING)
    sts   SRAM_DHCP_STATE, TMP_REG1
    rjmp  DHCP_EXIT_SUCCESS
    /* }}} */
DHCP_IN_REBOOTING_STATE: /* {{{ */
    lds   TMP_REG1, SRAM_DHCP_SECONDS
    tst   TMP_REG1
    breq  REBOOTING_SET_COUNTDOWN
    dec   TMP_REG1
    breq  REBOOTING_SET_INIT_STATE
    sts   SRAM_DHCP_SECONDS, TMP_REG1
    rjmp  DHCP_EXIT_SUCCESS
REBOOTING_SET_INIT_STATE:
    ldi   TMP_REG1, DHCP_STATE_INIT
    sts   SRAM_DHCP_STATE, TMP_REG1
    /* Missing rjmp DHCP_EXIT_SUCCESS intentionally as not necessary */
REBOOTING_SET_COUNTDOWN:
    ldi   TMP_REG1, REBOOTING_WAIT_SECONDS_FOR_ACK
    sts   SRAM_DHCP_SECONDS, TMP_REG1
    rjmp  DHCP_EXIT_SUCCESS
    /* }}} */
DHCP_EXIT_SUCCESS:
    pop   DHCP_PKT_SIZE_H
    pop   DHCP_PKT_SIZE_L
    pop   DHCP_STATE_R
    pop   YH
    pop   YL
    pop   ZH
    pop   ZL
    ret
/* }}} */
/*******************************************************************************
 * DHCP_INIT, this routine initialize DHCP {{{
 ******************************************************************************/
DHCP_INIT:
    /* Should I initialize to ZERO ? */
    // sts   SRAM_DHCP_XID_LAST_BYTE, TMP_REG1
    /* Check if our current IP in the EEPROM was set */
    ldi   YL, lo8(EEPROM_IP_ADDR)
    ldi   YH, hi8(EEPROM_IP_ADDR)
    ldi   COUNTER_REG, IPV4_SIZE_IN_BYTES
CHECK_IF_VALID_IP:
    rcall EEPROM_READ_N_INC
    tst   RETURN_VALUE
    brne  VALID_IP
    dec   COUNTER_REG
    brne  CHECK_IF_VALID_IP
    /* IP address is 0.0.0.0 (invalid IP) */
    ldi   TMP_REG1, (1 << DHCP_STATE_INIT)
    rjmp  STORE_STATE
VALID_IP:
    ldi   TMP_REG1, (1 << DHCP_STATE_INIT_REBOOT)
STORE_STATE:
    sts   SRAM_DHCP_STATE, TMP_REG1
    ret
/* }}} */
/*******************************************************************************
 * DHCP SEND packet {{{
 ******************************************************************************/
DHCP_SEND:
    /* Ethernet Header {{{ */
    ldi   TMP_REG2, (1 << ENC_MAC_DST_PTR_BROADCAST_BIT)
    sts   SRAM_ENC_MAC_DST_PTR, TMP_REG2
    ldi   TMP_REG2, (1 << ENC_TYPE_LEN_PTR_IPv4)
    sts   SRAM_ENC_TYPE_LEN_PTR, TMP_REG2
    rcall ETH_WRITE_BUFFER_PACKET_HEADER
    /* }}} */
    rcall ETH_SET_LISTEN_ON_SPI
    /* IPv4 Header {{{
     * This header has src as 0.0.0.0, dst as 255.255.255.255, checksum and
     * total length have to be setup
     */
    /* Read default IPv4 header from EEPROM {{{ */
    ldi   YL, lo8(EEPROM_IP_HEADER)
    ldi   YH, hi8(EEPROM_IP_HEADER)
    ldi   COUNTER_REG, (EEPROM_IP_HEADER_END - EEPROM_IP_HEADER)
    /* Write to SRAM, so total length and checksum can be set */
    ldi   ZL, lo8(SRAM_IPV4_HEADER)
    ldi   ZH, hi8(SRAM_IPV4_HEADER)
DHCP_WRITE_IP_HEADER_TO_SRAM:
    rcall EEPROM_READ_N_INC
    st    Z+, RETURN_VALUE
    dec   COUNTER_REG
    brne  DHCP_WRITE_IP_HEADER_TO_SRAM
    /* }}} */
    /* Set non default IPv4 header fields {{{ */
    ldi   ZL, lo8(SRAM_IPV4_HEADER)
    ldi   ZH, hi8(SRAM_IPV4_HEADER)

    /* IP TOTAL LENGTH {{{ */
    std   Z + (IPV4_TOTAL_LENGTH + 0), DHCP_PKT_SIZE_H
    std   Z + (IPV4_TOTAL_LENGTH + 1), DHCP_PKT_SIZE_L
    /* }}} */
    /* Src and Dst IP addresses for RENEWING {{{ */
    sbrs  DHCP_STATE_R, DHCP_STATE_RENEWING
    rjmp  DEFAULT_SRC_DST_ADDRESSES
    adiw  ZL, IPV4_SRC_ADDR
    ldi   COUNTER_REG, IPV4_SIZE_IN_BYTES
    ldi   YL, lo8(EEPROM_IP_ADDR)
    ldi   YH, hi8(EEPROM_IP_ADDR)
DHCP_IP_HEADER_SRC_IP_LOOP:
    rcall EEPROM_READ_N_INC
    st    Z+, RETURN_VALUE
    dec   COUNTER_REG
    brne  DHCP_IP_HEADER_SRC_IP_LOOP

    ldi   COUNTER_REG, IPV4_SIZE_IN_BYTES
    ldi   YL, lo8(SRAM_DHCP_SERVER_IP_ADDR)
    ldi   YH, hi8(SRAM_DHCP_SERVER_IP_ADDR)
DHCP_IP_HEADER_DST_IP_LOOP:
    ld    TMP_REG1, Y+
    st    Z+, TMP_REG1
    dec   COUNTER_REG
    brne  DHCP_IP_HEADER_DST_IP_LOOP
DEFAULT_SRC_DST_ADDRESSES:
    /* }}} */
    /* Internet Checksum {{{ */
    ldi   ZL, lo8(SRAM_IPV4_HEADER)
    ldi   ZH, hi8(SRAM_IPV4_HEADER)
    ldi   ARG_REG1, (EEPROM_IP_HEADER_END - EEPROM_IP_HEADER)
    rcall INTERNET_CHECKSUM_RFC1071
    std   Z + (IPV4_H_CHECKSUM + 0), YH
    std   Z + (IPV4_H_CHECKSUM + 1), YL
    /* }}} */
    /* }}} */
    /* Transmit IPv4 Header {{{ */
    ldi   COUNTER_REG, (EEPROM_IP_HEADER_END - EEPROM_IP_HEADER)
DHCP_WRITE_IP_HEADER:
    ld    ARG_REG1, Z+
    rcall SPI_MASTER_TRANSMIT
    dec   COUNTER_REG
    brne  DHCP_WRITE_IP_HEADER
    /* }}} */
    /* }}} */
    /* UDP Header {{{ */
    /* SRC/DST port {{{ */
    ldi   ARG_REG1, hi8(UDP_SRC_PORT)
    rcall SPI_MASTER_TRANSMIT
    ldi   ARG_REG1, lo8(UDP_SRC_PORT)
    rcall SPI_MASTER_TRANSMIT
    ldi   ARG_REG1, hi8(UDP_DST_PORT)
    rcall SPI_MASTER_TRANSMIT
    ldi   ARG_REG1, lo8(UDP_DST_PORT)
    rcall SPI_MASTER_TRANSMIT
    /* }}} */
    /* Write UDP Length {{{ */
    /* DHCP PKT SIZE was set to IP size, so, substract DHCP_IP_HEADER_SIZE to
     * get the UDP size */
    sbiw  DHCP_PKT_SIZE_L, DHCP_IP_HEADER_SIZE
    mov   ARG_REG1, DHCP_PKT_SIZE_H
    rcall SPI_MASTER_TRANSMIT
    mov   ARG_REG1, DHCP_PKT_SIZE_L
    rcall SPI_MASTER_TRANSMIT
    /* }}} */
    /* UDP Checksum, Zero for ignore {{{ */
    ldi   ARG_REG1, 0
    rcall SPI_MASTER_TRANSMIT
    rcall SPI_MASTER_TRANSMIT
    /* }}} */
    /* }}} */
    /* DHCP Body {{{ */
    /* Write first 8 bytes: OP, HTYPE, HLEN, HOPS AND XID (3 of 4 bytes) {{{ */
    ldi   YL, lo8(EEPROM_DHCP_HEADER)
    ldi   YH, hi8(EEPROM_DHCP_HEADER)
    ldi   COUNTER_REG, (EEPROM_DHCP_HEADER_END - EEPROM_DHCP_HEADER)
DHCP_REQUEST_IP_SET_HEADER_LOOP_1:
    rcall EEPROM_READ_N_INC
    mov   ARG_REG1, RETURN_VALUE
    rcall SPI_MASTER_TRANSMIT
    dec   COUNTER_REG
    brne  DHCP_REQUEST_IP_SET_HEADER_LOOP_1
    /* }}} */
    /* Last byte of XID {{{ */
    lds   ARG_REG1, SRAM_DHCP_XID_LAST_BYTE
    rcall SPI_MASTER_TRANSMIT
    /* }}} */
    /* set SECS and FLAGS to Zero {{{ */
    clr   ARG_REG1
    ldi   COUNTER_REG, 4
SECS_FLAGS_TO_ZERO:
    rcall SPI_MASTER_TRANSMIT
    dec   COUNTER_REG
    brne  SECS_FLAGS_TO_ZERO
    /* }}} */
    /* CIADDR {{{
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
    ldi   COUNTER_REG, IPV4_SIZE_IN_BYTES
CIADDR_TO_ZERO_OR_MY_IP:
    clr   RETURN_VALUE
    /* IP ADDR is zero for DISCOVER, as it is unset, then, save to read from
     * EEPROM, then, at request we already wrote the offer to EEPROM, so, don't
     * use EEPROM value, then, at BOUND/REVEW/REBIND use EEPROM value.
     * TODO: DHCPDECLINE */
    sbrs  DHCP_STATE_R, DHCP_STATE_REQUESTING /* right after DHCPOFFER */  
    rcall EEPROM_READ_N_INC
    mov   ARG_REG1, RETURN_VALUE
    rcall SPI_MASTER_TRANSMIT
    dec   COUNTER_REG
    brne  CIADDR_TO_ZERO_OR_MY_IP
    /* }}} */
    /* YIADDR, SIADDR and GIADDR to Zero  {{{ */
    clr   ARG_REG1
    ldi   COUNTER_REG, 12
YIADDR_SIADDR_GIADDR_TO_ZERO:
    rcall SPI_MASTER_TRANSMIT
    dec   COUNTER_REG
    brne  YIADDR_SIADDR_GIADDR_TO_ZERO
    /* }}} */
    /* CHADDR, write own MAC {{{ */
    ldi   YL, lo8(EEPROM_MAC_ADDR)
    ldi   YH, hi8(EEPROM_MAC_ADDR)
    ldi   COUNTER_REG, MAC_SIZE_IN_BYTES
DHCP_REQUEST_IP_SET_HEADER_LOOP_3:
    rcall EEPROM_READ_N_INC
    mov   ARG_REG1, RETURN_VALUE
    rcall SPI_MASTER_TRANSMIT
    dec   COUNTER_REG
    brne  DHCP_REQUEST_IP_SET_HEADER_LOOP_3
    /* }}} */
    /* header has 16 bytes for mac, as using only 6, there are 10 bytes to {{{
     * write as zero, then we have 192 bytes of zero (option overload/BOOTS
     * legacy) */
    clr   ARG_REG1
    ldi   COUNTER_REG, 202
DHCP_REQUEST_IP_SET_HEADER_LOOP_4:
    rcall SPI_MASTER_TRANSMIT
    dec   COUNTER_REG
    brne  DHCP_REQUEST_IP_SET_HEADER_LOOP_4
    /* }}} */
    /* Write magic cookie  {{{ */
    ldi   YL, lo8(EEPROM_DHCP_MAGIC_COOKIE)
    ldi   YH, hi8(EEPROM_DHCP_MAGIC_COOKIE)
    ldi   COUNTER_REG, (EEPROM_DHCP_MAGIC_COOKIE_END - EEPROM_DHCP_MAGIC_COOKIE)
DHCP_REQUEST_IP_SET_HEADER_LOOP_5:
    rcall EEPROM_READ_N_INC
    mov   ARG_REG1, RETURN_VALUE
    rcall SPI_MASTER_TRANSMIT
    dec   COUNTER_REG
    brne  DHCP_REQUEST_IP_SET_HEADER_LOOP_5
    /* }}} */
    /* DHCP Options {{{ */
    /* DHCP MSG TYPE {{{ */
    ldi   ARG_REG1, DHCP_OPTION_DHCP_MSG_TYPE
    rcall SPI_MASTER_TRANSMIT
    ldi   ARG_REG1, DHCP_OPTION_DHCP_MSG_TYPE_LEN
    rcall SPI_MASTER_TRANSMIT
    /* all messages from client but discover will have a request msg type */
    ldi   ARG_REG1, DHCP_OPTION_DHCP_MSG_TYPE_DHCP_DISCOVER
    sbrs  DHCP_STATE_R, DHCP_STATE_INIT
    ldi   ARG_REG1, DHCP_OPTION_DHCP_MSG_TYPE_DHCP_REQUEST
    rcall SPI_MASTER_TRANSMIT
    /* }}} */
    /* DHCP Discover options {{{ */
    sbrc  DHCP_STATE_R, DHCP_STATE_INIT
    rjmp  DHCP_END_OP
    sbrc  DHCP_STATE_R, DHCP_STATE_INIT_REBOOT
    rjmp  DHCP_END_OP
    sbrc  DHCP_STATE_R, DHCP_STATE_RENEWING
    rjmp  DHCP_END_OP
    sbrc  DHCP_STATE_R, DHCP_STATE_REBIDING
    rjmp  DHCP_END_OP
    /* }}} */
DHCP_REQUEST_OPS: /* DHCP Request options {{{ */
    ldi   YL, lo8(EEPROM_DHCP_REQUEST_OPS)
    ldi   YH, hi8(EEPROM_DHCP_REQUEST_OPS)
    ldi   COUNTER_REG, (EEPROM_DHCP_REQUEST_OPS_END - EEPROM_DHCP_REQUEST_OPS)
DHCP_REQUEST_EEPROM_OPS:
    rcall EEPROM_READ_N_INC
    mov   ARG_REG1, RETURN_VALUE
    rcall SPI_MASTER_TRANSMIT
    dec   COUNTER_REG
    brne  DHCP_REQUEST_EEPROM_OPS

    ldi   YL, lo8(EEPROM_IP_ADDR)
    ldi   YH, hi8(EEPROM_IP_ADDR)
    ldi   COUNTER_REG, DHCP_OPTION_ADDRESS_REQUEST_LEN
DHCP_REQUESTED_IP:
    rcall EEPROM_READ_N_INC
    mov   ARG_REG1, RETURN_VALUE
    rcall SPI_MASTER_TRANSMIT
    dec   COUNTER_REG
    brne  DHCP_REQUESTED_IP

    /* DHCP server ip address  */
    ldi   ARG_REG1, DHCP_OPTION_DHCP_SERVER_ID
    rcall SPI_MASTER_TRANSMIT
    ldi   ARG_REG1, DHCP_OPTION_DHCP_SERVER_ID_LEN
    rcall SPI_MASTER_TRANSMIT

    ldi   YL, lo8(SRAM_DHCP_SERVER_IP_ADDR)
    ldi   YH, hi8(SRAM_DHCP_SERVER_IP_ADDR)
    ldi   COUNTER_REG, DHCP_OPTION_DHCP_SERVER_ID_LEN
DHCP_SERVER_IP:
    ld    ARG_REG1, Y+
    rcall SPI_MASTER_TRANSMIT
    dec   COUNTER_REG
    brne  DHCP_SERVER_IP
    /* }}} */
    /* End OP */
DHCP_END_OP:
    ldi   ARG_REG1, DHCP_OPTION_END
    rcall SPI_MASTER_TRANSMIT
    /* }}} */
    /* }}} */
    ETH_END_LISTEN_ON_SPI
    rcall ETH_WRITE_BUFFER_PACKET_PAYLOAD_FINISH
    ret
/* }}} */
/*******************************************************************************
 * Handle dhcp packet {{{
 * BEWARE, EXPECTING ETH MODULE LISTENING TO SPI
 ******************************************************************************/
DHCP_HANDLE_PKT:
    push YL
    push YH

    /* Check OP, HTYPE, HLEN, HOPS and XID  {{{ */
    ETH_READ_NEXT_BYTE
    cpi   RETURN_VALUE, DHCP_OP_BOOTREPLY
    brne  DHCP_HANDLE_EXIT_SUCCESS

    ldi   YL, lo8(EEPROM_DHCP_HEADER + 1)
    ldi   YH, hi8(EEPROM_DHCP_HEADER + 1)
    ldi   COUNTER_REG, 6
CHECK_DHCP_HEADER:
    rcall EEPROM_READ_N_INC
    mov   TMP_REG1, RETURN_VALUE
    ETH_READ_NEXT_BYTE
    cp    TMP_REG1, RETURN_VALUE
    brne  DHCP_HANDLE_EXIT_SUCCESS
    dec   COUNTER_REG
    brne  CHECK_DHCP_HEADER

    /* Check last byte of the XID */
    ETH_READ_NEXT_BYTE
    lds   TMP_REG1, SRAM_DHCP_XID_LAST_BYTE
    cp    TMP_REG1, RETURN_VALUE
    brne  DHCP_HANDLE_EXIT_SUCCESS
    /* }}} */
    /* Jump to YIADDR {{{ */
    ETH_READ_BUFFER_END
    ldi   ARG_REG1, 0
    ldi   ARG_REG2, 8 /* SECS + FLAGS + CIADDR */
    rcall ETH_MOVE_READ_POINTER
    rcall ETH_READ_BUFFER_START
    /* }}} */
    /* Read offered IP and write it into EEPROM {{{ */
    ldi   COUNTER_REG, IPV4_SIZE_IN_BYTES
    ldi   YL, lo8(EEPROM_IP_ADDR)
    ldi   YH, hi8(EEPROM_IP_ADDR)
UPDATE_EEPROM_IP_ADDR:
    ETH_READ_NEXT_BYTE
    mov   ARG_REG1, RETURN_VALUE
    rcall EEPROM_WRITE_N_INC
    dec   COUNTER_REG
    brne  UPDATE_EEPROM_IP_ADDR
    /* }}} */
    /* Jump from siaddr ip addr to magic cookie {{{ */
    ETH_READ_BUFFER_END
    ldi   ARG_REG1, 0
    ldi   ARG_REG2, 216
    rcall ETH_MOVE_READ_POINTER
    rcall ETH_READ_BUFFER_START
    /* }}} */
    /* Check magic cookie {{{ */
    ldi   YL, lo8(EEPROM_DHCP_MAGIC_COOKIE)
    ldi   YH, hi8(EEPROM_DHCP_MAGIC_COOKIE)
    ldi   COUNTER_REG, (EEPROM_DHCP_MAGIC_COOKIE_END - EEPROM_DHCP_MAGIC_COOKIE)
CHECK_MAGIC_COOKIE:
    rcall EEPROM_READ_N_INC
    mov   TMP_REG1, RETURN_VALUE
    ETH_READ_NEXT_BYTE
    cp    TMP_REG1, RETURN_VALUE
    brne  DHCP_HANDLE_EXIT_FAILURE
    dec   COUNTER_REG
    brne  CHECK_MAGIC_COOKIE
    /* Jump to start reading options (skipping exit block) */
    rjmp  START_READING_DHCP_OPTIONS
    /* }}} */
DHCP_HANDLE_EXIT_SUCCESS: /* {{{ */
NO_MORE_OPTIONS:
    ldi  RETURN_VALUE, 0
DHCP_HANDLE_EXIT:
    ETH_READ_BUFFER_END
    pop  YH
    pop  YL
    ret
DHCP_HANDLE_EXIT_FAILURE:
    ldi  RETURN_VALUE, 1
    rjmp DHCP_HANDLE_EXIT
    /* }}} */
START_READING_DHCP_OPTIONS: /* {{{ */
KEEP_READING_DHCP_OPTIONS:
    ETH_READ_NEXT_BYTE
    /* Check if end of options */
    cpi   RETURN_VALUE, DHCP_OPTION_END
    breq  NO_MORE_OPTIONS
    /* Check if padding, which doesn't have length. Go to read next byte */
    cpi   RETURN_VALUE, DHCP_OPTION_PAD
    breq  KEEP_READING_DHCP_OPTIONS
    /* DHCP message {{{ */
    cpi   RETURN_VALUE, DHCP_OPTION_DHCP_MSG_TYPE
    brne  TRY_DHCP_OPTION_DHCP_SERVER_ID
    /* DHCP message, we care about dhcp offer */
    ETH_READ_NEXT_BYTE /* read size of option, must be 1 */
    ETH_READ_NEXT_BYTE
    cpi   RETURN_VALUE, DHCP_OPTION_DHCP_MSG_TYPE_DHCP_OFFER
    brne  TRY_DHCP_ACK
    ldi   TMP_REG1, (1 << DHCP_STATE_REQUESTING)
    sts   SRAM_DHCP_STATE, TMP_REG1
    rjmp  KEEP_READING_DHCP_OPTIONS
TRY_DHCP_ACK:
    cpi   RETURN_VALUE, DHCP_OPTION_DHCP_MSG_TYPE_DHCP_ACK
    brne  KEEP_READING_DHCP_OPTIONS
    /* Set states {{{ */
    ldi   TMP_REG1, (1 << DHCP_STATE_BOUND)
    sts   SRAM_DHCP_STATE, TMP_REG1
    ldi   TMP_REG1, (1 << DHCP_TIMER_LAP) | EEPROM_DHCP_TIMERS
    sts   SRAM_DHCP_TIMER_SUBTRAHEND_PTR_L, TMP_REG1
    /* }}} */
    rjmp  KEEP_READING_DHCP_OPTIONS
    /* }}} */
TRY_DHCP_OPTION_DHCP_SERVER_ID: /* {{{ */
    cpi   RETURN_VALUE, DHCP_OPTION_DHCP_SERVER_ID
    brne  TRY_DHCP_OPTION_ADDRESS_TIME
    ETH_READ_NEXT_BYTE /* must be 4 */
    ldi   COUNTER_REG, DHCP_OPTION_DHCP_SERVER_ID_LEN
    ldi   YL, lo8(SRAM_DHCP_SERVER_IP_ADDR)
    ldi   YH, hi8(SRAM_DHCP_SERVER_IP_ADDR)
STORE_DHCP_SERVER_IP_ADDR:
    ETH_READ_NEXT_BYTE
    st    Y+, RETURN_VALUE
    dec   COUNTER_REG
    brne  STORE_DHCP_SERVER_IP_ADDR
    rjmp  KEEP_READING_DHCP_OPTIONS
    /* }}} */
TRY_DHCP_OPTION_ADDRESS_TIME: /* {{{ */
    cpi   RETURN_VALUE, DHCP_OPTION_ADDRESS_TIME
    brne  TRY_DHCP_OPTION_SUBNET_MASK
    ETH_READ_NEXT_BYTE /* must be 4 */
    ldi   COUNTER_REG, DHCP_OPTION_ADDRESS_TIME_LEN
    ldi   YL, lo8(SRAM_DHCP_ADDRESS_TIME)
    ldi   YH, hi8(SRAM_DHCP_ADDRESS_TIME)
STORE_DHCP_ADDRESS_TIME:
    ETH_READ_NEXT_BYTE
    st    Y+, RETURN_VALUE
    dec   COUNTER_REG
    brne  STORE_DHCP_ADDRESS_TIME
    rjmp  KEEP_READING_DHCP_OPTIONS
    /* }}} */
TRY_DHCP_OPTION_SUBNET_MASK: /* {{{ */
    cpi   RETURN_VALUE, DHCP_OPTION_SUBNET_MASK
    brne  TRY_DHCP_OPTION_DOMAIN_SERVER
    ETH_READ_NEXT_BYTE /* must be 4 */
    ldi   COUNTER_REG, DHCP_OPTION_SUBNET_MASK_LEN
    ldi   YL, lo8(SRAM_DHCP_SUBNET_MASK)
    ldi   YH, hi8(SRAM_DHCP_SUBNET_MASK)
STORE_DHCP_OPTION_SUBNET_MASK:
    ETH_READ_NEXT_BYTE
    st    Y+, RETURN_VALUE
    dec   COUNTER_REG
    brne  STORE_DHCP_OPTION_SUBNET_MASK
    rjmp  KEEP_READING_DHCP_OPTIONS
    /* }}} */
TRY_DHCP_OPTION_DOMAIN_SERVER: /* {{{ */
    cpi   RETURN_VALUE, DHCP_OPTION_DOMAIN_SERVER
    brne  IGNORE_DHCP_OP
    ETH_READ_NEXT_BYTE
    mov   COUNTER_REG, RETURN_VALUE
    ldi   YL, lo8(SRAM_DHCP_DOMAIN_SERVER)
    ldi   YH, hi8(SRAM_DHCP_DOMAIN_SERVER)
    /* BEWARE NOT TO CALL ANY ROUTINE THAT CHANGES TMP_REG1 */
    ldi   TMP_REG1, DHCP_DOMAIN_SERVER_LEN
STORE_DHCP_OPTION_DOMAIN_SERVER:
    ETH_READ_NEXT_BYTE
    tst   TMP_REG1
    breq  SKIP_DHCP_OPTION_DOMAIN_SERVER_ST
    st    Y+, RETURN_VALUE
    dec   TMP_REG1
SKIP_DHCP_OPTION_DOMAIN_SERVER_ST:
    dec   COUNTER_REG
    brne  STORE_DHCP_OPTION_DOMAIN_SERVER
    rjmp  KEEP_READING_DHCP_OPTIONS
    /* }}} */
IGNORE_DHCP_OP: /* {{{ */
    ETH_READ_NEXT_BYTE /* read size of option */
    mov   COUNTER_REG, RETURN_VALUE
DHCP_OP_READ_CONTENT:
    ETH_READ_NEXT_BYTE
    dec   COUNTER_REG
    brne  DHCP_OP_READ_CONTENT
    rjmp  KEEP_READING_DHCP_OPTIONS
    /* }}} */
    /* }}} */
/* }}} */
/*******************************************************************************
 * Timer handlers {{{
 * Carry will be set when timer expires
 ******************************************************************************/
DHCP_TIMERS:
    lds   YL, SRAM_DHCP_TIMER_SUBTRAHEND_PTR_L
    sbrc  YL, DHCP_TIMER_LAP
    rjmp  DHCP_SET_COUNTDOWN
    rjmp  DHCP_COUNTDOWN
DHCP_SET_COUNTDOWN:
    /* Clear lap bit, increment pointer by 1 {{{ */
    cbr   YL, (1 << DHCP_TIMER_LAP)
    sts   SRAM_DHCP_TIMER_SUBTRAHEND_PTR_L, YL
    /* }}} */
    /* Copy lease time to dhcp seconds {{{ */
    ldi   ZL, lo8(SRAM_DHCP_ADDRESS_TIME)
    ldi   ZH, hi8(SRAM_DHCP_ADDRESS_TIME)
    ldi   COUNTER_REG, 4
DHCP_SET_COUNTDOWN_LOOP:
    ld    TMP_REG2, Z+
    std   Z + (SRAM_DHCP_SECONDS - SRAM_DHCP_ADDRESS_TIME - 1), TMP_REG2
    dec   COUNTER_REG
    brne  DHCP_SET_COUNTDOWN_LOOP
    /* }}} */
DHCP_COUNTDOWN:
    /* Start from least significant byte.
     * Subtract 1 from first byte, then subtract zero.
     * All subtraction are with carry
     */
    /* Loading 1 address beyond because of ld with pre-decrement */
    ldi   ZL, lo8(SRAM_DHCP_SECONDS + 4)
    ldi   ZH, hi8(SRAM_DHCP_SECONDS + 4)
    ldi   COUNTER_REG, 4
    clr   YH
    rcall EEPROM_READ_N_INC
    clc
DHCP_TIMERS_DEC:
    ld    TMP_REG1, -Z
    sbc   TMP_REG1, RETURN_VALUE
    clr   RETURN_VALUE
    st    Z, TMP_REG1
    dec   COUNTER_REG
    brne  DHCP_TIMERS_DEC
    /* After subtraction, Check if underflow, if so, then set
     * DHCP_TIMER_LAP so DHCP packet is sent and next time
     * DHCP_TIMERS is called, then the timer is reset */
    brcc  DHCP_TIMERS_EXIT
    lds   TMP_REG1, SRAM_DHCP_TIMER_SUBTRAHEND_PTR_L
    inc   YL
    sbr   TMP_REG1, (1 << DHCP_TIMER_LAP)
    sts   SRAM_DHCP_TIMER_SUBTRAHEND_PTR_L, TMP_REG1
DHCP_TIMERS_EXIT:
    ret
/* }}} */

.end
