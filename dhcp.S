/* vim: set filetype=S foldmethod=marker: */
.NOLIST
#include <avr/io.h>
#include <avr/interrupt.h>
#include "defs.h"
#include "dhcp.h"
#include "ipv4.h"
#include "enc28j60.h"
.LIST

.global DHCP_DISCOVER
.global DHCP_HANDLE_PKT


/*******************************************************************************
 * Discover and Request {{{
 * Request and Discover are two separated messages in the process, but, they are
 * almost the same, therefore reusing most of the code.
 * On Discovery, T is clear
 * On Request, T is set
 ******************************************************************************/
DHCP_REQUEST:
    set
    rjmp DHCP_REQUEST_DISCOVER_COMMON
DHCP_DISCOVER:
    clt
DHCP_REQUEST_DISCOVER_COMMON:
    push  YL
    push  YH

    /* Ethernet Header {{{ */
    ldi   TMP_REG2, (1 << ENC_MAC_DST_PTR_BROADCAST_BIT)
    sts   ENC_MAC_DST_PTR, TMP_REG2
    ldi   TMP_REG2, (1 << ENC_TYPE_LEN_PTR_IPv4)
    sts   ENC_TYPE_LEN_PTR, TMP_REG2
    rcall ETH_WRITE_BUFFER_PACKET_HEADER
    /* }}} */
    rcall ETH_SET_LISTEN_ON_SPI
    /* IPv4 Header {{{
     * This header has src as 0.0.0.0, dst as 255.255.255.255, checksum and
     * total length have to be setup
     */
    /* Read default IPv4 header from EEPROM */
    ldi   YL, lo8(EEPROM_IP_HEADER)
    ldi   YH, hi8(EEPROM_IP_HEADER)
    ldi   COUNTER_REG, (EEPROM_IP_HEADER_END - EEPROM_IP_HEADER)
    /* Write to SRAM, so total length and checksum can be set */
    ldi   ZL, lo8(IPV4_HEADER)
    ldi   ZH, hi8(IPV4_HEADER)
DHCP_WRITE_IP_HEADER_TO_SRAM:
    rcall EEPROM_READ_N_INC
    st    Z+, RETURN_VALUE
    dec   COUNTER_REG
    brne  DHCP_WRITE_IP_HEADER_TO_SRAM

    ldi   ZL, lo8(IPV4_HEADER)
    ldi   ZH, hi8(IPV4_HEADER)

    /* Write the packet size depending if DISCOVERY or REQUEST */
    brts  DHCP_WRITE_REQUEST_PKT_SIZE
    ldi   TMP_REG2, hi8(DHCP_DISCOVERY_PKT_SIZE)
    std   Z + (IPV4_TOTAL_LENGTH + 0), TMP_REG2
    ldi   TMP_REG2, lo8(DHCP_DISCOVERY_PKT_SIZE)
    std   Z + (IPV4_TOTAL_LENGTH + 1), TMP_REG2
    rjmp  DHCP_PKT_SIZE_DONE
DHCP_WRITE_REQUEST_PKT_SIZE:
    ldi   TMP_REG2, hi8(DHCP_REQUEST_PKT_SIZE)
    std   Z + (IPV4_TOTAL_LENGTH + 0), TMP_REG2
    ldi   TMP_REG2, lo8(DHCP_REQUEST_PKT_SIZE)
    std   Z + (IPV4_TOTAL_LENGTH + 1), TMP_REG2
DHCP_PKT_SIZE_DONE:

    ldi   ARG_REG1, (EEPROM_IP_HEADER_END - EEPROM_IP_HEADER)

    rcall INTERNET_CHECKSUM_RFC1071
    std   Z + (IPV4_H_CHECKSUM + 0), YH
    std   Z + (IPV4_H_CHECKSUM + 1), YL

    ldi   COUNTER_REG, (EEPROM_IP_HEADER_END - EEPROM_IP_HEADER)
DHCP_WRITE_IP_HEADER:
    ld    ARG_REG1, Z+
    rcall SPI_MASTER_TRANSMIT
    dec   COUNTER_REG
    brne  DHCP_WRITE_IP_HEADER
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
    /* Write the packet size depending if DISCOVERY or REQUEST {{{ */
    brts  DHCP_WRITE_REQUEST_UDP_PKT_SIZE
    ldi   ARG_REG1, hi8(DHCP_DISCOVERY_UDP_PKT_SIZE)
    rcall SPI_MASTER_TRANSMIT
    ldi   ARG_REG1, lo8(DHCP_DISCOVERY_UDP_PKT_SIZE)
    rcall SPI_MASTER_TRANSMIT
    rjmp  DHCP_UDP_PKT_SIZE_DONE
DHCP_WRITE_REQUEST_UDP_PKT_SIZE:
    ldi   ARG_REG1, hi8(DHCP_REQUEST_UDP_PKT_SIZE)
    rcall SPI_MASTER_TRANSMIT
    ldi   ARG_REG1, lo8(DHCP_REQUEST_UDP_PKT_SIZE)
    rcall SPI_MASTER_TRANSMIT
DHCP_UDP_PKT_SIZE_DONE:
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
    lds   ARG_REG1, DHCP_XID_LAST_BYTE
    brts  SKIP_XID_INC_N_UPDATE
    inc   ARG_REG1
    sts   DHCP_XID_LAST_BYTE, ARG_REG1
SKIP_XID_INC_N_UPDATE:
    rcall SPI_MASTER_TRANSMIT
    /* }}} */
    /* set SECS, FLAGS, CIADDR, YIADDR to zero {{{ */
    ldi   ARG_REG1, 0
    ldi   COUNTER_REG, 12
DHCP_REQUEST_IP_SET_HEADER_LOOP_2:
    rcall SPI_MASTER_TRANSMIT
    dec   COUNTER_REG
    brne  DHCP_REQUEST_IP_SET_HEADER_LOOP_2
    /* }}} */
    /* SIADDR to zero or value depending on T {{{ */
    /* TODO: SIADDR is always 0 from the client, used only from the server to
     * tell what IP to use for following BOOTP REQUESTS */
    ldi   YL, lo8(DHCP_SERVER_IP_ADDR)
    ldi   YH, hi8(DHCP_SERVER_IP_ADDR)
    ldi   COUNTER_REG, IPV4_SIZE_IN_BYTES
DHCP_REQUEST_IP_SET_HEADER_LOOP_2_1:
    brtc  SKIP_READING_SERVER_IP
    ld    ARG_REG1, Y+
SKIP_READING_SERVER_IP:
    rcall SPI_MASTER_TRANSMIT
    dec   COUNTER_REG
    brne  DHCP_REQUEST_IP_SET_HEADER_LOOP_2_1
    /* }}} */
    /* GIADDR to zero {{{ */
    ldi   ARG_REG1, 0
    ldi   COUNTER_REG, 4
DHCP_REQUEST_IP_SET_HEADER_LOOP_2_2:
    rcall SPI_MASTER_TRANSMIT
    dec   COUNTER_REG
    brne  DHCP_REQUEST_IP_SET_HEADER_LOOP_2_2
    /* }}} */
    /* Write own MAC {{{ */
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
    ldi   ARG_REG1, 0
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
    brts  DHCP_REQUEST_OPS
    /* DHCP Discover {{{ */
    ldi   ARG_REG1, DHCP_OPTION_DHCP_MSG_TYPE
    rcall SPI_MASTER_TRANSMIT
    ldi   ARG_REG1, DHCP_OPTION_DHCP_MSG_TYPE_LEN
    rcall SPI_MASTER_TRANSMIT
    ldi   ARG_REG1, DHCP_OPTION_DHCP_MSG_TYPE_DHCP_DISCOVER
    rcall SPI_MASTER_TRANSMIT
    rjmp  DHCP_END_OP
    /* }}} */
DHCP_REQUEST_OPS: /* DHCP Request {{{ */
#if 0
    /* DHCP message */
    ldi   ARG_REG1, DHCP_OPTION_DHCP_MSG_TYPE
    rcall SPI_MASTER_TRANSMIT
    ldi   ARG_REG1, DHCP_OPTION_DHCP_MSG_TYPE_LEN
    rcall SPI_MASTER_TRANSMIT
    ldi   ARG_REG1, DHCP_OPTION_DHCP_MSG_TYPE_DHCP_REQUEST
    rcall SPI_MASTER_TRANSMIT

    /* DHCP requested ip address */
    ldi   ARG_REG1, DHCP_OPTION_ADDRESS_REQUEST
    rcall SPI_MASTER_TRANSMIT
    ldi   ARG_REG1, DHCP_OPTION_ADDRESS_REQUEST_LEN
    rcall SPI_MASTER_TRANSMIT
#else
    ldi   YL, lo8(EEPROM_DHCP_REQUEST_OPS)
    ldi   YH, hi8(EEPROM_DHCP_REQUEST_OPS)
    ldi   COUNTER_REG, (EEPROM_DHCP_REQUEST_OPS_END - EEPROM_DHCP_REQUEST_OPS)
DHCP_REQUEST_EEPROM_OPS:
    rcall EEPROM_READ_N_INC
    mov   ARG_REG1, RETURN_VALUE
    rcall SPI_MASTER_TRANSMIT
    dec   COUNTER_REG
    brne  DHCP_REQUEST_EEPROM_OPS
#endif

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

    ldi   YL, lo8(DHCP_SERVER_IP_ADDR)
    ldi   YH, hi8(DHCP_SERVER_IP_ADDR)
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

    pop   YH
    pop   YL
    ret

/* }}} */
/*******************************************************************************
 * Handle dhcp packet {{{
 * BEWARE, EXPECTING ETH MODULE LISTENING TO SPI
 ******************************************************************************/
DHCP_HANDLE_PKT:
    push YL
    push YH

    /* Check OP, HTYPE, HLEN, HOPS and XID */
    ETH_READ_NEXT_BYTE
    cpi   RETURN_VALUE, 0x02
    /* Avoid "relocation truncated to fit: R_AVR_7_PCREL against `no symbol'" by
     * jumping to an intermedium point */
    brne  RELOCATION_TRUNCATED_WORK_AROUND

    ldi   YL, lo8(EEPROM_DHCP_HEADER + 1)
    ldi   YH, hi8(EEPROM_DHCP_HEADER + 1)
    ldi   COUNTER_REG, 6
CHECK_DHCP_HEADER:
    rcall EEPROM_READ_N_INC
    mov   TMP_REG1, RETURN_VALUE
    ETH_READ_NEXT_BYTE
    cp    TMP_REG1, RETURN_VALUE
    brne  RELOCATION_TRUNCATED_WORK_AROUND
    dec   COUNTER_REG
    brne  CHECK_DHCP_HEADER

    /* Check last byte of the XID */
    ETH_READ_NEXT_BYTE
    lds   TMP_REG1, DHCP_XID_LAST_BYTE
    cp    TMP_REG1, RETURN_VALUE
RELOCATION_TRUNCATED_WORK_AROUND:
    brne  DHCP_HANDLE_EXIT_SUCCESS

    /* Jump to YIADDR */
    ETH_READ_BUFFER_END
    ldi   ARG_REG1, 0
    ldi   ARG_REG2, 8 /* SECS + FLAGS + CIADDR */
    rcall ETH_MOVE_READ_POINTER
    rcall ETH_READ_BUFFER_START

    /* Read offered IP and write it into EEPROM */
    ldi   COUNTER_REG, IPV4_SIZE_IN_BYTES
    ldi   YL, lo8(EEPROM_IP_ADDR)
    ldi   YH, hi8(EEPROM_IP_ADDR)
UPDATE_EEPROM_IP_ADDR:
    ETH_READ_NEXT_BYTE
    mov   ARG_REG1, RETURN_VALUE
    rcall EEPROM_WRITE_N_INC
    dec   COUNTER_REG
    brne  UPDATE_EEPROM_IP_ADDR
    
    /* Jump from siaddr ip addr to magic cookie */
    ETH_READ_BUFFER_END
    ldi   ARG_REG1, 0
    ldi   ARG_REG2, 216
    rcall ETH_MOVE_READ_POINTER
    rcall ETH_READ_BUFFER_START

    /* Check magic cookie */
    ldi   YL, lo8(EEPROM_DHCP_MAGIC_COOKIE)
    ldi   YH, hi8(EEPROM_DHCP_MAGIC_COOKIE)
    ldi   COUNTER_REG, (EEPROM_DHCP_MAGIC_COOKIE_END - EEPROM_DHCP_MAGIC_COOKIE)
CHECK_MAGIC_COOKIE:
    rcall EEPROM_READ_N_INC
    mov   R1, RETURN_VALUE
    ETH_READ_NEXT_BYTE
    cp    R1, RETURN_VALUE
    brne  DHCP_HANDLE_EXIT_FAILURE
    dec   COUNTER_REG
    brne  CHECK_MAGIC_COOKIE

    /* DHCP read options {{{ */
    clt /* Using T to know if DHCP REQUEST needs to be sent */
KEEP_READING_OP:
    ETH_READ_NEXT_BYTE
    /* Check if end of options */
    cpi   RETURN_VALUE, DHCP_OPTION_END
    breq  NO_MORE_OPTIONS
    /* Check if padding, which doesn't have length. Go to read next byte */
    cpi   RETURN_VALUE, DHCP_OPTION_PAD
    breq  KEEP_READING_OP
    /* DHCP message {{{ */
    cpi   RETURN_VALUE, DHCP_OPTION_DHCP_MSG_TYPE
    brne  TRY_DHCP_OPTION_DHCP_SERVER_ID
    /* DHCP message, we care about dhcp offer */
    ETH_READ_NEXT_BYTE /* read size of option, must be 1 */
    ETH_READ_NEXT_BYTE
    /* I guess offer is the only one that requires to give an answer */
    cpi   RETURN_VALUE, DHCP_OPTION_DHCP_MSG_TYPE_DHCP_OFFER
    brne  KEEP_READING_OP
    set   /* Setting T, then sending Request depending on T */
    brne  KEEP_READING_OP
    /* }}} */
TRY_DHCP_OPTION_DHCP_SERVER_ID: /* {{{ */
    cpi   RETURN_VALUE, DHCP_OPTION_DHCP_SERVER_ID
    brne  IGNORE_DHCP_OP
    ETH_READ_NEXT_BYTE /* must be 4 */
    ldi   COUNTER_REG, IPV4_SIZE_IN_BYTES
    ldi   YL, lo8(DHCP_SERVER_IP_ADDR)
    ldi   YH, hi8(DHCP_SERVER_IP_ADDR)
STORE_DHCP_SERVER_IP_ADDR:
    ETH_READ_NEXT_BYTE
    st    Y+, RETURN_VALUE
    dec   COUNTER_REG
    brne  STORE_DHCP_SERVER_IP_ADDR
    brne  KEEP_READING_OP
    /* }}} */
IGNORE_DHCP_OP: /* {{{ */
    ETH_READ_NEXT_BYTE /* read size of option */
    mov   COUNTER_REG, RETURN_VALUE
DHCP_OP_READ_CONTENT:
    ETH_READ_NEXT_BYTE
    dec   COUNTER_REG
    brne  DHCP_OP_READ_CONTENT
    brne  KEEP_READING_OP
    /* }}} */
NO_MORE_OPTIONS:
    /* }}} */

    /* T was set if DHCP message was offer, so now send the request */
    brtc  DHCP_HANDLE_EXIT_SUCCESS
    rcall DHCP_REQUEST

DHCP_HANDLE_EXIT_SUCCESS:
    ldi  RETURN_VALUE, 0
DHCP_HANDLE_EXIT:
    ETH_READ_BUFFER_END
    pop  YH
    pop  YL
    ret
DHCP_HANDLE_EXIT_FAILURE:
    /* TODO: do something better */
    // SET_LED1
    rjmp DHCP_HANDLE_EXIT
/* }}} */

