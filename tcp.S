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
/* s1 should not be used in the rest of this file */
#define TCP_HEADER_LEN_REG   s1
#define TCP_PAYLOAD_LEN_REG  s2
#define SEQ_N_LEN            4
#define TCP_PAYLOAD_LEN      (EEPROM_HTTP_RESPONSE_END - EEPROM_HTTP_RESPONSE)

/* GLOBAL {{{1 ---------------------------------------------------------------*/
.global TCP_HANDLE_PKT

/* DATA  {{{1 ----------------------------------------------------------------*/
.section .data
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

/* TEXT {{{1 -----------------------------------------------------------------*/
.section .text

/* TCP Handle {{{2 -----------------------------------------------------------*/
TCP_HANDLE_PKT:
    push  TCP_HEADER_LEN_REG
    push  TCP_PAYLOAD_LEN_REG
    rcall ETH_READ_BUFFER_START

    /* Read TCP header until beginning of options */
    ldi   t3, TCP_HEADER_OPTIONS
    ldi   ZL, lo8(SRAM_TCP_HEADER)
    ldi   ZH, hi8(SRAM_TCP_HEADER)
0:  ETH_READ_NEXT_BYTE
    st    Z+, x4
    dec   t3
    brne  0b

    /* Get the TCP header length in bytes */
    /* Load Data Offset + Flags. Remove Flags and Swap */
    lds   t1, SRAM_TCP_DO_FLAGS
    swap  t1
    andi  t1, 0x0F
    /* data offset from words to bytes (*4) */
    lsl   t1
    lsl   t1
    mov   TCP_HEADER_LEN_REG, t1

    /* Read the TCP options, remove constant TCP header length */
    mov   t3, TCP_HEADER_LEN_REG
    subi  t3, TCP_HEADER_OPTIONS
    breq  END_OF_OPTIONS
0:  ETH_READ_NEXT_BYTE
    st    Z+, x4
    dec   t3
    brne  0b
END_OF_OPTIONS:

    /* Common modification from incoming packet to outgoing packet */
    /* Swap Src/Dst ports */
    ldi   ZL, lo8(SRAM_TCP_SRC_PORT)
    ldi   ZH, hi8(SRAM_TCP_SRC_PORT)
    ldi   YL, lo8(SRAM_TCP_DST_PORT)
    ldi   YH, hi8(SRAM_TCP_DST_PORT)
    ldi   x1, IPV4_PORT_LEN
    rcall MEMSWAP

    /* Handle sequence number and acknowledge number */
    /* Swap sequence number with acknowledge number */
    /* Y was left pointing to Seq. Num. */
    ldi   ZL, lo8(SRAM_TCP_ACK_N)
    ldi   ZH, hi8(SRAM_TCP_ACK_N)
    ldi   x1, 4
    rcall MEMSWAP

    /* Increment acknowledge number by:
     *  1 if SYN or FIN packet
     *  TCP Payload */
    /* Z was left pointing to SRAM_TCP_DO_FLAGS */
    adiw  ZL, 1
    ld    t1, Z+ /* Z is going to point to SRAM_TCP_WINDOW */
    clr   t2
    andi  t1, (1 << TCP_HEADER_FLAG_SYN | 1 << TCP_HEADER_FLAG_FIN)
    breq  0f
    inc   t2
    /* TODO: add support for 16b payload size */
0:  lds   x1, (SRAM_IPV4_PAYLOAD_LENGTH_IN_BYTES + 1)
    sub   x1, TCP_HEADER_LEN_REG
    add   x1, t2
    /* Y is pointing to SRAM_TCP_ACK_N from previous MEMSWAP */
    rcall ADD_32b

    /* Set checksum to zero */
    adiw  ZL, 2 /* point to SRAM_TCP_CHKSUM */
    st    Z+, zero
    st    Z+, zero

    /* Process options */
    adiw  ZL, 2 /* skip SRAM_TCP_URGENT_P */
    /* The rest of the tcp header is (Data offset * 4 - 20)
     * If we take ZL that points to the beginning of the options and add it
     * (data offset - 5) * 4, we will know when ZL is at the beginning of the
     * data */
    mov   t2, TCP_HEADER_LEN_REG
    subi  t2, 20
    add   t2, ZL /* t2 == ZL => First byte of data */
TCP_SYN_OPTIONS: /* {{{ */
    /* Check if ZL >= t2, simple comparison based on post-compile check
     * PCC0001 */
    cp    t2, ZL
    brsh  TCP_END_OF_OPTIONS
    ld    t1, Z+
    /* Test end of options */
    cpi   t1, TCP_OPT_END
    breq  TCP_END_OF_OPTIONS
    /* Test padding */
    cpi   t1, TCP_OPT_NOP
    breq  TCP_SYN_OPTIONS
    /* Test MSS */
    cpi   t1, TCP_OPT_MSS
    brne  TRY_WSF
    adiw  ZL, TCP_OPT_MSS_LEN - 1
    rjmp  TCP_SYN_OPTIONS
    /* Test WSF */
TRY_WSF:
    cpi   t1, TCP_OPT_WSF
    brne  TRY_SACK
    adiw  ZL, TCP_OPT_WSF_LEN - 1
    rjmp  TCP_SYN_OPTIONS
    /* Sack permitted */
TRY_SACK:
    cpi   t1, TCP_OPT_SACK
    brne  TRY_TTP
    adiw  ZL, TCP_OPT_SACK_LEN - 1
    rjmp  TCP_SYN_OPTIONS
    /* Test time stamp */
TRY_TTP:
    cpi   t1, TCP_OPT_TTP
    brne  TCP_OPTIONS_ERR
    /* Copy original time stamp to reply time stamp */
    adiw  ZL, 1
    movw  YL, ZL
    adiw  ZL, 4
    ldi   x1, 4
    rcall MEMCPY
    rjmp  TCP_SYN_OPTIONS
TCP_OPTIONS_ERR:
TCP_END_OF_OPTIONS: /* }}} */
    ETH_READ_BUFFER_END

    /* Set Z to TCP header */
    ldi   ZL, lo8(SRAM_TCP_HEADER)
    ldi   ZH, hi8(SRAM_TCP_HEADER)

    /* Check if SYN packet */
    ldd   t1, Z + (TCP_HEADER_DO_FLAGS + 1)
    andi  t1, (1 << TCP_HEADER_FLAG_SYN | 1 << TCP_HEADER_FLAG_FIN)
    breq  0f

    /* Handle SYN/FIN */
    ldd   t1, Z + (TCP_HEADER_DO_FLAGS + 1)
    ori   t1, TCP_HEADER_DO_FLAGS_H_FLAG_ACK
    std   Z + (TCP_HEADER_DO_FLAGS + 1), t1
    clr   TCP_PAYLOAD_LEN_REG
    rjmp  TCP_HANDLE_PKT_TO_NETWORK

    /* Not SYN/FIN, then move Z to beginning of TCP payload */
0:  add   ZL, TCP_HEADER_LEN_REG
    adc   ZH, zero
    /* Call Handle if TCP packet has payload */
    lds   t1, (SRAM_IPV4_PAYLOAD_LENGTH_IN_BYTES + 1)
    sub   t1, TCP_HEADER_LEN_REG
    breq  TCP_HANDLE_PKT_END

    /* TCP_PAYLOAD_HANDLE returns the size of the payload */
    rcall HTTP_HANDLE_PKT
    mov   TCP_PAYLOAD_LEN_REG, x4

TCP_HANDLE_PKT_TO_NETWORK:
    /* Calculate checksums and lengths and write packets to ENC28J60 */
    /* TCP checksum, include Pseudo header */
    ldi   ZL, lo8(SRAM_TCP_HEADER)
    ldi   ZH, hi8(SRAM_TCP_HEADER)
    mov   x1, TCP_HEADER_LEN_REG
    add   x1, TCP_PAYLOAD_LEN_REG
    ldi   x2, 1
    rcall INTERNET_CHECKSUM_RFC1071
    std   Z + (TCP_HEADER_CHKSUM + 0), x3
    std   Z + (TCP_HEADER_CHKSUM + 1), x4

    /* Ethernet header */
    rcall ETH_WRITE_BUFFER_PACKET_HEADER

    /* IPv4 header */
    /* IPv4 payload length */
    lds   x1, SRAM_IPV4_IHL_IN_BYTES
    add   x1, TCP_HEADER_LEN_REG
    add   x1, TCP_PAYLOAD_LEN_REG
    rcall IPV4_PREPARE_INCOMING_HEADER_FOR_RESPONSE

    /* Write IPv4 header into ENC buffer */
    lds   x1, SRAM_IPV4_IHL_IN_BYTES
    rcall ETH_WRITE_Z_TO_TRANSMIT_BUFFER

    /* TCP header */
    ldi   ZL, lo8(SRAM_TCP_HEADER)
    ldi   ZH, hi8(SRAM_TCP_HEADER)
    mov   x1, TCP_HEADER_LEN_REG
    add   x1, TCP_PAYLOAD_LEN_REG
    rcall ETH_WRITE_Z_TO_TRANSMIT_BUFFER
    rcall ETH_WRITE_BUFFER_PACKET_PAYLOAD_FINISH

TCP_HANDLE_PKT_END:
    pop   TCP_PAYLOAD_LEN_REG
    pop   TCP_HEADER_LEN_REG
    ret

.end
