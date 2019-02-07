/* vim: set filetype=S foldmethod=marker: */
#include "enc28j60.S"
#include "defs.h"
#ifndef __IPV4_S__
#define __IPV4_S__

#if 0 /* IPv4 header */
    0               1               2               3
    0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 0 |Version|  IHL  |Type of Service|          Total Length         |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 4 |         Identification        |Flags|      Fragment Offset    |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 8 |  Time to Live |    Protocol   |         Header Checksum       |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
12 |                       Source Address                          |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
16 |                    Destination Address                        |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
20 |                    Options                    |    Padding    |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
#endif
#define IPV4_VERSION          0
#define IPV4_IHL              0 /* Internet Header Length in words of 4 bytes */
#define IPV4_TOS              1
#define IPV4_TOTAL_LENGTH     2 /* In bytes */
#define IPV4_IDENTIFICATION   4
#define IPV4_FLAGS            6
#define IPV4_FRAG_OFFSET      6
#define IPV4_TTL              8
#define IPV4_PROTOCOL         9
#define IPV4_H_CHECKSUM      10
#define IPV4_SRC_ADDR        12
#define IPV4_DST_ADDR        16
#define IPV4_OPTIONS         20

#define IPV4_ICMP_TOM         0 /* Type of message */
#define IPV4_ICMP_CODE        1
#define IPV4_ICMP_CHECKSUM    2
#define IPV4_ICMP_HEADER      4
#define IPV4_ICMP_PAYLOAD     8 /* Optional */

/* TODO: improve defines */
#define IPV4_TOS_PING         0
#define IPV4_PROTOCOL_PING    1

#define COUNTER R16
#define DATA    R17
#define READ_NEXT_BYTE rcall SPI_MASTER_TRANSMIT

/*******************************************************************************
 * Read IPv4 Header
 ******************************************************************************/
IPV4_READ_HEADER:
    push  COUNTER
    push  ZH
    push  ZL

    ldi   ZL, lo8(IPV4_HEADER)
    ldi   ZH, hi8(IPV4_HEADER)

    rcall ETH_READ_BUFFER_START
    /* Read the first byte, which contains the version and the header length,
     * assign counter with the length and check that version is 4, if not,
     * return 1 and exit */
    READ_NEXT_BYTE
    st    Z+, RETURN_VALUE
    mov   COUNTER, RETURN_VALUE
    andi  COUNTER, 0x0F
    swap  RETURN_VALUE
    andi  RETURN_VALUE, 0x0F
    cpi   RETURN_VALUE, 0x04
    brne  IPV4_WRONG_VERSION
    /* Length is in 32bits words, as reading bytes, then IHL * 4, then subtract
     * one as the first bytes was already read */
    lsl   COUNTER
    lsl   COUNTER
    subi  COUNTER, 1

IPV4_READ_HEADER_LOOP:
    READ_NEXT_BYTE
    st    Z+, RETURN_VALUE
    dec   COUNTER
    brne  IPV4_READ_HEADER_LOOP

IPV4_READ_HEADER_FINISH:
    ETH_READ_BUFFER_END
    pop   ZL
    pop   ZH
    pop   COUNTER
    ret

IPV4_WRONG_VERSION:
    ldi   RETURN_VALUE, 1
    rjmp  IPV4_READ_HEADER_FINISH

/*******************************************************************************
 * PING
 ******************************************************************************/
IPV4_RESPONSE_IF_PING:
    push  COUNTER
    push  TMP1
    push  ZL
    push  ZH

    /* Check if Type of service "ping" */
    ldi   ZL, lo8(IPV4_HEADER)
    ldi   ZH, hi8(IPV4_HEADER)
    ldd   TMP1, Z + IPV4_TOS
    cpi   TMP1, IPV4_TOS_PING
    brne  IPV4_NOT_PING_1
    /* Check if protocol ICMP */
    ldd   TMP1, Z + IPV4_PROTOCOL
    cpi   TMP1, IPV4_PROTOCOL_PING
    brne  IPV4_NOT_PING_1

    rjmp  IPV4_IS_PING

IPV4_NOT_PING_1:
    pop   ZH
    pop   ZL
    pop   TMP1
    pop   COUNTER
    ldi   RETURN_VALUE, 1
    ret

IPV4_IS_PING:
    /* Write Ethernet header to write buffer */
    rcall ETH_WRITE_BUFFER_PACKET_HEADER

    /* Read IPv4 Payload into SRAM */
    /* First check that payload is smaller than 200 bytes */
    ldd   COUNTER, Z + IPV4_TOTAL_LENGTH
    cpi   COUNTER, 0
    brne  IPV4_PING_PAYLOAD_TOO_BIG
    ldd   COUNTER, Z + IPV4_TOTAL_LENGTH + 1
    cpi   COUNTER, IPV4_PAYLOAD_LEN
    brlt  IPV4_PING_PAYLOAD_TOO_BIG

    /* Before reading PING PAYLOAD, swap IP addresses (preparing ipv4 response
     * header */
    push  COUNTER
    ldi   COUNTER, MAC_SIZE_IN_BYTES
IPV4_RESPONSE_IF_PING_SWAP_IP_ADDR:
    ldd   TMP1, Z + IPV4_SRC_ADDR
    push  TMP1
    ldd   TMP1, Z + IPV4_DST_ADDR
    std   Z + IPV4_SRC_ADDR, TMP1
    pop   TMP1
    std   Z + IPV4_DST_ADDR, TMP1
    adiw  ZL, 1
    dec   COUNTER
    brne  IPV4_RESPONSE_IF_PING_SWAP_IP_ADDR
    pop   COUNTER

    /* Read payload */
    ldi   ZL, lo8(IPV4_PAYLOAD)
    ldi   ZH, hi8(IPV4_PAYLOAD)
    rcall ETH_READ_BUFFER_START
IPV4_RESPONSE_IF_PING_READ_PAYLOAD:
    READ_NEXT_BYTE
    st    Z+, RETURN_VALUE
    dec   COUNTER
    brne  IPV4_RESPONSE_IF_PING_READ_PAYLOAD
    ETH_READ_BUFFER_END

    /* First byte of PING payload is 8 for request and 0 for reply */
    ldi   TMP1, 0
    sts   IPV4_PAYLOAD, TMP1

    /* TODO: calculate checksum */
    ldi   ZL, lo8(IPV4_HEADER)
    ldi   ZH, hi8(IPV4_HEADER)
    ldd   ARG_REG1, Z + IPV4_IHL
    lsl   ARG_REG1 /* IHL * 4 to be in bytes */
    lsl   ARG_REG1
    push  ARG_REG1
    push  ZL
    push  ZH
    rcall ETH_WRITE_BUFFER_PACKET_PAYLOAD
    pop   ZH
    pop   ZL
    pop   ARG_REG1

    /* Total length - IHL * 4 is the size of the payload */
    ldd   TMP1, Z + IPV4_TOTAL_LENGTH + 1
    sub   TMP1, ARG_REG1
    mov   ARG_REG1, TMP1
    ldi   ZL, lo8(IPV4_PAYLOAD)
    ldi   ZH, hi8(IPV4_PAYLOAD)

    /* ARG_REG1 & Z must be not changed by IPV4_PING_CHECKSUM */
    push  YL
    push  YH
    rcall IPV4_PING_CHECKSUM
    std   Z + IPV4_ICMP_CHECKSUM, YH
    std   Z + IPV4_ICMP_CHECKSUM + 1, YL
    pop   YH
    pop   YL

    rcall ETH_WRITE_BUFFER_PACKET_PAYLOAD
    rcall ETH_WRITE_BUFFER_PACKET_PAYLOAD_FINISH

    ldi   RETURN_VALUE, 0
IPV4_RESPONSE_IF_PING_END:
    pop   ZH
    pop   ZL
    pop   TMP1
    pop   COUNTER
    ret

IPV4_NOT_PING:
    ldi   RETURN_VALUE, 1
    rjmp  IPV4_RESPONSE_IF_PING_END
    ERR_ETH_SET_ERROR
IPV4_PING_PAYLOAD_TOO_BIG:
    ldi   RETURN_VALUE, 2
    ERR_ETH_SET_ERROR
    rjmp  IPV4_RESPONSE_IF_PING_END

/*******************************************************************************
 * Calculate checksum with carry
 * Value is written into Y
 * Previous value of Y is lost
 * Using address set by Z
 * Using ARG_REG1 as counter
 ******************************************************************************/
IPV4_PING_CHECKSUM:
    push  ZL
    push  ZH
    push  ARG_REG1
    push  DATA

    /* Clear received checksum */
    ldi   DATA, 0
    std   Z + IPV4_ICMP_CHECKSUM, DATA
    std   Z + IPV4_ICMP_CHECKSUM + 1, DATA
    clr   YL
    clr   YH

    lsr   ARG_REG1 /* adding by word */
    clc   /* Clear any carry from before */

IPV4_PING_CHECKSUM_LOOP:
    ld    DATA, Z+
    push  DATA
    ld    DATA, Z+
    adc   YL, DATA
    pop   DATA
    adc   YH, DATA
    dec   ARG_REG1
    brne  IPV4_PING_CHECKSUM_LOOP

    brcc  IPV4_PING_CHECKSUM_END
    /* If the last addition generated a Carry, then add zero with carry, which
     * could also generate a Carry into YH, so, add zero with carry as well */
    ldi   DATA, 0
    adc   YL, DATA
    adc   YH, DATA

IPV4_PING_CHECKSUM_END:
    com   YL
    com   YH

    pop   DATA
    pop   ARG_REG1
    pop   ZH
    pop   ZL
    ERR_ETH_SET_ERROR
    ret

#endif
