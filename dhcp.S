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
#define REQUESTING_MAX_TIME     15

/* Bit 7 used for counter underflow flag.
 * EEPROM timer holds the subtrahends for the timer, there are 6 stages, 3 with
 * T1 and 3 with T2.
 * Upper byte of EEPROM address is guarantee to be zero with the following
 * check, then we can write simpler code. */
#if (EEPROM_DHCP_TIMERS + 8) > 127
#   error "Optimization for EEPROM_DHCP_TIMERS won't work"
#endif

/* GLOBAL {{{1 ---------------------------------------------------------------*/
.global DHCP_HANDLE_PKT
.global DHCP_INIT
.global DHCP

.global SRAM_DHCP_IP_ADDR

/* DATA  {{{1 ----------------------------------------------------------------*/
/* XXX: SRAM_DHCP_XID_LAST_BYTE placed first, so we can skip it in DHCP_INIT
 * when setting the memory to zero */
.section .data
SRAM_DHCP:
SRAM_DHCP_XID_LAST_BYTE:          .skip 1
SRAM_DHCP_IP_ADDR:                .skip IPV4_ADDR_LEN
SRAM_DHCP_SERVER_IP_ADDR:         .skip DHCP_OPTION_DHCP_SERVER_ID_LEN
SRAM_DHCP_STATE:                  .skip 1
SRAM_DHCP_ADDRESS_TIME:           .skip DHCP_OPTION_ADDRESS_TIME_LEN
SRAM_DHCP_SECONDS:                .skip DHCP_OPTION_ADDRESS_TIME_LEN
SRAM_DHCP_SUBNET_MASK:            .skip DHCP_OPTION_SUBNET_MASK_LEN
SRAM_DHCP_DOMAIN_SERVER:          .skip DHCP_DOMAIN_SERVER_LEN
/* Pointer to T1/T2 subtrahend. Bit 7 used as flag.
 * Only one byte is needed as EEPROM_DHCP_TIMERS is guarantee to have upper byte
 * equal to zero */
SRAM_DHCP_TIMER_SUBTRAHEND_PTR_L: .skip 1
SRAM_DHCP_END:

/* TEXT {{{1 -----------------------------------------------------------------*/
.section .text

/* DHCP {{{2 -------------------------------------------------------------------
 * This routine is called every 1 second.
 *
 * Depending on the current DHCP state, the routine will send a DHCP packet, or
 * wait for some time to pass or change state, etc.
 * ---------------------------------------------------------------------------*/
DHCP:
    push  yl
    push  yh
    push  s1 /* Pkt size low */
    push  s2 /* Pkt size high */
    push  s3 /* DHCP state */

    /* Set Y to start of dhcp data section */
    ldi   yl, lo8(SRAM_DHCP)
    ldi   yh, hi8(SRAM_DHCP)

    /* Load common packet size
     * All DHCP packages but DHCPREQUEST will have the same packet size */
    ldi   t1, lo8(DHCP_IP_COMMON_PKT_SIZE)
    mov   s1, t1
    ldi   t1, hi8(DHCP_IP_COMMON_PKT_SIZE)
    mov   s2, t1

    ldd   s3, y + SRAM_DHCP_STATE - SRAM_DHCP /* Load current DHCP state */

    /* DHCP_INIT_STATE -------------------------------------------------------*/
    sbrs  s3, DHCP_STATE_INIT
    rjmp  0f
    ldi   zl, lo8(SRAM_DHCP_IP_ADDR)
    ldi   zh, hi8(SRAM_DHCP_IP_ADDR)
    ldi   a1, IPV4_ADDR_LEN
    rcall BZERO
    /* Try to send a REQUEST every 16 seconds (DHCP_TIMER_ANDI)
     * DHCP_WAITING_IN_STATE re-uses SRAM_DHCP_TIMER_SUBTRAHEND_PTR_L */
    rcall DHCP_WAITING_IN_STATE
    brne  9f /* still waiting, return */
    /* Send discover and jump directly to selecting state. */
    rcall DHCP_XID_INCREMENT
    rcall DHCP_SEND
    ldi   t1, (1 << DHCP_STATE_SELECTING)
    std   y + SRAM_DHCP_STATE - SRAM_DHCP, t1

    /* DHCP_SELECTING_STATE --------------------------------------------------*/
0:  sbrs  s3, DHCP_STATE_SELECTING
    rjmp  0f
    /* Wait DHCP_WAITING_IN_STATE for an DHCP offer. If offer not received, then
     * go to Init state. If offer received, DHCP handle will change state */
    rcall DHCP_WAITING_IN_STATE
    brne  9f /* exit success */
    rjmp  8f /* set init state and exit success */

    /* DHCP_REQUESTING_STATE -------------------------------------------------*/
0:  sbrs  s3, DHCP_STATE_REQUESTING
    rjmp  0f
    /* Send a DHCP request. Request size is different from common size.
     * Request are sent every few seconds, if no ack is received after
     * REQUESTING_MAX_TIME seconds, then it will go to init state */
    rcall DHCP_WAITING_IN_STATE
    brne  9f /* exit success */
    ldd   t1, y + SRAM_DHCP_TIMER_SUBTRAHEND_PTR_L - SRAM_DHCP
    cpi   t1, REQUESTING_MAX_TIME
    brsh  8f
    adiw  s1, DHCP_REQUEST_EXTRA_OPS_SIZE
    rcall DHCP_SEND

    /* DHCP_BOUND_STATE ------------------------------------------------------*/
0:  sbrs  s3, DHCP_STATE_BOUND
    rjmp  0f
    /* In bound state we just wait until the timer for the IP Address Lease Time
     * expires */
    rcall DHCP_TIMERS
    brcc  9f /* exit success */
    /* Change DHCP state */
    ldi   t1, (1 << DHCP_STATE_RENEWING)
    std   y + SRAM_DHCP_STATE - SRAM_DHCP, t1
    /* XXX: Update state in s3 and jump to DHCP_STATE_RENEWING where packets are
     * sent, skipping the timer */
    mov   s3, t1
    rjmp  1f

    /* DHCP_RENEWING_STATE and DHCP_REBINDING_STATE --------------------------*/
0:  ldi   t1, (1 << DHCP_STATE_RENEWING)|(1 << DHCP_STATE_REBINDING)
    and   t1, s3
    breq  0f
    rcall DHCP_TIMERS
    brcc  9f /* exit success */
1:  rcall DHCP_XID_INCREMENT
    rcall DHCP_SEND /* Read: DHCPREQUEST generated on RENEWING state rfc2131 */
    /* Check if x still pointing to T1 */
    ldd   t1, y + SRAM_DHCP_TIMER_SUBTRAHEND_PTR_L - SRAM_DHCP
    cbr   t1, (1 << DHCP_TIMER_LAP)
    cpi   t1, EEPROM_DHCP_TIMERS_T2
    brlo  9f /* Still in T1, nothing to do, exit success */
    cpi   t1, EEPROM_DHCP_TIMERS_END
    brlo  1f /* Still in T2, change state */
    /* Beyond T2, which means no more timers, go to DHCP init state */
    rjmp  8f /* set init state and exit success */
1:  ldi   t1, (1 << DHCP_STATE_REBINDING)
    std   y + SRAM_DHCP_STATE - SRAM_DHCP, t1

    /* DHCP_INIT_REBOOT_STATE ------------------------------------------------*/
0:  sbrs  s3, DHCP_STATE_INIT_REBOOT
    rjmp  0f
    rcall DHCP_XID_INCREMENT
    rcall DHCP_SEND
    ldi   t1, (1 << DHCP_STATE_REBOOTING)
    std   y + SRAM_DHCP_STATE - SRAM_DHCP, t1

    /* DHCP_REBOOTING_STATE --------------------------------------------------*/
0:  sbrs  s3, DHCP_STATE_REBOOTING
    rjmp  9f
    rcall DHCP_WAITING_IN_STATE
    brne  9f /* exit success */
8:  ldi   t1, (1 << DHCP_STATE_INIT) /* Used from other states as well */
    std   y + SRAM_DHCP_STATE - SRAM_DHCP, t1

9:  pop   s3
    pop   s2
    pop   s1
    pop   yh
    pop   yl
    ret

/* DHCP_INIT {{{2 --------------------------------------------------------------
 * Initialize DHCP data to zero, skip SRAM_DHCP_XID_LAST_BYTE.
 * If EEPROM_IP_ADDR != 0.0.0.0; then set DHCP_STATE_INIT_REBOOT and copy
 * EEPROM_IP_ADDR to SRAM_DHCP_IP_ADDR.
 * ---------------------------------------------------------------------------*/
DHCP_INIT:
    ldi   zl, lo8(SRAM_DHCP_IP_ADDR)
    ldi   zh, hi8(SRAM_DHCP_IP_ADDR)
    ldi   a1, SRAM_DHCP_END - SRAM_DHCP_IP_ADDR
    rcall BZERO

    /* Check if our IP Address in the EEPROM is != 0.0.0.0
     * We just zero out SRAM_DHCP_IP_ADDR, so using it to compare */
    ldi   xl, lo8(EEPROM_IP_ADDR)
    ldi   xh, hi8(EEPROM_IP_ADDR)
    ldi   zl, lo8(SRAM_DHCP_IP_ADDR)
    ldi   zh, hi8(SRAM_DHCP_IP_ADDR)
    ldi   a1, IPV4_ADDR_LEN
    rcall E_MEMCMP
    ldi   t1, (1 << DHCP_STATE_INIT)
    breq  0f
    rcall E_MEMCPY
    subi  zl, IPV4_ADDR_LEN
    ldi   t1, (1 << DHCP_STATE_INIT_REBOOT)
0:  std   z + SRAM_DHCP_STATE - SRAM_DHCP_IP_ADDR, t1
    DEBUG(rcall PRINT_VARIABLES)
    ret

/* DHCP_SEND {{{2 --------------------------------------------------------------
 * Send a DHCP packet, many fields will depend on which DHCP state we are.
 * ---------------------------------------------------------------------------*/
DHCP_SEND:
    DEBUG(PRINT_STR STR_DHCP_SEND_START)
    DEBUG(rcall PRINT_VARIABLES)
    /* Ethernet Header */
    ldi   t2, (1 << ENC_MAC_DST_PTR_BROADCAST_BIT)
    sts   SRAM_ENC_MAC_DST_PTR, t2
    ldi   t2, (EEPROM_TYPE_LEN_IPV4 - EEPROM_TYPE_LEN)
    sts   SRAM_ENC_TYPE_LEN_OFFSET, t2
    rcall ETH_WRITE_BUFFER_PACKET_HEADER

    rcall ETH_SET_LISTEN_ON_SPI
    /* IPv4 Header
     * This header has src as 0.0.0.0, dst as 255.255.255.255, checksum and
     * total length have to be setup
     */
    /* Read default IPv4 header plus part of UDP header from EEPROM */
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

    /* Set non default IPv4 header fields */
    /* IP Total Length */
    std   z + (IPV4_TOTAL_LENGTH + 0), s2
    std   z + (IPV4_TOTAL_LENGTH + 1), s1

    /* Src and Dst IP addresses for RENEWING */
    sbrs  s3, DHCP_STATE_RENEWING
    rjmp  0f /* Deafult Src/Dst IP Addresses */
    /* Copy Src IP address */
    adiw  zl, IPV4_SRC_ADDR
    ldi   a1, IPV4_ADDR_LEN
    ldi   xl, lo8(SRAM_DHCP_IP_ADDR)
    ldi   xh, hi8(SRAM_DHCP_IP_ADDR)
    rcall MEMCPY
    /* Copy DHCP server IP address */
    ldi   xl, lo8(SRAM_DHCP_SERVER_IP_ADDR)
    ldi   xh, hi8(SRAM_DHCP_SERVER_IP_ADDR)
    rcall MEMCPY
    /* Set z back to SRAM_IPV4_HEADER */
    sbiw  zl, IPV4_ADDR_LEN * 2 + IPV4_SRC_ADDR

    /* Internet Checksum */
0:  ldi   a1, (EEPROM_IP_HEADER_END - EEPROM_IP_HEADER)
    ldi   a2, 0
    rcall INTERNET_CHECKSUM_RFC1071
    std   z + (IPV4_H_CHECKSUM + 0), a3
    std   z + (IPV4_H_CHECKSUM + 1), a4

    /* Transmit IPv4 Header plus part of UDP */
    ldi   a1, (EEPROM_UDP_DHCP_PORT_END - EEPROM_IP_HEADER)
    rcall ETH_WRITE_Z_TO_TRANSMIT_BUFFER
    rcall ETH_SET_LISTEN_ON_SPI

    /* UDP Header*/
    /* SRC/DST already written */
    /* Write UDP Length */
    /* DHCP PKT SIZE was set to IP size, so, subtract DHCP_IP_HEADER_SIZE to
     * get the UDP size */
    sbiw  s1, DHCP_IP_HEADER_SIZE
    mov   a1, s2
    rcall SPI_MASTER_TRANSMIT
    mov   a1, s1
    rcall SPI_MASTER_TRANSMIT

    /* UDP Checksum, Zero for ignore */
    ldi   a1, 2
    rcall SPI_MASTER_TRANSMIT_ZEROS

    /* DHCP Body -------------------------------------------------------------*/
    /* Write first 8 bytes: OP, HTYPE, HLEN, HOPS AND XID (3 of 4 bytes) */
    ldi   xl, lo8(EEPROM_DHCP_HEADER)
    ldi   xh, hi8(EEPROM_DHCP_HEADER)
    ldi   a1, (EEPROM_DHCP_HEADER_END - EEPROM_DHCP_HEADER)
    rcall SPI_EEPROM_TRANSMIT

    /* Last byte of XID */
    ldd   a1, y + SRAM_DHCP_XID_LAST_BYTE - SRAM_DHCP
    DEBUG(rcall PRINT_CURRENT_XID)
    rcall SPI_MASTER_TRANSMIT

    /* set SECS and FLAGS to Zero */
    ldi   a1, 4
    rcall SPI_MASTER_TRANSMIT_ZEROS

    /* CIADDR
     * Field      DHCPDISCOVER          DHCPREQUEST           DHCPDECLINE,
     *            DHCPINFORM                                  DHCPRELEASE
     * -----      ------------          -----------           -----------
     * 'ciaddr'   0 (DHCPDISCOVER)      0 or client's         0 (DHCPDECLINE)
     *            client's              network address       client's network
     *            network address       (BOUND/RENEW/REBIND)  address
     *            (DHCPINFORM)                                (DHCPRELEASE)
     *
     * SRAM_DHCP_IP_ADDR gets written when ACK is received, gets set to zero on
     * init state and set to previous IP address on reboot.
     */
    ldi   xl, lo8(SRAM_DHCP_IP_ADDR)
    ldi   xh, hi8(SRAM_DHCP_IP_ADDR)
    ldi   a1, IPV4_ADDR_LEN
    rcall SRAM_SPI_MEMCPY

    /* YIADDR, SIADDR and GIADDR to Zero  */
    ldi   a1, 12
    rcall SPI_MASTER_TRANSMIT_ZEROS

    /* CHADDR, write own MAC */
    ldi   xl, lo8(EEPROM_MAC_ADDR)
    ldi   xh, hi8(EEPROM_MAC_ADDR)
    ldi   a1, MAC_ADDR_LEN
    rcall SPI_EEPROM_TRANSMIT

    /* header has 16 bytes for mac, as using only 6, there are 10 bytes to 
     * write as zero, then we have 192 bytes of zero (option overload/BOOTS
     * legacy) */
    ldi   a1, 202
    rcall SPI_MASTER_TRANSMIT_ZEROS

#if EEPROM_DHCP_MAGIC_COOKIE_END != EEPROM_DHCP_OPTION_MSG_N_LEN
#   error "EEPROM_DHCP_MAGIC_COOKIE_END != EEPROM_DHCP_OPTION_MSG_N_LEN"
#endif
    /* Write magic cookie and beginning of option msg */
    ldi   xl, lo8(EEPROM_DHCP_MAGIC_COOKIE)
    ldi   xh, hi8(EEPROM_DHCP_MAGIC_COOKIE)
    ldi   a1, (EEPROM_DHCP_OPTION_MSG_N_LEN_END - EEPROM_DHCP_MAGIC_COOKIE)
    rcall SPI_EEPROM_TRANSMIT

    /* DHCP Options */
    /* DHCP MSG TYPE */
    /* MSG type and length is written from EEPROM */
    /* all messages from client but discover will have a request msg type */
    ldi   a1, DHCP_OPTION_DHCP_MSG_TYPE_DHCP_DISCOVER
    sbrs  s3, DHCP_STATE_INIT
    ldi   a1, DHCP_OPTION_DHCP_MSG_TYPE_DHCP_REQUEST
    rcall SPI_MASTER_TRANSMIT

    /* DHCP packets that don't require more options 
     * BEWARE s3 gets modified here */
    andi  s3, (1 << DHCP_STATE_INIT)        | \
              (1 << DHCP_STATE_INIT_REBOOT) | \
              (1 << DHCP_STATE_REBOOTING)   | \
              (1 << DHCP_STATE_RENEWING)    | \
              (1 << DHCP_STATE_REBINDING)
    brne  0f /* End of options */

    /* DHCP Request options */
#if EEPROM_DHCP_REQUEST_OPS_END_1 != EEPROM_IP_ADDR
#   error "DHCP request required EEPROM_DHCP_REQUEST_OPS_END_1 == EEPROM_IP_ADDR"
#endif
#if EEPROM_IP_ADDR_END != EEPROM_DHCP_REQUEST_OPS_2
#   error "DHCP request required EEPROM_IP_ADDR_END == EEPROM_DHCP_REQUEST_OPS_2"
#endif
    /* Hostname and IP address */
    ldi   xl, lo8(EEPROM_DHCP_REQUEST_OPS_1)
    ldi   xh, hi8(EEPROM_DHCP_REQUEST_OPS_1)
    ldi   a1, (EEPROM_DHCP_REQUEST_OPS_2_END - EEPROM_DHCP_REQUEST_OPS_1)
    rcall SPI_EEPROM_TRANSMIT

    ldi   zl, lo8(SRAM_DHCP_SERVER_IP_ADDR)
    ldi   zh, hi8(SRAM_DHCP_SERVER_IP_ADDR)
    ldi   a1, DHCP_OPTION_DHCP_SERVER_ID_LEN
    rcall ETH_WRITE_Z_TO_TRANSMIT_BUFFER
    rcall ETH_SET_LISTEN_ON_SPI

0:  ldi   a1, DHCP_OPTION_END /* End Options */
    rcall SPI_MASTER_TRANSMIT

    ETH_END_LISTEN_ON_SPI
    rcall ETH_WRITE_BUFFER_PACKET_PAYLOAD_FINISH
    ret

/* DHCP_HANDLE_PKT {{{2 --------------------------------------------------------
 * Handle DHCP packet, we expect to receive OFFER or ACK.
 *
 * Caller must call ETH_READ_BUFFER_START before calling this routine and
 * ETH_READ_BUFFER_END afterwards.
 * ---------------------------------------------------------------------------*/
DHCP_HANDLE_PKT:
    DEBUG(PRINT_STR_SAFE STR_DHCP_HANDLE_START)
    /* Check OP, HTYPE, HLEN, HOPS and XID */
    ETH_READ_NEXT_BYTE
    cpi   a4, DHCP_OP_BOOTREPLY
    brne  9f /* return */

    /* Compare beginning of header */
    ldi   xl, lo8(EEPROM_DHCP_HEADER + 1)
    ldi   xh, hi8(EEPROM_DHCP_HEADER + 1)
    ldi   a1, 6
    rcall SE_MEMCMP
    brne  9f /* return */

    /* Check last byte of the XID */
    ETH_READ_NEXT_BYTE
    lds   t1, SRAM_DHCP_XID_LAST_BYTE
    DEBUG(rcall PRINT_INCOMING_N_EXPECTED_XID)
    cp    t1, a4
    brne  9f /* return */

    /* Jump to YIADDR */
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

    /* Read offered IP and write it into EEPROM */
    ldi   zl, lo8(EEPROM_IP_ADDR)
    ldi   zh, hi8(EEPROM_IP_ADDR)
    ldi   a1, IPV4_ADDR_LEN
    rcall SEE_MEMCPY

    /* Jump from siaddr ip addr to magic cookie */
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

    /* Check magic cookie */
    ldi   xl, lo8(EEPROM_DHCP_MAGIC_COOKIE)
    ldi   xh, hi8(EEPROM_DHCP_MAGIC_COOKIE)
    ldi   a1, (EEPROM_DHCP_MAGIC_COOKIE_END - EEPROM_DHCP_MAGIC_COOKIE)
    rcall SE_MEMCMP
    breq  3f /* Jump to read options loop (skipping exit block) */
    DEBUG(PRINT_STR_SAFE STR_FAILURE)

9:  DEBUG(rcall PRINT_VARIABLES)
    ret

    /* Read DHCP options loop ------------------------------------------------*/
3:  ldi   zl, lo8(SRAM_DHCP)
    ldi   zh, hi8(SRAM_DHCP)
    ETH_READ_NEXT_BYTE

    /* Check if end of options */
    cpi   a4, DHCP_OPTION_END
    breq  9b /* return */

    /* Check if padding, which doesn't have length. Go to read next byte */
    cpi   a4, DHCP_OPTION_PAD
    breq  3b /* keep reading DHCP options */

    /* DHCP message */
    cpi   a4, DHCP_OPTION_DHCP_MSG_TYPE
    brne  2f /* Try other options */
    /* DHCP message, we care about dhcp offer */
    ETH_READ_NEXT_BYTE /* read size of option, must be 1 */
    ETH_READ_NEXT_BYTE
    /* DHCP Offer */
    cpi   a4, DHCP_OPTION_DHCP_MSG_TYPE_DHCP_OFFER
    brne  0f
    ldi   t1, (1 << DHCP_STATE_REQUESTING)
    ldi   t2, DHCP_TIMER_ANDI /* Causes DHCP_WAITING_IN_STATE to set SREG(Z) */
    rjmp  1f
    /* DHCP Ack */
0:  cpi   a4, DHCP_OPTION_DHCP_MSG_TYPE_DHCP_ACK
    brne  3b /* keep reading DHCP options */
    DEBUG(PRINT_STR_SAFE STR_OPT_ACK)
    /* Copy offered address from EEPROM to SRAM */
    ldi   xl, lo8(EEPROM_IP_ADDR)
    ldi   xh, hi8(EEPROM_IP_ADDR)
    adiw  zl, SRAM_DHCP_IP_ADDR - SRAM_DHCP
    ldi   a1, IPV4_ADDR_LEN
    rcall E_MEMCPY
    sbiw  zl, SRAM_DHCP_IP_ADDR - SRAM_DHCP + IPV4_ADDR_LEN
    ldi   t1, (1 << DHCP_STATE_BOUND)
    ldi   t2, (1 << DHCP_TIMER_LAP) | EEPROM_DHCP_TIMERS
1:  std   z + SRAM_DHCP_STATE - SRAM_DHCP, t1
    std   z + SRAM_DHCP_TIMER_SUBTRAHEND_PTR_L - SRAM_DHCP, t2
    rjmp  3b /* keep reading DHCP options */

    /* Read generic options that don't require much processing */
    /* Server ID */
2:  cpi   a4, DHCP_OPTION_DHCP_SERVER_ID
    brne  0f
    adiw  zl, SRAM_DHCP_SERVER_IP_ADDR - SRAM_DHCP
    ldi   t1, DHCP_OPTION_DHCP_SERVER_ID_LEN
    rjmp  1f
    /* Address time */
0:  cpi   a4, DHCP_OPTION_ADDRESS_TIME
    brne  0f
    adiw  zl, SRAM_DHCP_ADDRESS_TIME - SRAM_DHCP
    ldi   t1, DHCP_OPTION_ADDRESS_TIME_LEN
    rjmp  1f
    /* Subnet mask */
0:  cpi   a4, DHCP_OPTION_SUBNET_MASK
    brne  0f
    adiw  zl, SRAM_DHCP_SUBNET_MASK - SRAM_DHCP
    ldi   t1, DHCP_OPTION_SUBNET_MASK_LEN
    rjmp  1f
    /* Domain server */
0:  cpi   a4, DHCP_OPTION_DOMAIN_SERVER
    brne  0f
    adiw  zl, SRAM_DHCP_DOMAIN_SERVER - SRAM_DHCP
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
    st    z+, a4
1:  dec   t3
    brne  0b
    rjmp  3b /* keep reading DHCP options */

/* DHCP_TIMERS {{{2 ------------------------------------------------------------
 * Carry will be set when timer expires
 * ---------------------------------------------------------------------------*/
DHCP_TIMERS:
    /* Common set for set-counter and decrement-counter */
    ldi   zl, lo8(SRAM_DHCP_SECONDS + 4)
    ldi   zh, hi8(SRAM_DHCP_SECONDS + 4)
    ldi   a1, 4 /* Used for MEMCPY and counter in subtraction loop */

    /* Check if underflow */
    ldd   xl, y + SRAM_DHCP_TIMER_SUBTRAHEND_PTR_L - SRAM_DHCP
    sbrs  xl, DHCP_TIMER_LAP
    rjmp  0f /* Jump to decrement counter */

    /* Underflow found, set counter: clear lap bit, increment pointer by 1 */
    cbr   xl, (1 << DHCP_TIMER_LAP)
    std   y + SRAM_DHCP_TIMER_SUBTRAHEND_PTR_L - SRAM_DHCP, xl

    /* Copy lease time to DHCP seconds */
    ldi   xl, lo8(SRAM_DHCP_ADDRESS_TIME)
    ldi   xh, hi8(SRAM_DHCP_ADDRESS_TIME)
    sbiw  zl, 4
    rcall MEMCPY
    ldd   xl, y + SRAM_DHCP_TIMER_SUBTRAHEND_PTR_L - SRAM_DHCP

    /* Subtract the value pointed by x in the EEPROM to the uint32 big endian
     * value in SRAM_DHCP_SECONDS */
    /* Loading 1 address beyond because of ld with pre-decrement */
    /* Could be replaced with SUB_UINT32_BIG_ENDIAN, but as subtraction not
     * needed anywhere else, then just do it here */
    /* Expected z to point to SRAM_DHCP_SECONDS + 4 */
0:  clr   xh
    rcall EEPROM_READ_N_INC
    clc
0:  ld    t1, -z
    sbc   t1, a4
    clr   a4
    st    z, t1
    dec   a1
    brne  0b
    /* After subtraction, Check if underflow, if so, set DHCP_TIMER_LAP. DHCP
     * packet will be sent and next time DHCP_TIMERS is called, the timer will
     * be reset */
    brcc  9f /* return */
    ldd   t1, y + SRAM_DHCP_TIMER_SUBTRAHEND_PTR_L - SRAM_DHCP
    inc   t1
    sbr   t1, (1 << DHCP_TIMER_LAP)
    std   y + SRAM_DHCP_TIMER_SUBTRAHEND_PTR_L - SRAM_DHCP, t1
9:  ret

/* DHCP_WAITING_IN_STATE {{{2 --------------------------------------------------
 * Simple counter, it will set SREG(Z) on overflow.
 *
 * XXX: It re-uses SRAM_DHCP_TIMER_SUBTRAHEND_PTR_L which is not used in all
 * DHCP states.
 *
 * XXX: SRAM_DHCP_TIMER_SUBTRAHEND_PTR_L may be used uninitialized, but should
 * not be a problem.
 * ---------------------------------------------------------------------------*/
DHCP_WAITING_IN_STATE:
    ldd   t1, y + SRAM_DHCP_TIMER_SUBTRAHEND_PTR_L - SRAM_DHCP
    inc   t1
    std   y + SRAM_DHCP_TIMER_SUBTRAHEND_PTR_L - SRAM_DHCP, t1
    andi  t1, DHCP_TIMER_ANDI
    ret

/* DHCP_XID_INCREMENT {{{2 -----------------------------------------------------
 * Increment last byte of XID, which is 4 bytes long.
 * TODO: improve when is called, it seems to me that is called more often than
 * needed.
 * ---------------------------------------------------------------------------*/
DHCP_XID_INCREMENT:
    ldd   t1, y + SRAM_DHCP_XID_LAST_BYTE - SRAM_DHCP
    inc   t1
    std   y + SRAM_DHCP_XID_LAST_BYTE - SRAM_DHCP, t1
    ret

/* DEBUG {{{1 ----------------------------------------------------------------*/
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
    ldd   a1, y + SRAM_DHCP_STATE - SRAM_DHCP
    PRINT_REG a1
    PRINT_NEWLINE
    DEBUG_POP
    ret

PRINT_VARIABLES:
    DEBUG_PUSH
    PRINT_STR STR_DHCP_VARS

    PRINT_STR STR_DHCP_IP_ADDR
    ldi   xl, lo8(SRAM_DHCP_IP_ADDR)
    ldi   xh, hi8(SRAM_DHCP_IP_ADDR)
    ldi   t3, 4
0:  ld    a1, x+
    rcall UART_TRANSMIT_HEX
    dec   t3
    brne  0b
    PRINT_NEWLINE

    PRINT_STR STR_DHCP_XID_LAST_BYTE
    ldi   xl, lo8(SRAM_DHCP_XID_LAST_BYTE)
    ldi   xh, hi8(SRAM_DHCP_XID_LAST_BYTE)
    ldi   t3, 1
0:  ld    a1, x+
    rcall UART_TRANSMIT_HEX
    dec   t3
    brne  0b
    PRINT_NEWLINE

    PRINT_STR STR_DHCP_SERVER_IP_ADDR
    ldi   xl, lo8(SRAM_DHCP_SERVER_IP_ADDR)
    ldi   xh, hi8(SRAM_DHCP_SERVER_IP_ADDR)
    ldi   t3, DHCP_OPTION_DHCP_SERVER_ID_LEN
0:  ld    a1, x+
    rcall UART_TRANSMIT_HEX
    dec   t3
    brne  0b
    PRINT_NEWLINE

    PRINT_STR STR_DHCP_ADDRESS_TIME
    ldi   xl, lo8(SRAM_DHCP_ADDRESS_TIME)
    ldi   xh, hi8(SRAM_DHCP_ADDRESS_TIME)
    ldi   t3, DHCP_OPTION_ADDRESS_TIME_LEN
0:  ld    a1, x+
    rcall UART_TRANSMIT_HEX
    dec   t3
    brne  0b
    PRINT_NEWLINE

    PRINT_STR STR_DHCP_SECONDS
    ldi   xl, lo8(SRAM_DHCP_SECONDS)
    ldi   xh, hi8(SRAM_DHCP_SECONDS)
    ldi   t3, DHCP_OPTION_ADDRESS_TIME_LEN
0:  ld    a1, x+
    rcall UART_TRANSMIT_HEX
    dec   t3
    brne  0b
    PRINT_NEWLINE

    PRINT_STR STR_DHCP_SUBNET_MASK
    ldi   xl, lo8(SRAM_DHCP_SUBNET_MASK)
    ldi   xh, hi8(SRAM_DHCP_SUBNET_MASK)
    ldi   t3, DHCP_OPTION_SUBNET_MASK_LEN
0:  ld    a1, x+
    rcall UART_TRANSMIT_HEX
    dec   t3
    brne  0b
    PRINT_NEWLINE

    PRINT_STR STR_DHCP_DOMAIN_SERVER
    ldi   xl, lo8(SRAM_DHCP_DOMAIN_SERVER)
    ldi   xh, hi8(SRAM_DHCP_DOMAIN_SERVER)
    ldi   t3, DHCP_DOMAIN_SERVER_LEN
0:  ld    a1, x+
    rcall UART_TRANSMIT_HEX
    dec   t3
    brne  0b
    PRINT_NEWLINE

    PRINT_STR STR_DHCP_STATE
    ldi   xl, lo8(SRAM_DHCP_STATE)
    ldi   xh, hi8(SRAM_DHCP_STATE)
    ldi   t3, 1
0:  ld    a1, x+
    rcall UART_TRANSMIT_HEX
    dec   t3
    brne  0b
    PRINT_NEWLINE

    PRINT_STR STR_DHCP_TIMER_SUBTRAHEND_PTR_L
    ldi   xl, lo8(SRAM_DHCP_TIMER_SUBTRAHEND_PTR_L)
    ldi   xh, hi8(SRAM_DHCP_TIMER_SUBTRAHEND_PTR_L)
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
