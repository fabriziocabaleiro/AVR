/* vim: set filetype=S foldmethod=marker: */
/* INCLUDES {{{1 */
.NOLIST
#include <avr/io.h>
#include "enc28j60.h"
#include "ipv4.h"
#include "defs.h"
#include "eeprom_data.h"
.LIST

/* MACORS {{{1 ---------------------------------------------------------------*/
#define IPV4_PSEUDO_HEADER_LEN (IPV4_ADDR_LEN * 2 + 1 + 1 + 2) /* 12 */

/* GLOBAL {{{1 ---------------------------------------------------------------*/
.global IPV4_HANDLE_PKT
.global INTERNET_CHECKSUM_RFC1071
.global IPV4_PREPARE_DEFAULT_HEADER_20_40_BYTES

.global SRAM_IPV4_IHL_IN_BYTES
.global SRAM_IPV4_PAYLOAD_LENGTH_IN_BYTES
.global SRAM_IPV4_HEADER
.global SRAM_IPV4_PAYLOAD
.global SRAM_IP_ADDR_DST
.global IPV4_PSEUDO_HEADER_SUM

/* DATA  {{{1 ----------------------------------------------------------------*/
.section .data
SRAM_IPV4_PSEUDO_HEADER:
SRAM_IPV4_PSEUDO_HEADER_SRC_ADDR: .skip IPV4_ADDR_LEN
SRAM_IPV4_PSEUDO_HEADER_DST_ADDR: .skip IPV4_ADDR_LEN
SRAM_IPV4_PSEUDO_HEADER_ZEROS:    .skip 1
SRAM_IPV4_PSEUDO_HEADER_PROTOCOL: .skip 1
SRAM_IPV4_PSEUDO_HEADER_LENGTH:   .skip 2
SRAM_IPV4_FLAGS:        .skip   1
SRAM_IPV4_HEADER:       .skip   IPV4_MAX_HEADER_LEN
/* Internet Header Length in bytes */
SRAM_IPV4_IHL_IN_BYTES: .skip   1
/* Internet Payload Length in bytes */
SRAM_IPV4_PAYLOAD_LENGTH_IN_BYTES: .skip 2
/* Destination IP Address, when sending an IP packet, caller routine should set
 * the DST IP address here */
SRAM_IP_ADDR_DST:       .skip   IPV4_ADDR_LEN
SRAM_IPV4_PAYLOAD:      .skip   IPV4_PAYLOAD_LEN

/* TEXT {{{1 -----------------------------------------------------------------*/
.section .text

/* Handle IPv4 packet {{{2 -----------------------------------------------------
 * Check protocol (tcp, udp, etc) and port to deliver to corresponding routine
 * IP version != 4 will be ignore */
#define IPV4_HEADER_FLAGS_REG R23
#define RECEIVED_IP_IS_MINE_BIT      3
#define RECEIVED_IP_IS_BROADCAST_BIT 7
IPV4_HANDLE_PKT:
    push  ZH
    push  ZL
    push  IPV4_HEADER_FLAGS_REG

    /* Read IPv4 Header */
    ldi   ZL, lo8(SRAM_IPV4_HEADER)
    ldi   ZH, hi8(SRAM_IPV4_HEADER)
    rcall ETH_READ_BUFFER_START

    /* Read the first byte, which contains the version and the header length,
     * assign counter with the length and check that version is 4, if not,
     * return 1 and exit */
    ETH_READ_NEXT_BYTE
    st    Z+, RTV_L_REG
    mov   COUNTER_REG, RTV_L_REG
    /* Check if IPv4 */
    andi  RTV_L_REG, 0xF0
    cpi   RTV_L_REG, 0x40
    /* Only IPv4 will be handle, other versions will be ignore */
    breq  PACKET_IS_IPV4
    rjmp  IPV4_HANDLE_EXIT
PACKET_IS_IPV4:
    andi  COUNTER_REG, 0x0F
    /* Length is in 32bits words, as reading bytes, then IHL * 4, then subtract
     * one as the first bytes was already read */
    lsl   COUNTER_REG
    lsl   COUNTER_REG
    /* Taking the chance to store the Internet Header Length in bytes */
    sts   SRAM_IPV4_IHL_IN_BYTES, COUNTER_REG
    /* We already read one byte (version|IHL), so, subtract 1 */
    subi  COUNTER_REG, 1
    /* Read the rest of the IPv4 header */
READ_HEADER:
    ETH_READ_NEXT_BYTE
    st    Z+, RTV_L_REG
    dec   COUNTER_REG
    brne  READ_HEADER
    ETH_READ_BUFFER_END

    push  YL
    push  YH
    /* Check if Dst IP Address is ours */
    clr   IPV4_HEADER_FLAGS_REG
    ldi   YH, hi8(EEPROM_IP_ADDR)
    ldi   YL, lo8(EEPROM_IP_ADDR)
    ldi   ZL, lo8(SRAM_IPV4_HEADER + IPV4_DST_ADDR)
    ldi   ZH, hi8(SRAM_IPV4_HEADER + IPV4_DST_ADDR)
    ldi   ARG_REG1, IPV4_ADDR_LEN
    rcall ES_MEMCMP
    brne  0f
    sbr   IPV4_HEADER_FLAGS_REG, (1 << RECEIVED_IP_IS_MINE_BIT)
0:

    /* Check if Dst IP Address is broadcast */
    movw  YL, ZL
    ldi   ARG_REG2, 0xFF
    rcall REG_MEMCMP
    brne  0f
    sbr   IPV4_HEADER_FLAGS_REG, (1 << RECEIVED_IP_IS_BROADCAST_BIT)
0:

    /* Get and store IPv4 Payload length in bytes */
    sbiw  YL, (IPV4_DST_ADDR - IPV4_TOTAL_LENGTH - 1)
    ld    TMP_REG1, Y
    lds   TMP_REG2, SRAM_IPV4_IHL_IN_BYTES
    sub   TMP_REG1, TMP_REG2 /* total length - header */
    /* TODO: use STD which is lighter than STS */
    sts   SRAM_IPV4_PAYLOAD_LENGTH_IN_BYTES + 1, TMP_REG1
    ld    TMP_REG1, -Y
    sbc   TMP_REG1, ZERO_REG
    sts   SRAM_IPV4_PAYLOAD_LENGTH_IN_BYTES, TMP_REG1

    pop   YH
    pop   YL

    sts   SRAM_IPV4_FLAGS, IPV4_HEADER_FLAGS_REG

    /* Deliver packet using IPv4 protocol {{{ */
    sbiw  ZL, IPV4_DST_ADDR
    /* Load Internet protocol number */
    ldd   TMP_REG1, Z + IPV4_PROTOCOL

    /* We may receive a DHCP packet that doesn't have our current IP address,
     * therefore we don't check if Dst IP Addr is ours */
    cpi   TMP_REG1, INTERNET_PROTOCOL_NUMBER_USER_DATAGRAM
    brne  RETURN_IF_IP_PACKET_NOT_FOR_ME
    rcall UDP_HANDLE_PKT
    rjmp  IPV4_HANDLE_EXIT

    /* Stop processing IP packet if Dst IP address is not mine */
RETURN_IF_IP_PACKET_NOT_FOR_ME:
    sbrs  IPV4_HEADER_FLAGS_REG, RECEIVED_IP_IS_MINE_BIT
    rjmp  IPV4_HANDLE_EXIT

TRY_PROTOCOL_ICMP:
    cpi   TMP_REG1, INTERNET_PROTOCOL_NUMBER_ICMP
    brne  TRY_PROTOCOL_TCP
    rcall ICMP_HANDLE_PKT
    rjmp  IPV4_HANDLE_EXIT

TRY_PROTOCOL_TCP:
    cpi   TMP_REG1, INTERNET_PROTOCOL_NUMBER_TCP
    brne  IPV4_HANDLE_EXIT
    /* TCP not implemented yet */
    rcall TCP_HANDLE_PKT
    rjmp  IPV4_HANDLE_EXIT
    /* }}} */

IPV4_HANDLE_EXIT:
    pop   IPV4_HEADER_FLAGS_REG
    pop   ZL
    pop   ZH
    ret

/* Internet Checksum RFC 1071 {{{2 ---------------------------------------------
 * Byte order independent
 *
 * Input:
 *   ZH:ZL     Address to start reading from
 *   ARG_REG1  Bytes to read, if odd, then, rounded down.
 *   ARG_REG2[0] == 1 ? Include Pseudo header.
 *
 * Return value (checksum) in [RTV_H_REG:RTV_L_REG]
 * previous value of Y is lost, caller must take care of it. */
INTERNET_CHECKSUM_RFC1071:
    push  ZL
    push  ZH
    push  YL
    push  YH
    push  SAVED1_REG
    push  SAVED2_REG
    push  ARG_REG1

    mov   SAVED2_REG, ARG_REG1
    clr   RTV_L_REG
    clr   RTV_H_REG
    clr   TMP_REG2

    clc   /* Clear any carry from before */

IPV4_PING_CHECKSUM_LOOP:
    ld    TMP_REG1, Z+
    sbrs  TMP_REG2, 0
    adc   RTV_H_REG, TMP_REG1
    sbrc  TMP_REG2, 0
    adc   RTV_L_REG, TMP_REG1
    inc   TMP_REG2
    dec   ARG_REG1
    brne  IPV4_PING_CHECKSUM_LOOP

    /* pseudo header */
    sbrs  ARG_REG2, 0
    rjmp  INTERNET_CHECKSUM_LOOP_END

    /* Save Status Register to continue summation with pseudo header */
    in    SAVED1_REG, _SFR_IO_ADDR(SREG)

    /* Copy src/dst IP addresses */
    ldi   YL, lo8(SRAM_IPV4_HEADER + IPV4_SRC_ADDR)
    ldi   YH, hi8(SRAM_IPV4_HEADER + IPV4_SRC_ADDR)
    ldi   ZL, lo8(SRAM_IPV4_PSEUDO_HEADER)
    ldi   ZH, hi8(SRAM_IPV4_PSEUDO_HEADER)
    ldi   ARG_REG1, IPV4_ADDR_LEN * 2
    rcall MEMCPY

    /* Reserve byte and IPv4 Protocol */
    st    Z+, ZERO_REG
    lds   TMP_REG1, (SRAM_IPV4_HEADER + IPV4_PROTOCOL)
    st    Z+, TMP_REG1

    /* Length, this length does NOT include the pseudo header length */
    st    Z+, ZERO_REG
    st    Z+, SAVED2_REG
    
    cbr   ARG_REG2, 1
    clr   TMP_REG2
    ldi   ZL, lo8(SRAM_IPV4_PSEUDO_HEADER)
    ldi   ZH, hi8(SRAM_IPV4_PSEUDO_HEADER)
    ldi   ARG_REG1, IPV4_PSEUDO_HEADER_LEN
    out   _SFR_IO_ADDR(SREG), SAVED1_REG
    rjmp  IPV4_PING_CHECKSUM_LOOP

INTERNET_CHECKSUM_LOOP_END:
    /* If the last addition generated a Carry, then add zero with carry, which
     * could also generate a Carry into RTV_H_REG, so, add zero with carry as
     * well */
    adc   RTV_H_REG, ZERO_REG
    adc   RTV_L_REG, ZERO_REG

    com   RTV_L_REG
    com   RTV_H_REG

    pop   ARG_REG1
    pop   SAVED2_REG
    pop   SAVED1_REG
    pop   YH
    pop   YL
    pop   ZH
    pop   ZL
    ret

/* Prepare IPv4 header {{{2 ----------------------------------------------------
 * ARG_REG1 total size */
IPV4_PREPARE_DEFAULT_HEADER_20_40_BYTES:
    push  YH
    push  YL
    push  ZH
    push  ZL

    /* Read from */
    /* TODO: ES_MEMCMP */
    ldi   YL, lo8(EEPROM_IP_HEADER)
    ldi   YH, hi8(EEPROM_IP_HEADER)
    ldi   COUNTER_REG, (EEPROM_IP_HEADER_TIL_CHK_SUM - EEPROM_IP_HEADER)
    /* Write to */
    ldi   ZL, lo8(SRAM_IPV4_HEADER)
    ldi   ZH, hi8(SRAM_IPV4_HEADER)
IPV4_PREPARE_HEADER_GET_FROM_EEPROM:
    rcall EEPROM_READ_N_INC
    st    Z+, RTV_L_REG
    dec   COUNTER_REG
    brne  IPV4_PREPARE_HEADER_GET_FROM_EEPROM
    /* till here we have 10 bytes written. Now we have to write checksum and
     * src/dst IP addresses */
    /* Write zero checksum for the moment */
    st    Z+, ZERO_REG
    st    Z+, ZERO_REG

    /* SRC IP Address */
    ldi   YL, lo8(EEPROM_IP_ADDR)
    ldi   YH, hi8(EEPROM_IP_ADDR)
    ldi   COUNTER_REG, IPV4_ADDR_LEN
IPV4_PREPARE_HEADER_GET_IP_FROM_EEPROM:
    rcall EEPROM_READ_N_INC
    st    Z+, RTV_L_REG
    dec   COUNTER_REG
    brne  IPV4_PREPARE_HEADER_GET_IP_FROM_EEPROM

    /* DST IP Address */
    /* TODO: MEMCPY */
    ldi   YL, lo8(SRAM_IP_ADDR_DST)
    ldi   YH, hi8(SRAM_IP_ADDR_DST)
    ldi   COUNTER_REG, IPV4_ADDR_LEN
IPV4_PREPARE_HEADER_GET_IP_FROM_EEPROM_DST:
    ld    TMP_REG1, Y+
    st    Z+, TMP_REG1
    dec   COUNTER_REG
    brne  IPV4_PREPARE_HEADER_GET_IP_FROM_EEPROM_DST

    /* Update Total length and calculate Checksum */
    ldi   ZL, lo8(SRAM_IPV4_HEADER)
    ldi   ZH, hi8(SRAM_IPV4_HEADER)
    std   Z + (IPV4_TOTAL_LENGTH + 1), ARG_REG1

    ldi   ARG_REG1, IPV4_DEFAULT_HEADER_LEN
    ldi   ARG_REG2, 0
    rcall INTERNET_CHECKSUM_RFC1071
    std   Z + (IPV4_H_CHECKSUM + 0), RTV_H_REG
    std   Z + (IPV4_H_CHECKSUM + 1), RTV_L_REG

    pop   ZL
    pop   ZH
    pop   YL
    pop   YH
    ret

.end
