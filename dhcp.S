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

/* Defines {{{ */
#define READ_NEXT_BYTE rcall SPI_MASTER_TRANSMIT

#define UDP_SRC_PORT                68
#define UDP_DST_PORT                67
#define DHCP_DISCOVERY_UDP_PKT_SIZE  (     8 + /* UDP header */          \
                                      11 * 4 + /* before BOOTP legacy */ \
                                         192 + /* BOOTP legacy */        \
                                           4 + /* magic cookie */        \
                                           3 + /* DHCP discover */       \
                                           1   /* endmark */             \
                                   )
#define DHCP_REQUEST_UDP_PKT_SIZE    (DHCP_DISCOVERY_UDP_PKT_SIZE + 12)
#define DHCP_DISCOVERY_PKT_SIZE      (DHCP_DISCOVERY_UDP_PKT_SIZE + 20)
#define DHCP_REQUEST_PKT_SIZE        (DHCP_DISCOVERY_PKT_SIZE + 12)

.macro SR reg
    push  ARG_REG1
    push  RETURN_VALUE
    mov   ARG_REG1, \reg
    rcall EEPROM_WRITE_N_INC
    pop   RETURN_VALUE
    pop   ARG_REG1
.endm
/* }}} */

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

    ldi   TMP_REG2, (1 << ENC_MAC_DST_PTR_BROADCAST_BIT)
    sts   ENC_MAC_DST_PTR, TMP_REG2
    ldi   TMP_REG2, (1 << ENC_TYPE_LEN_PTR_IPv4)
    sts   ENC_TYPE_LEN_PTR, TMP_REG2
    rcall ETH_WRITE_BUFFER_PACKET_HEADER

    rcall ETH_SET_LISTEN_ON_SPI

    /* Write IPv4 Header
     * This header has src as 0.0.0.0, dst as 255.255.255.255, checksum and
     * total length have to be setup
     */
    /* Read default IPv4 header from EEPROM */
    ldi   YL, lo8(EEPROM_IP_HEADER)
    ldi   YH, hi8(EEPROM_IP_HEADER)
    ldi   COUNTER_REG, EEPROM_IP_HEADER_LEN
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

    ldi   ARG_REG1, EEPROM_IP_HEADER_LEN

    rcall INTERNET_CHECKSUM_RFC1071
    std   Z + (IPV4_H_CHECKSUM + 0), YH
    std   Z + (IPV4_H_CHECKSUM + 1), YL

    ldi   COUNTER_REG, EEPROM_IP_HEADER_LEN
DHCP_WRITE_IP_HEADER:
    ld    ARG_REG1, Z+
    rcall SPI_MASTER_TRANSMIT
    dec   COUNTER_REG
    brne  DHCP_WRITE_IP_HEADER

    ldi   ARG_REG1, hi8(UDP_SRC_PORT)
    rcall SPI_MASTER_TRANSMIT
    ldi   ARG_REG1, lo8(UDP_SRC_PORT)
    rcall SPI_MASTER_TRANSMIT
    ldi   ARG_REG1, hi8(UDP_DST_PORT)
    rcall SPI_MASTER_TRANSMIT
    ldi   ARG_REG1, lo8(UDP_DST_PORT)
    rcall SPI_MASTER_TRANSMIT

    /* Write the packet size depending if DISCOVERY or REQUEST */
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

    ldi   ARG_REG1, 0
    rcall SPI_MASTER_TRANSMIT
    rcall SPI_MASTER_TRANSMIT

    /************* 
     * DHCP PART * 
     *************/
    /* Write first 8 bytes: OP, HTYPE, HLEN, HOPS AND XID */
    ldi   YL, lo8(EEPROM_DHCP_HEADER)
    ldi   YH, hi8(EEPROM_DHCP_HEADER)
    ldi   COUNTER_REG, EEPROM_DHCP_HEADER_LEN
DHCP_REQUEST_IP_SET_HEADER_LOOP_1:
    rcall EEPROM_READ_N_INC
    mov   ARG_REG1, RETURN_VALUE
    rcall SPI_MASTER_TRANSMIT
    dec   COUNTER_REG
    brne  DHCP_REQUEST_IP_SET_HEADER_LOOP_1

    /* set SECS, FLAGS, CIADDR, YIADDR to zero */
    ldi   ARG_REG1, 0
    ldi   COUNTER_REG, 12
DHCP_REQUEST_IP_SET_HEADER_LOOP_2:
    rcall SPI_MASTER_TRANSMIT
    dec   COUNTER_REG
    brne  DHCP_REQUEST_IP_SET_HEADER_LOOP_2

    /* SIADDR to zero or value depending on T */
    ldi   YL, lo8(DHCP_SERVER_IP_ADDR)
    ldi   YH, hi8(DHCP_SERVER_IP_ADDR)
    ldi   COUNTER_REG, IPV4_SIZE_IN_BYTES
DHCP_REQUEST_IP_SET_HEADER_LOOP_2_1:
    brtc  SKIP_REAADING_SERVER_IP
    ld    ARG_REG1, Y+
SKIP_REAADING_SERVER_IP:
    rcall SPI_MASTER_TRANSMIT
    dec   COUNTER_REG
    brne  DHCP_REQUEST_IP_SET_HEADER_LOOP_2_1
    
    /* GIADDR to zero */
    ldi   ARG_REG1, 0
    ldi   COUNTER_REG, 4
DHCP_REQUEST_IP_SET_HEADER_LOOP_2_2:
    rcall SPI_MASTER_TRANSMIT
    dec   COUNTER_REG
    brne  DHCP_REQUEST_IP_SET_HEADER_LOOP_2_2

    /* Write own MAC */
    ldi   YL, lo8(EEPROM_MAC_ADDR)
    ldi   YH, hi8(EEPROM_MAC_ADDR)
    ldi   COUNTER_REG, MAC_SIZE_IN_BYTES
DHCP_REQUEST_IP_SET_HEADER_LOOP_3:
    rcall EEPROM_READ_N_INC
    mov   ARG_REG1, RETURN_VALUE
    rcall SPI_MASTER_TRANSMIT
    dec   COUNTER_REG
    brne  DHCP_REQUEST_IP_SET_HEADER_LOOP_3

    /* header has 16 bytes for mac, as using only 6, there are 10 bytes to write
     * as zero, then we have 192 bytes of zero (option overload/BOOTS legacy) */
    ldi   ARG_REG1, 0
    ldi   COUNTER_REG, 202
DHCP_REQUEST_IP_SET_HEADER_LOOP_4:
    rcall SPI_MASTER_TRANSMIT
    dec   COUNTER_REG
    brne  DHCP_REQUEST_IP_SET_HEADER_LOOP_4

    /* Write magic cookie */
    ldi   YL, lo8(EEPROM_DHCP_MAGIC_COOKIE)
    ldi   YH, hi8(EEPROM_DHCP_MAGIC_COOKIE)
    ldi   COUNTER_REG, EEPROM_DHCP_MAGIC_COOKIE_LEN
DHCP_REQUEST_IP_SET_HEADER_LOOP_5:
    rcall EEPROM_READ_N_INC
    mov   ARG_REG1, RETURN_VALUE
    rcall SPI_MASTER_TRANSMIT
    dec   COUNTER_REG
    brne  DHCP_REQUEST_IP_SET_HEADER_LOOP_5

    brts  DHCP_REQUEST_OPS
    /* DHCP Discover */
    ldi   ARG_REG1, DHCP_OPTION_DHCP_MSG_TYPE
    rcall SPI_MASTER_TRANSMIT
    ldi   ARG_REG1, DHCP_OPTION_DHCP_MSG_TYPE_LEN
    rcall SPI_MASTER_TRANSMIT
    ldi   ARG_REG1, DHCP_OPTION_DHCP_MSG_TYPE_DHCP_DISCOVER
    rcall SPI_MASTER_TRANSMIT
    rjmp  DHCP_END_OP

    /* DHCP Request */
DHCP_REQUEST_OPS:
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

    /* End OP */
DHCP_END_OP:
    ldi   ARG_REG1, DHCP_OPTION_END
    rcall SPI_MASTER_TRANSMIT

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
    /* check first 4 bytes to be 0x02 0x01 0x06 0x00 */
    READ_NEXT_BYTE
    cpi   RETURN_VALUE, 0x02
    // brne  DHCP_HANDLE_EXIT_FAILURE
    READ_NEXT_BYTE
    cpi   RETURN_VALUE, 0x01
    // brne  DHCP_HANDLE_EXIT_FAILURE
    READ_NEXT_BYTE
    cpi   RETURN_VALUE, 0x06
    // brne  DHCP_HANDLE_EXIT_FAILURE
    READ_NEXT_BYTE
    cpi   RETURN_VALUE, 0x00
    // brne  DHCP_HANDLE_EXIT_FAILURE

    /* TODO: check id */
    ETH_READ_BUFFER_END
    ldi   ARG_REG1, 0
    ldi   ARG_REG2, 12
    rcall ETH_MOVE_READ_POINTER
    rcall ETH_READ_BUFFER_START

    /* Read offered IP and write it into EEPROM */
    ldi   COUNTER_REG, IPV4_SIZE_IN_BYTES
    ldi   YL, lo8(EEPROM_IP_ADDR)
    ldi   YH, hi8(EEPROM_IP_ADDR)
UPDATE_EEPROM_IP_ADDR:
    READ_NEXT_BYTE
    mov   ARG_REG1, RETURN_VALUE
    rcall EEPROM_WRITE_N_INC
    dec   COUNTER_REG
    brne  UPDATE_EEPROM_IP_ADDR
    
    ldi   YL, lo8(DHCP_SERVER_IP_ADDR)
    ldi   YH, hi8(DHCP_SERVER_IP_ADDR)
    ldi   COUNTER_REG, IPV4_SIZE_IN_BYTES
STORE_DHCP_SERVER_IP_ADDR:
    READ_NEXT_BYTE
    st    Y+, RETURN_VALUE
    dec   COUNTER_REG
    brne  STORE_DHCP_SERVER_IP_ADDR

    /* Jump from gateway ip addr to magic cookie */
    ETH_READ_BUFFER_END
    ldi   ARG_REG1, 0
    ldi   ARG_REG2, 212
    rcall ETH_MOVE_READ_POINTER
    rcall ETH_READ_BUFFER_START

    /* Check magic cookie */
    ldi   YL, lo8(EEPROM_DHCP_MAGIC_COOKIE)
    ldi   YH, hi8(EEPROM_DHCP_MAGIC_COOKIE)
    ldi   COUNTER_REG, EEPROM_DHCP_MAGIC_COOKIE_LEN
CHECK_MAGIC_COOKIE:
    rcall EEPROM_READ_N_INC
    mov   R1, RETURN_VALUE
    READ_NEXT_BYTE
    cp    R1, RETURN_VALUE
    brne  DHCP_HANDLE_EXIT_FAILURE
    dec   COUNTER_REG
    brne  CHECK_MAGIC_COOKIE

    /* DHCP options */
KEEP_READING_OP:
    READ_NEXT_BYTE
    /* Check if end of options */
    cpi   RETURN_VALUE, DHCP_OPTION_END
    breq  NO_MORE_OPTIONS
    /* Check if server sent dhcp message */
    cpi   RETURN_VALUE, DHCP_OPTION_DHCP_MSG_TYPE
    brne  IGNORE_DHCP_OP
    /* DHCP message, we care about dhcp offer */
    READ_NEXT_BYTE /* read size of option, must be 1 */
    READ_NEXT_BYTE
    /* I guess offer is the only one that requires to give an answer */
    cpi   RETURN_VALUE, DHCP_OPTION_DHCP_MSG_TYPE_DHCP_OFFER
    brne  KEEP_READING_OP
    rcall DHCP_REQUEST
IGNORE_DHCP_OP:
    READ_NEXT_BYTE /* read size of option */
    mov   COUNTER_REG, RETURN_VALUE
DHCP_OP_READ_CONTENT:
    READ_NEXT_BYTE
    dec   COUNTER_REG
    brne  DHCP_OP_READ_CONTENT
NO_MORE_OPTIONS:

DHCP_HANDLE_EXIT_SUCCESS:
    ETH_READ_BUFFER_END
    ldi  RETURN_VALUE, 0
DHCP_HANDLE_EXIT:
    pop  YH
    pop  YL
    ret
DHCP_HANDLE_EXIT_FAILURE:
    /* TODO: do something better */
    ERR_ETH_SET_ERROR
    rjmp DHCP_HANDLE_EXIT
/* }}} */

