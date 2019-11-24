/* vim: set filetype=S foldmethod=marker: */
/* INCLUDES {{{1 */
.NOLIST
#include <avr/io.h>
#include "defs.h"
#include "tcp.h"
#include "enc28j60.h"
#include "eeprom_data.h"
#include "ipv4.h"
#include "dht11.h"
.LIST

/* MACORS {{{1 ---------------------------------------------------------------*/
#define TCP_HEADER_LEN_REG R3
#define SEQ_N_LEN       4
/* Maximum number of concurrent connections */
#define TCP_MAX_CONNS   4
/* 2 bytes for src port
 * 2 bytes for dst port
 * 4 Byte for sequence number
 * 4 bytes for acknowledgement number */
#define TCP_CONN_LENGTH (2 + 2 + 4 + 4)
#define TCP_CONN_TABLE_LENGTH (TCP_MAX_CONNS * TCP_CONN_LENGTH)

/* Connection table offsets */
#define TCP_CONN_TBL_SRC_PORT       0
#define TCP_CONN_TBL_DST_PORT       2
#define TCP_CONN_TBL_REMOTE_SEQ_N   4
#define TCP_CONN_TBL_LOCAL_SEQ_N    8

#define TCP_PAYLOAD_LEN             20

/* GLOBAL {{{1 ---------------------------------------------------------------*/
.global TCP_HANDLE_PKT

/* DATA  {{{1 ----------------------------------------------------------------*/
.section .data
/* TODO: split pseudo header into corresponding fields */
SRAM_TCP_PSEUDO_HEADER: .skip 12
SRAM_TCP_HEADER:
SRAM_TCP_SRC_PORT: .skip 2
SRAM_TCP_DST_PORT: .skip 2
SRAM_TCP_SEQ_N:    .skip 4
SRAM_TCP_ACK_N:    .skip 4
SRAM_TCP_DO_FLAGS: .skip 2
SRAM_TCP_WINDOW:   .skip 2
SRAM_TCP_CHKSUM:   .skip 2
SRAM_TCP_URGENT_P: .skip 2
SRAM_TCP_OPTS:     .skip 40
SRAM_TCP_PAYLOAD:  .skip TCP_PAYLOAD_LEN

SRAM_TCP_CONNS: .skip TCP_CONN_TABLE_LENGTH

/* TEXT {{{1 -----------------------------------------------------------------*/
.section .text

/* TCP Handle {{{2 -------------------------------------------------------------
 * TCP not supported at the moment */
TCP_HANDLE_PKT:
    push  TCP_HEADER_LEN_REG
    rcall ETH_READ_BUFFER_START

    /* Read TCP option until beginning of options */
    ldi   COUNTER_REG, TCP_HEADER_OPTIONS
    ldi   ZL, lo8(SRAM_TCP_HEADER)
    ldi   ZH, hi8(SRAM_TCP_HEADER)
READ_HEADER:
    ETH_READ_NEXT_BYTE
    st    Z+, RTV_L_REG
    dec   COUNTER_REG
    brne  READ_HEADER

    /* Get the TCP header length in bytes */
    /* Load Data Offset + Flags. Remove Flags and Swap */
    lds   TMP_REG1, SRAM_TCP_DO_FLAGS
    andi  TMP_REG1, 0xF0
    swap  TMP_REG1
    /* data offset from words to bytes (*4) */
    lsl   TMP_REG1
    lsl   TMP_REG1
    mov   TCP_HEADER_LEN_REG, TMP_REG1

    /* Read the TCP options, remove constant TCP header length */
    mov   COUNTER_REG, TCP_HEADER_LEN_REG
    subi  COUNTER_REG, 20
    breq  END_OF_OPTIONS
0:
    ETH_READ_NEXT_BYTE
    st    Z+, RTV_L_REG
    dec   COUNTER_REG
    brne  0b
END_OF_OPTIONS:

    /* Check if SYN packet */
    lds   TMP_REG1, SRAM_TCP_DO_FLAGS + 1
    sbrs  TMP_REG1, TCP_HEADER_FLAG_SYN
    rjmp  TCP_NOT_SYN

    rcall TCP_SEND_SYN_ACK
    rjmp  TCP_HANDLE_PKT_END

    /* Check if FIN packet */
TCP_NOT_SYN:

    sbrs  TMP_REG1, TCP_HEADER_FLAG_FIN
    rjmp  TCP_NOT_FIN

    rcall TCP_SEND_FIN_ACK
    rjmp  TCP_HANDLE_PKT_END

TCP_NOT_FIN:

    sbrs  TMP_REG1, TCP_HEADER_FLAG_PSH
    rjmp  TCP_HANDLE_PKT_END

    rcall TCP_PAYLOAD_HANDLE

TCP_HANDLE_PKT_END:
    ETH_READ_BUFFER_END
    pop   TCP_HEADER_LEN_REG
    ret

/* TCP_SEND_SYN_ACK {{{2 -------------------------------------------------------
   */
TCP_SEND_SYN_ACK:
    /* TODO: check if we have an established connection for this pair of src/dest
     * ip/tcp ports */

    /* Set initial sequence number */
    ldi   YL, lo8(SRAM_TIMER1_SECONDS)
    ldi   YH, hi8(SRAM_TIMER1_SECONDS)
    ldi   ZL, lo8(SRAM_TCP_CONNS + TCP_CONN_TBL_LOCAL_SEQ_N)
    ldi   ZH, hi8(SRAM_TCP_CONNS + TCP_CONN_TBL_LOCAL_SEQ_N)
    ldi   ARG_REG1, 4
    rcall MEMCPY

    /* Copy Src/Dst port to connection table */
    ldi   YL, lo8(SRAM_TCP_HEADER)
    ldi   YH, hi8(SRAM_TCP_HEADER)
    ldi   ZL, lo8(SRAM_TCP_CONNS)
    ldi   ZH, hi8(SRAM_TCP_CONNS)
    ldi   ARG_REG1, IPV4_PORT_LEN * 2
    rcall MEMCPY
    rjmp  0f /* jump to common code for SYN and FIN */

TCP_SEND_FIN_ACK:
    /* Get acknowledge number */
    ldi   YL, lo8(SRAM_TCP_ACK_N)
    ldi   YH, hi8(SRAM_TCP_ACK_N)
    ldi   ZL, lo8(SRAM_TCP_CONNS + TCP_CONN_TBL_LOCAL_SEQ_N)
    ldi   ZH, hi8(SRAM_TCP_CONNS + TCP_CONN_TBL_LOCAL_SEQ_N)
    ldi   ARG_REG1, SEQ_N_LEN
    rcall MEMCPY

0:  /* common code for SYN and FIN */
    /* Swap Src/Dst ports */
    ldi   ZL, lo8(SRAM_TCP_SRC_PORT)
    ldi   ZH, hi8(SRAM_TCP_SRC_PORT)
    ldi   YL, lo8(SRAM_TCP_DST_PORT)
    ldi   YH, hi8(SRAM_TCP_DST_PORT)
    ldi   ARG_REG1, IPV4_PORT_LEN
    rcall MEMSWAP

    /* Get sequence number */
    /* Y was left pointing to Seq. Num. */
    ldi   ZL, lo8(SRAM_TCP_CONNS + TCP_CONN_TBL_REMOTE_SEQ_N)
    ldi   ZH, hi8(SRAM_TCP_CONNS + TCP_CONN_TBL_REMOTE_SEQ_N)
    ldi   ARG_REG1, SEQ_N_LEN
    rcall MEMCPY

    /* Set Sequence Number from connection table */
    ldi   ZL, lo8(SRAM_TCP_HEADER + TCP_HEADER_SQNC_N)
    ldi   ZH, hi8(SRAM_TCP_HEADER + TCP_HEADER_SQNC_N)
    ldi   YL, lo8(SRAM_TCP_CONNS + TCP_CONN_TBL_LOCAL_SEQ_N)
    ldi   YH, hi8(SRAM_TCP_CONNS + TCP_CONN_TBL_LOCAL_SEQ_N)
    rcall MEMCPY /* ARG_REG1 was already set to SEQ_N_LEN */

    /* Set Acknowledge Number from connection table */
    sbiw  YL, (TCP_CONN_TBL_LOCAL_SEQ_N - TCP_CONN_TBL_REMOTE_SEQ_N + SEQ_N_LEN)
    rcall MEMCPY /* ARG_REG1 was already set to SEQ_N_LEN */

    /* Add 1 to acknowledge number */
    movw  YL, ZL
    sbiw  YL, SEQ_N_LEN
    ldi   ARG_REG1, 1
    rcall ADD_32b

    /* Get data offset */
    ld    TMP_REG1, Z+
    andi  TMP_REG1, 0xF0
    mov   TCP_HEADER_LEN_REG, TMP_REG1
    swap  TCP_HEADER_LEN_REG
    lsl   TCP_HEADER_LEN_REG
    lsl   TCP_HEADER_LEN_REG

    /* Set ACK flag */
    ld    TMP_REG1, Z
    ori   TMP_REG1, TCP_HEADER_DO_FLAGS_H_FLAG_ACK
    st    Z, TMP_REG1

    /* Set checksum to zero */
    adiw  ZL, 3
    st    Z+, ZERO_REG
    st    Z+, ZERO_REG

    /* Process options */
    adiw  ZL, 2
    /* The rest of the tcp header is (Data offset * 4 - 20)
     * If we take ZL that points to the beginning of the options and add it
     * (data offset - 5) * 4, we will know when ZL is at the beginning of the
     * data */
    mov   TMP_REG2, TCP_HEADER_LEN_REG
    subi  TMP_REG2, 20
    add   TMP_REG2, ZL /* TMP_REG2 == ZL => First byte of data */
TCP_SYN_OPTIONS: /* {{{ */
    /* Beyond data offset */
    cp    TMP_REG2, ZL
    breq  TCP_END_OF_OPTIONS
    ld    TMP_REG1, Z+
    /* Test end of options */
    cpi   TMP_REG1, TCP_OPT_END
    breq  TCP_END_OF_OPTIONS
    /* Test padding */
    cpi   TMP_REG1, TCP_OPT_NOP
    breq  TCP_SYN_OPTIONS
    /* Test MSS */
    cpi   TMP_REG1, TCP_OPT_MSS
    brne  TRY_WSF
    SET_LED1
    adiw  ZL, TCP_OPT_MSS_LEN - 1
    rjmp  TCP_SYN_OPTIONS
    /* Test WSF */
TRY_WSF:
    cpi   TMP_REG1, TCP_OPT_WSF
    brne  TRY_SACK
    adiw  ZL, TCP_OPT_WSF_LEN - 1
    rjmp  TCP_SYN_OPTIONS
    /* Sack permitted */
TRY_SACK:
    cpi   TMP_REG1, TCP_OPT_SACK
    brne  TRY_TTP
    adiw  ZL, TCP_OPT_SACK_LEN - 1
    rjmp  TCP_SYN_OPTIONS
    /* Test time stamp */
TRY_TTP:
    cpi   TMP_REG1, TCP_OPT_TTP
    brne  TCP_OPTIONS_ERR
    /* Copy original time stamp to reply time stamp */
    adiw  ZL, 1
    movw  YL, ZL
    adiw  ZL, 4
    ldi   ARG_REG1, 4
    rcall MEMCPY
    rjmp  TCP_SYN_OPTIONS
TCP_OPTIONS_ERR:
    SET_LED0
TCP_END_OF_OPTIONS: /* }}} */

    ETH_READ_BUFFER_END

    /* TCP checksum */
    /* TCP pseudo header */
    /* Copy SRC and DST IP Addresses */
    ldi   ZL, lo8(SRAM_TCP_PSEUDO_HEADER)
    ldi   ZH, hi8(SRAM_TCP_PSEUDO_HEADER)
    ldi   YL, lo8(SRAM_IPV4_HEADER + IPV4_SRC_ADDR)
    ldi   YH, hi8(SRAM_IPV4_HEADER + IPV4_SRC_ADDR)
    ldi   ARG_REG1, IPV4_ADDR_LEN * 2
    rcall MEMCPY

    /* Reserve byte and IPv4 Protocol */
    st    Z+, ZERO_REG
    ldi   YL, lo8(SRAM_IPV4_HEADER + IPV4_PROTOCOL)
    ldi   YH, hi8(SRAM_IPV4_HEADER + IPV4_PROTOCOL)
    ld    TMP_REG1, Y
    st    Z+, TMP_REG1

    /* Length, this length does NOT include the pseudo header length */
    st    Z+, ZERO_REG
    mov   TMP_REG1, TCP_HEADER_LEN_REG
    st    Z+, TMP_REG1

    /* Calculate TCP checksum */
    ldi   ZL, lo8(SRAM_TCP_PSEUDO_HEADER)
    ldi   ZH, hi8(SRAM_TCP_PSEUDO_HEADER)
    mov   ARG_REG1, TCP_HEADER_LEN_REG
    subi  ARG_REG1, -12 /* 12 = pseudo header length */
    rcall INTERNET_CHECKSUM_RFC1071
    ldi   ZL, lo8(SRAM_TCP_HEADER)
    ldi   ZH, hi8(SRAM_TCP_HEADER)
    std   Z + (TCP_HEADER_CHKSUM + 0), RTV_H_REG
    std   Z + (TCP_HEADER_CHKSUM + 1), RTV_L_REG

    /* Ethernet header */
    rcall ETH_WRITE_BUFFER_PACKET_HEADER
    /* IP header */
    /* Swap SRC/DST IP Addresses */
    ldi   ZL, lo8(SRAM_IPV4_HEADER + IPV4_SRC_ADDR)
    ldi   ZH, hi8(SRAM_IPV4_HEADER + IPV4_SRC_ADDR)
    ldi   YL, lo8(SRAM_IPV4_HEADER + IPV4_DST_ADDR)
    ldi   YH, hi8(SRAM_IPV4_HEADER + IPV4_DST_ADDR)
    ldi   ARG_REG1, IPV4_ADDR_LEN
    rcall MEMSWAP

    /* ipv4 checksum */
    /* Write IPv4 header into ENC buffer */
    /* Zero out checksum */
    sbiw  ZL, (IPV4_SRC_ADDR + IPV4_ADDR_LEN - IPV4_H_CHECKSUM)
    st    Z+, ZERO_REG
    st    Z+, ZERO_REG
    sbiw  ZL, (IPV4_H_CHECKSUM + 2) /* set Z to IPv4 header */
    /* TODO: handle better identification */
    std   Z + IPV4_IDENTIFICATION + 0, ZERO_REG
    std   Z + IPV4_IDENTIFICATION + 1, ZERO_REG
    lds   ARG_REG1, SRAM_IPV4_IHL_IN_BYTES
    rcall INTERNET_CHECKSUM_RFC1071
    std   Z + IPV4_H_CHECKSUM + 0, RTV_H_REG
    std   Z + IPV4_H_CHECKSUM + 1, RTV_L_REG

    /* Write IPv4 header into ENC buffer */
    lds   ARG_REG1, SRAM_IPV4_IHL_IN_BYTES
    rcall ETH_WRITE_Z_TO_TRANSMIT_BUFFER

    /* TCP header */
    ldi   ZL, lo8(SRAM_TCP_HEADER)
    ldi   ZH, hi8(SRAM_TCP_HEADER)
    mov   ARG_REG1, TCP_HEADER_LEN_REG
    rcall ETH_WRITE_Z_TO_TRANSMIT_BUFFER
    rcall ETH_WRITE_BUFFER_PACKET_PAYLOAD_FINISH

    ret

/* TCP packet with payload handle {{{2  ----------------------------------------
   */
TCP_PAYLOAD_HANDLE:
    /* Swap Src/Dst ports */
    ldi   ZL, lo8(SRAM_TCP_SRC_PORT)
    ldi   ZH, hi8(SRAM_TCP_SRC_PORT)
    ldi   YL, lo8(SRAM_TCP_DST_PORT)
    ldi   YH, hi8(SRAM_TCP_DST_PORT)
    ldi   ARG_REG1, IPV4_PORT_LEN
    rcall MEMSWAP

    /* Get sequence number */
    /* Get Ack number */
    /* Y was left pointing to Seq. Num. */
    ldi   ZL, lo8(SRAM_TCP_CONNS + TCP_CONN_TBL_REMOTE_SEQ_N)
    ldi   ZH, hi8(SRAM_TCP_CONNS + TCP_CONN_TBL_REMOTE_SEQ_N)
    ldi   ARG_REG1, SEQ_N_LEN * 2
    rcall MEMCPY

    /* TODO: this is handling final ack of 3 way handshake, should go somewhere
     * else */
#if 0
    lds   TMP_REG1, SRAM_IPV4_PAYLOAD_LENGTH_IN_BYTES
    cpi   TMP_REG1, 0
    brne  XXX
    ETH_READ_BUFFER_END
    ret
XXX:
#endif

    /* Set Sequence Number from connection table */
    ldi   ZL, lo8(SRAM_TCP_HEADER + TCP_HEADER_SQNC_N)
    ldi   ZH, hi8(SRAM_TCP_HEADER + TCP_HEADER_SQNC_N)
    ldi   YL, lo8(SRAM_TCP_CONNS + TCP_CONN_TBL_LOCAL_SEQ_N)
    ldi   YH, hi8(SRAM_TCP_CONNS + TCP_CONN_TBL_LOCAL_SEQ_N)
    ldi   ARG_REG1, SEQ_N_LEN
    rcall MEMCPY /* ARG_REG1 was already set to SEQ_N_LEN */

    /* Set Acknowledge Number from connection table */
    sbiw  YL, (TCP_CONN_TBL_LOCAL_SEQ_N - TCP_CONN_TBL_REMOTE_SEQ_N + SEQ_N_LEN)
    rcall MEMCPY /* ARG_REG1 was already set to SEQ_N_LEN */

    /* Get data offset */
    /* Z points to byte 12, data offset */
    ld    TMP_REG1, Z+
    andi  TMP_REG1, 0xF0
    mov   TCP_HEADER_LEN_REG, TMP_REG1
    swap  TCP_HEADER_LEN_REG
    lsl   TCP_HEADER_LEN_REG
    lsl   TCP_HEADER_LEN_REG

    /* Add TCP payload to acknowledge number */
    /* TCP payload = IPv4 Payload - TCP Header */
    ldi   YL, lo8(SRAM_TCP_ACK_N)
    ldi   YH, hi8(SRAM_TCP_ACK_N)
    lds   ARG_REG1, (SRAM_IPV4_PAYLOAD_LENGTH_IN_BYTES + 1)
    sub   ARG_REG1, TCP_HEADER_LEN_REG
    rcall ADD_32b

    /* Set ACK flag */
    ld    TMP_REG1, Z
    ori   TMP_REG1, TCP_HEADER_DO_FLAGS_H_FLAG_ACK
    st    Z, TMP_REG1

    /* Set checksum to zero */
    adiw  ZL, 3
    st    Z+, ZERO_REG
    st    Z+, ZERO_REG

    /* Process options */
    adiw  ZL, 2
    /* The rest of the tcp header is (Data offset * 4 - 20)
     * If we take ZL that points to the beginning of the options and add it
     * (data offset - 5) * 4, we will know when ZL is at the beginning of the
     * data */
    mov   TMP_REG2, TCP_HEADER_LEN_REG
    subi  TMP_REG2, 20
    add   TMP_REG2, ZL /* TMP_REG2 == ZL => First byte of data */
TCP_PAYLOAD_OPTIONS: /* {{{ */
    /* Beyond data offset */
    cp    TMP_REG2, ZL
    breq  TCP_TMP_END_OF_OPTIONS
    ld    TMP_REG1, Z+
    /* Test end of options */
    cpi   TMP_REG1, TCP_OPT_END
    breq  TCP_TMP_END_OF_OPTIONS
    /* Test padding */
    cpi   TMP_REG1, TCP_OPT_NOP
    breq  TCP_PAYLOAD_OPTIONS
    /* Test MSS */
    cpi   TMP_REG1, TCP_OPT_MSS
    brne  TRY_TMP_WSF
    SET_LED1
    adiw  ZL, TCP_OPT_MSS_LEN - 1
    rjmp  TCP_PAYLOAD_OPTIONS
    /* Test WSF */
TRY_TMP_WSF:
    cpi   TMP_REG1, TCP_OPT_WSF
    brne  TRY_TMP_SACK
    adiw  ZL, TCP_OPT_WSF_LEN - 1
    rjmp  TCP_PAYLOAD_OPTIONS
    /* Sack permitted */
TRY_TMP_SACK:
    cpi   TMP_REG1, TCP_OPT_SACK
    brne  TRY_TMP_TTP
    adiw  ZL, TCP_OPT_SACK_LEN - 1
    rjmp  TCP_PAYLOAD_OPTIONS
    /* Test time stamp */
TRY_TMP_TTP:
    cpi   TMP_REG1, TCP_OPT_TTP
    brne  TCP_TMP_OPTIONS_ERR
    /* Copy original time stamp to reply time stamp */
    adiw  ZL, 1
    movw  YL, ZL
    adiw  ZL, 4
    ldi   ARG_REG1, 4
    rcall MEMCPY
    rjmp  TCP_PAYLOAD_OPTIONS
TCP_TMP_OPTIONS_ERR:
    SET_LED0
TCP_TMP_END_OF_OPTIONS: /* }}} */

    ETH_READ_BUFFER_END

    /* HTTP response payload */
    ldi   YL, lo8(EEPROM_HTTP_TEST)
    ldi   YH, hi8(EEPROM_HTTP_TEST)
    ldi   ARG_REG1, (EEPROM_HTTP_TEST_END - EEPROM_HTTP_TEST)
    rcall ES_MEMCPY
    /* Set back Z to beginning of HTTP payload */
    sbiw  ZL, (EEPROM_HTTP_TEST_END - EEPROM_HTTP_RH_OFFSET)

    /* RH */
    ldi   YL, lo8(SRAM_DHT11_PAYLOAD)
    ldi   YH, hi8(SRAM_DHT11_PAYLOAD)
    ld    ARG_REG1, Y+
    ldi   ARG_REG2, 10
    rcall SDIV
    subi  RTV_L_REG, -48 /* + '0' */
    subi  RTV_H_REG, -48 /* + '0' */
    st    Z+, RTV_L_REG
    st    Z+, RTV_H_REG

    adiw  ZL, 1

    ld    ARG_REG1, Y+
    ldi   TMP_REG2, 48
    ldi   TMP_REG1, 10
    mul   ARG_REG1, TMP_REG1
    add   XMULX_RTV_H_REG, TMP_REG2 /* + '0' */
    st    Z+, XMULX_RTV_H_REG
    mul   XMULX_RTV_L_REG, TMP_REG1
    add   XMULX_RTV_H_REG, TMP_REG2 /* + '0' */
    st    Z+, XMULX_RTV_H_REG

    /* Temperature */
    adiw  ZL, 4
    ld    ARG_REG1, Y+
    ldi   ARG_REG2, 10
    rcall SDIV
    subi  RTV_L_REG, -48 /* + '0' */
    subi  RTV_H_REG, -48 /* + '0' */
    st    Z+, RTV_L_REG
    st    Z+, RTV_H_REG

    adiw  ZL, 1

    ld    ARG_REG1, Y+
    ldi   TMP_REG2, 48
    ldi   TMP_REG1, 10
    mul   ARG_REG1, TMP_REG1
    add   XMULX_RTV_H_REG, TMP_REG2 /* + '0' */
    st    Z+, XMULX_RTV_H_REG
    mul   XMULX_RTV_L_REG, TMP_REG1
    add   XMULX_RTV_H_REG, TMP_REG2 /* + '0' */
    st    Z+, XMULX_RTV_H_REG

    /* TCP checksum */
    /* TCP pseudo header */
    /* Copy SRC and DST IP Addresses */
    ldi   ZL, lo8(SRAM_TCP_PSEUDO_HEADER)
    ldi   ZH, hi8(SRAM_TCP_PSEUDO_HEADER)
    ldi   YL, lo8(SRAM_IPV4_HEADER + IPV4_SRC_ADDR)
    ldi   YH, hi8(SRAM_IPV4_HEADER + IPV4_SRC_ADDR)
    ldi   ARG_REG1, IPV4_ADDR_LEN * 2
    rcall MEMCPY

    /* Reserve byte and IPv4 Protocol */
    st    Z+, ZERO_REG
    ldi   YL, lo8(SRAM_IPV4_HEADER + IPV4_PROTOCOL)
    ldi   YH, hi8(SRAM_IPV4_HEADER + IPV4_PROTOCOL)
    ld    TMP_REG1, Y
    st    Z+, TMP_REG1

    /* Length, this length does NOT include the pseudo header length */
    st    Z+, ZERO_REG
    mov   TMP_REG1, TCP_HEADER_LEN_REG
    subi  TMP_REG1, -(EEPROM_HTTP_TEST_END - EEPROM_HTTP_TEST)
    st    Z+, TMP_REG1

    /* Calculate TCP checksum */
    ldi   ZL, lo8(SRAM_TCP_PSEUDO_HEADER)
    ldi   ZH, hi8(SRAM_TCP_PSEUDO_HEADER)
    mov   ARG_REG1, TCP_HEADER_LEN_REG
    subi  ARG_REG1, -12 /* 12 = pseudo header length */
    subi  ARG_REG1, -(EEPROM_HTTP_TEST_END - EEPROM_HTTP_TEST)
    rcall INTERNET_CHECKSUM_RFC1071
    ldi   ZL, lo8(SRAM_TCP_HEADER)
    ldi   ZH, hi8(SRAM_TCP_HEADER)
    std   Z + (TCP_HEADER_CHKSUM + 0), RTV_H_REG
    std   Z + (TCP_HEADER_CHKSUM + 1), RTV_L_REG

    /* Ethernet header */
    rcall ETH_WRITE_BUFFER_PACKET_HEADER
    /* IP header */
    /* Swap SRC/DST IP Addresses */
    ldi   ZL, lo8(SRAM_IPV4_HEADER + IPV4_SRC_ADDR)
    ldi   ZH, hi8(SRAM_IPV4_HEADER + IPV4_SRC_ADDR)
    ldi   YL, lo8(SRAM_IPV4_HEADER + IPV4_DST_ADDR)
    ldi   YH, hi8(SRAM_IPV4_HEADER + IPV4_DST_ADDR)
    ldi   ARG_REG1, IPV4_ADDR_LEN
    rcall MEMSWAP

    /* IPv4 payload length */
    lds   TMP_REG1, SRAM_IPV4_IHL_IN_BYTES
    add   TMP_REG1, TCP_HEADER_LEN_REG
    subi  TMP_REG1, -(EEPROM_HTTP_TEST_END - EEPROM_HTTP_TEST)
    sts   (SRAM_IPV4_HEADER + IPV4_TOTAL_LENGTH + 1), TMP_REG1
    sts   (SRAM_IPV4_HEADER + IPV4_TOTAL_LENGTH + 0), ZERO_REG

    /* ipv4 checksum */
    /* Write IPv4 header into ENC buffer */
    /* Zero out checksum */
    sbiw  ZL, (IPV4_SRC_ADDR + IPV4_ADDR_LEN - IPV4_H_CHECKSUM)
    st    Z+, ZERO_REG
    st    Z+, ZERO_REG
    sbiw  ZL, (IPV4_H_CHECKSUM + 2) /* set Z to IPv4 header */
    /* TODO: handle better identification */
    std   Z + IPV4_IDENTIFICATION + 0, ZERO_REG
    std   Z + IPV4_IDENTIFICATION + 1, ZERO_REG
    lds   ARG_REG1, SRAM_IPV4_IHL_IN_BYTES
    rcall INTERNET_CHECKSUM_RFC1071
    std   Z + IPV4_H_CHECKSUM + 0, RTV_H_REG
    std   Z + IPV4_H_CHECKSUM + 1, RTV_L_REG

    /* Write IPv4 header into ENC buffer */
    lds   ARG_REG1, SRAM_IPV4_IHL_IN_BYTES
    rcall ETH_WRITE_Z_TO_TRANSMIT_BUFFER

    /* TCP header */
    ldi   ZL, lo8(SRAM_TCP_HEADER)
    ldi   ZH, hi8(SRAM_TCP_HEADER)
    mov   ARG_REG1, TCP_HEADER_LEN_REG
    subi  ARG_REG1, -(EEPROM_HTTP_TEST_END - EEPROM_HTTP_TEST)
    rcall ETH_WRITE_Z_TO_TRANSMIT_BUFFER
    rcall ETH_WRITE_BUFFER_PACKET_PAYLOAD_FINISH

#if 0
    /* Fin packet */
    /* TCP sequence number */
    ldi   YL, lo8(SRAM_TCP_SEQ_N)
    ldi   YH, hi8(SRAM_TCP_SEQ_N)
    ldi   ARG_REG1, (EEPROM_HTTP_TEST_END - EEPROM_HTTP_TEST)
    rcall ADD_32b
    /* TCP pseudo header */
    /* set length */
    ldi   ZL, lo8(SRAM_TCP_PSEUDO_HEADER + 2 * IPV4_ADDR_LEN + 2)
    ldi   ZH, hi8(SRAM_TCP_PSEUDO_HEADER + 2 * IPV4_ADDR_LEN + 2)
    st    Z+, ZERO_REG
    st    Z, TCP_HEADER_LEN_REG
    /* Calculate TCP checksum */
    ldi   ZL, lo8(SRAM_TCP_PSEUDO_HEADER)
    ldi   ZH, hi8(SRAM_TCP_PSEUDO_HEADER)
    mov   ARG_REG1, TCP_HEADER_LEN_REG
    subi  ARG_REG1, -12 /* 12 = pseudo header length */
    rcall INTERNET_CHECKSUM_RFC1071
    ldi   ZL, lo8(SRAM_TCP_HEADER)
    ldi   ZH, hi8(SRAM_TCP_HEADER)
    std   Z + (TCP_HEADER_CHKSUM + 0), RTV_H_REG
    std   Z + (TCP_HEADER_CHKSUM + 1), RTV_L_REG

    /* Ethernet header */
    rcall ETH_WRITE_BUFFER_PACKET_HEADER
    /* IP header */
    ldi   ZL, lo8(SRAM_IPV4_HEADER + IPV4_SRC_ADDR)
    ldi   ZH, hi8(SRAM_IPV4_HEADER + IPV4_SRC_ADDR)
    /* IPv4 payload */
    lds   TMP_REG1, SRAM_IPV4_IHL_IN_BYTES
    add   TMP_REG1, TCP_HEADER_LEN_REG
    sts   (SRAM_IPV4_HEADER + IPV4_TOTAL_LENGTH + 1), TMP_REG1

    /* ipv4 checksum */
    /* Write IPv4 header into ENC buffer */
    /* Zero out checksum */
    ldi   ZL, lo8(SRAM_IPV4_HEADER + IPV4_H_CHECKSUM)
    ldi   ZH, hi8(SRAM_IPV4_HEADER + IPV4_H_CHECKSUM)
    st    Z+, ZERO_REG
    st    Z+, ZERO_REG
    sbiw  ZL, (IPV4_H_CHECKSUM + 2) /* set Z to IPv4 header */
    /* TODO: handle better identification */
    std   Z + IPV4_IDENTIFICATION + 0, ZERO_REG
    std   Z + IPV4_IDENTIFICATION + 1, ZERO_REG
    lds   ARG_REG1, SRAM_IPV4_IHL_IN_BYTES
    add   ARG_REG1, TCP_HEADER_LEN_REG
    rcall INTERNET_CHECKSUM_RFC1071
    std   Z + IPV4_H_CHECKSUM + 0, RTV_H_REG
    std   Z + IPV4_H_CHECKSUM + 1, RTV_L_REG

    /* Write IPv4 header into ENC buffer */
    lds   ARG_REG1, SRAM_IPV4_IHL_IN_BYTES
    rcall ETH_WRITE_Z_TO_TRANSMIT_BUFFER

    /* TCP header */
    ldi   ZL, lo8(SRAM_TCP_HEADER)
    ldi   ZH, hi8(SRAM_TCP_HEADER)
    ldd   TMP_REG1, Z + (TCP_HEADER_DO_FLAGS + 1)
    sbr   TMP_REG1, (1 << TCP_HEADER_FLAG_FIN)
    cbr   TMP_REG1, (1 << TCP_HEADER_FLAG_PSH)
    std   Z + (TCP_HEADER_DO_FLAGS + 1), TMP_REG1
    mov   ARG_REG1, TCP_HEADER_LEN_REG
    rcall ETH_WRITE_Z_TO_TRANSMIT_BUFFER
    rcall ETH_WRITE_BUFFER_PACKET_PAYLOAD_FINISH
#endif
    ret

.end
