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
/* SAVED1_REG should not be used in the rest of this file */
#define TCP_HEADER_LEN_REG   SAVED1_REG
#define TCP_PAYLOAD_LEN_REG  SAVED2_REG
#define SEQ_N_LEN            4
#define TCP_PAYLOAD_LEN      20

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
    ldi   COUNTER_REG, TCP_HEADER_OPTIONS
    ldi   ZL, lo8(SRAM_TCP_HEADER)
    ldi   ZH, hi8(SRAM_TCP_HEADER)
0:  ETH_READ_NEXT_BYTE
    st    Z+, RTV_L_REG
    dec   COUNTER_REG
    brne  0b

    /* Get the TCP header length in bytes */
    /* Load Data Offset + Flags. Remove Flags and Swap */
    lds   TMP_REG1, SRAM_TCP_DO_FLAGS
    swap  TMP_REG1
    andi  TMP_REG1, 0x0F
    /* data offset from words to bytes (*4) */
    lsl   TMP_REG1
    lsl   TMP_REG1
    mov   TCP_HEADER_LEN_REG, TMP_REG1

    /* Read the TCP options, remove constant TCP header length */
    mov   COUNTER_REG, TCP_HEADER_LEN_REG
    subi  COUNTER_REG, TCP_HEADER_OPTIONS
    breq  END_OF_OPTIONS
0:  ETH_READ_NEXT_BYTE
    st    Z+, RTV_L_REG
    dec   COUNTER_REG
    brne  0b
END_OF_OPTIONS:

    /* Common modification from incoming packet to outgoing packet */
    /* Swap Src/Dst ports */
    ldi   ZL, lo8(SRAM_TCP_SRC_PORT)
    ldi   ZH, hi8(SRAM_TCP_SRC_PORT)
    ldi   YL, lo8(SRAM_TCP_DST_PORT)
    ldi   YH, hi8(SRAM_TCP_DST_PORT)
    ldi   ARG_REG1, IPV4_PORT_LEN
    rcall MEMSWAP

    /* Handle sequence number and acknowledge number */
    /* Swap sequence number with acknowledge number */
    /* Y was left pointing to Seq. Num. */
    ldi   ZL, lo8(SRAM_TCP_ACK_N)
    ldi   ZH, hi8(SRAM_TCP_ACK_N)
    ldi   ARG_REG1, 4
    rcall MEMSWAP

    /* Increment acknowledge number by:
     *  1 if SYN or FIN packet
     *  TCP Payload */
    /* Z was left pointing to SRAM_TCP_DO_FLAGS */
    adiw  ZL, 1
    ld    TMP_REG1, Z+ /* Z is going to point to SRAM_TCP_WINDOW */
    clr   TMP_REG2
    andi  TMP_REG1, (1 << TCP_HEADER_FLAG_SYN | 1 << TCP_HEADER_FLAG_FIN)
    breq  0f
    inc   TMP_REG2
    /* TODO: add support for 16b payload size */
0:  lds   ARG_REG1, (SRAM_IPV4_PAYLOAD_LENGTH_IN_BYTES + 1)
    sub   ARG_REG1, TCP_HEADER_LEN_REG
    add   ARG_REG1, TMP_REG2
    /* Y is pointing to SRAM_TCP_ACK_N from previous MEMSWAP */
    rcall ADD_32b

    /* Set checksum to zero */
    adiw  ZL, 2 /* point to SRAM_TCP_CHKSUM */
    st    Z+, ZERO_REG
    st    Z+, ZERO_REG

    /* Process options */
    adiw  ZL, 2 /* skip SRAM_TCP_URGENT_P */
    /* The rest of the tcp header is (Data offset * 4 - 20)
     * If we take ZL that points to the beginning of the options and add it
     * (data offset - 5) * 4, we will know when ZL is at the beginning of the
     * data */
    mov   TMP_REG2, TCP_HEADER_LEN_REG
    subi  TMP_REG2, 20
    add   TMP_REG2, ZL /* TMP_REG2 == ZL => First byte of data */
TCP_SYN_OPTIONS: /* {{{ */
    /* Check if ZL >= TMP_REG2, simple comparison based on post-compile check
     * PCC0001 */
    cp    TMP_REG2, ZL
    brsh  TCP_END_OF_OPTIONS
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
TCP_END_OF_OPTIONS: /* }}} */
    ETH_READ_BUFFER_END

    /* Set Z to TCP header */
    ldi   ZL, lo8(SRAM_TCP_HEADER)
    ldi   ZH, hi8(SRAM_TCP_HEADER)

    /* Check if SYN packet */
    ldd   TMP_REG1, Z + (TCP_HEADER_DO_FLAGS + 1)
    andi  TMP_REG1, (1 << TCP_HEADER_FLAG_SYN | 1 << TCP_HEADER_FLAG_FIN)
    breq  0f

    /* Handle SYN/FIN */
    ldd   TMP_REG1, Z + (TCP_HEADER_DO_FLAGS + 1)
    ori   TMP_REG1, TCP_HEADER_DO_FLAGS_H_FLAG_ACK
    std   Z + (TCP_HEADER_DO_FLAGS + 1), TMP_REG1
    clr   TCP_PAYLOAD_LEN_REG
    rjmp  TCP_HANDLE_PKT_TO_NETWORK

    /* Not SYN/FIN, then move Z to beginning of TCP payload */
0:  add   ZL, TCP_HEADER_LEN_REG
    adc   ZH, ZERO_REG
    /* Call Handle if TCP packet has payload */
    lds   TMP_REG1, (SRAM_IPV4_PAYLOAD_LENGTH_IN_BYTES + 1)
    sub   TMP_REG1, TCP_HEADER_LEN_REG
    breq  TCP_HANDLE_PKT_END

    /* TCP_PAYLOAD_HANDLE returns the size of the payload */
    rcall HTTP_HANDLE_PKT
    mov   TCP_PAYLOAD_LEN_REG, RTV_L_REG

TCP_HANDLE_PKT_TO_NETWORK:
    /* Calculate checksums and lengths and write packets to ENC28J60 */
    /* TCP checksum, include Pseudo header */
    ldi   ZL, lo8(SRAM_TCP_HEADER)
    ldi   ZH, hi8(SRAM_TCP_HEADER)
    mov   ARG_REG1, TCP_HEADER_LEN_REG
    add   ARG_REG1, TCP_PAYLOAD_LEN_REG
    ldi   ARG_REG2, 1
    rcall INTERNET_CHECKSUM_RFC1071
    std   Z + (TCP_HEADER_CHKSUM + 0), RTV_H_REG
    std   Z + (TCP_HEADER_CHKSUM + 1), RTV_L_REG

    /* Ethernet header */
    rcall ETH_WRITE_BUFFER_PACKET_HEADER

    /* IPv4 header */
    /* IPv4 payload length */
    lds   ARG_REG1, SRAM_IPV4_IHL_IN_BYTES
    add   ARG_REG1, TCP_HEADER_LEN_REG
    add   ARG_REG1, TCP_PAYLOAD_LEN_REG
    rcall IPV4_PREPARE_INCOMING_HEADER_FOR_RESPONSE

    /* Write IPv4 header into ENC buffer */
    lds   ARG_REG1, SRAM_IPV4_IHL_IN_BYTES
    rcall ETH_WRITE_Z_TO_TRANSMIT_BUFFER

    /* TCP header */
    ldi   ZL, lo8(SRAM_TCP_HEADER)
    ldi   ZH, hi8(SRAM_TCP_HEADER)
    mov   ARG_REG1, TCP_HEADER_LEN_REG
    add   ARG_REG1, TCP_PAYLOAD_LEN_REG
    rcall ETH_WRITE_Z_TO_TRANSMIT_BUFFER
    rcall ETH_WRITE_BUFFER_PACKET_PAYLOAD_FINISH

TCP_HANDLE_PKT_END:
    pop   TCP_PAYLOAD_LEN_REG
    pop   TCP_HEADER_LEN_REG
    ret

.end
