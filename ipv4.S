/* vim: set filetype=S foldmethod=marker: */
.NOLIST
#include <avr/io.h>
#include "enc28j60.h"
#include "ipv4.h"
#include "defs.h"
.LIST

.global IPV4_HANDLE_PKT
.global INTERNET_CHECKSUM_RFC1071
.global IPV4_PREPARE_DEFAULT_HEADER_20_40_BYTES

.global SRAM_IPV4_IHL_IN_BYTES
.global SRAM_IPV4_HEADER
.global SRAM_IPV4_PAYLOAD
.global SRAM_IP_ADDR_DST

.section .data
SRAM_IPV4_HEADER:       .skip   IPV4_MAX_HEADER_LEN
SRAM_IPV4_PAYLOAD:      .skip   IPV4_PAYLOAD_LEN
SRAM_IPV4_IHL_IN_BYTES: .skip   1
/* This is the default IP address to send packages to,
 * it should be set by password authentication or something else, but, for now,
 * just assigning it through ping request */
SRAM_IP_ADDR_DST:       .skip   IPV4_ADDR_LEN

.section .text
/*******************************************************************************
 * Handle IPv4 packet {{{
 * Check protocol (tcp, udp, etc) and port to deliver to corresponding routine
 * IP version != 4 will be ignore
 ******************************************************************************/
IPV4_HANDLE_PKT:
    push  ZH
    push  ZL

    /* Read IPv4 Header {{{ */
    ldi   ZL, lo8(SRAM_IPV4_HEADER)
    ldi   ZH, hi8(SRAM_IPV4_HEADER)
    rcall ETH_READ_BUFFER_START

    /* Read the first byte, which contains the version and the header length,
     * assign counter with the length and check that version is 4, if not,
     * return 1 and exit */
    ETH_READ_NEXT_BYTE
    st    Z+, RETURN_VALUE
    mov   COUNTER_REG, RETURN_VALUE
    andi  RETURN_VALUE, 0xF0
    cpi   RETURN_VALUE, 0x40
    /* Only IPv4 will be handle, other versions will be ignore */
    breq  PACKET_IS_IPV4
    rjmp  IPV4_HANDLE_EXIT_SUCCESS
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
    st    Z+, RETURN_VALUE
    dec   COUNTER_REG
    brne  READ_HEADER
    ETH_READ_BUFFER_END
    /* }}} */
    /* Check if IPv4 packet is for me, set IPV4_PACKET_FOR_ME {{{
     * Beware EEPROM_READ_N_INC does not modify TMP_REG[123]
     * DHCP may have an IPv4 Dst address different than mine... */
    push  YL
    push  YH

/* Setting RECEIVED_IP* bits at the beginning, then subtracting, if 4
 * subtractions, then the MSB of the nibble will be zero */
#define RECEIVED_IP_IS_MINE_BIT      3
#define RECEIVED_IP_IS_BROADCAST_BIT 7
    clr   TMP_REG2 /* Using nibble to check My IP addr or Broadcast */
    ldi   YH, hi8(EEPROM_IP_ADDR)
    ldi   YL, lo8(EEPROM_IP_ADDR)
    ldi   ZL, lo8(SRAM_IPV4_HEADER)
    ldi   ZH, hi8(SRAM_IPV4_HEADER)
    ldi   COUNTER_REG, IPV4_SIZE_IN_BYTES
CHECK_IP_ADDR:
    rcall EEPROM_READ_N_INC
    ldd   TMP_REG1, Z + IPV4_DST_ADDR
    cp    TMP_REG1, RETURN_VALUE
    brne  NOT_MY_IP
    subi  TMP_REG2, -0x01
NOT_MY_IP:
    cpi   TMP_REG1, 0xFF
    brne  NOT_BROADCAST
    subi  TMP_REG2, -0x10
NOT_BROADCAST:
    adiw  ZL, 1
    dec   COUNTER_REG
    brne  CHECK_IP_ADDR

    pop   YH
    pop   YL

#if 0 // debug
    ldi   YL, lo8(EEPROM_DEBUG)
    ldi   YH, hi8(EEPROM_DEBUG)
    mov   ARG_REG1, TMP_REG2
    rcall EEPROM_WRITE_N_INC
    ERR_SET
#endif

    /* }}} */
    /* Deliver packet using IPv4 protocol {{{ */
    /* Faster than setting ZH:ZL, just subtract... previously added value */
    sbiw  ZL, IPV4_SIZE_IN_BYTES
    /* Load Internet protocol number */
    ldd   TMP_REG1, Z + IPV4_PROTOCOL

    /* We may receive a DHCP packet that doesn't have our current IP address,
     * therefore we ignore IPV4_PACKET_FOR_ME for the moment */
    cpi   TMP_REG1, INTERNET_PROTOCOL_NUMBER_USER_DATAGRAM
    brne  RETURN_IF_IP_PACKET_NOT_FOR_ME
    rcall UDP_HANDLE_PKT
    rjmp  IPV4_HANDLE_EXIT_SUCCESS

RETURN_IF_IP_PACKET_NOT_FOR_ME:
    sbrc  TMP_REG2, RECEIVED_IP_IS_MINE_BIT
    rjmp  IPV4_HANDLE_EXIT_SUCCESS

TRY_PROTOCOL_ICMP:
    cpi   TMP_REG1, INTERNET_PROTOCOL_NUMBER_ICMP
    brne  TRY_PROTOCOL_TCP
    rcall ICMP_HANDLE_PKT
    rjmp  IPV4_HANDLE_EXIT_SUCCESS

TRY_PROTOCOL_TCP:
#if 0
    cpi   TMP_REG2, INTERNET_PROTOCOL_NUMBER_TCP
    brne  TRY_PROTOCOL_UDP
    /* TCP not implemented yet */
    rcall TCP_HANDLE_PKT
    rjmp  IPV4_HANDLE_EXIT_SUCCESS
#endif
    /* }}} */

IPV4_HANDLE_EXIT_SUCCESS:
    ldi   RETURN_VALUE, 0
IPV4_HANDLE_END:
    pop   ZL
    pop   ZH
    ret
/* }}} */
/*******************************************************************************
 * Internet Checksum RFC 1071 {{{
 * Byte order independent
 *
 * Input:
 *   ZH:ZL     Address to start reading from
 *   ARG_REG1  Bytes to read, if odd, then, rounded down.
 *
 * Return value (checksum) in Y
 * previous value of Y is lost, caller must take care of it.
 ******************************************************************************/
INTERNET_CHECKSUM_RFC1071:
    push  ZL
    push  ZH
    push  ARG_REG1

    clr   YL
    clr   YH

    lsr   ARG_REG1 /* adding by word */
    clc   /* Clear any carry from before */

IPV4_PING_CHECKSUM_LOOP:
    ld    TMP_REG1, Z+
    adc   YH, TMP_REG1
    ld    TMP_REG1, Z+
    adc   YL, TMP_REG1
    dec   ARG_REG1
    brne  IPV4_PING_CHECKSUM_LOOP

    brcc  IPV4_PING_CHECKSUM_END
    /* If the last addition generated a Carry, then add zero with carry, which
     * could also generate a Carry into YH, so, add zero with carry as well */
    clr   TMP_REG1
IPV4_PING_CHECKSUM_REMAINING_CARRY:
    adc   YH, TMP_REG1
    adc   YL, TMP_REG1
    brcs  IPV4_PING_CHECKSUM_REMAINING_CARRY

IPV4_PING_CHECKSUM_END:
    com   YL
    com   YH

    pop   ARG_REG1
    pop   ZH
    pop   ZL
    ret
/* }}} */
/*******************************************************************************
 * Prepare IPv4 header {{{
 * This routine returns the size of the header
 * ARG_REG1 total size
 ******************************************************************************/
IPV4_PREPARE_DEFAULT_HEADER_20_40_BYTES:
    push  YH
    push  YL
    push  ZH
    push  ZL

    /* Read from */
    ldi   YL, lo8(EEPROM_IP_HEADER)
    ldi   YH, hi8(EEPROM_IP_HEADER)
    ldi   COUNTER_REG, (EEPROM_IP_HEADER_TIL_CHK_SUM - EEPROM_IP_HEADER)
    /* Write to */
    ldi   ZL, lo8(SRAM_IPV4_HEADER)
    ldi   ZH, hi8(SRAM_IPV4_HEADER)
IPV4_PREPARE_HEADER_GET_FROM_EEPROM:
    rcall EEPROM_READ_N_INC
    st    Z+, RETURN_VALUE
    dec   COUNTER_REG
    brne  IPV4_PREPARE_HEADER_GET_FROM_EEPROM
    /* till here we have 10 bytes written. Now we have to write checksum and
     * src/dst IP addresses */
    /* Write zero checksum for the moment */
    clr   TMP_REG1
    st    Z+, TMP_REG1
    st    Z+, TMP_REG1

    /* SRC IP Address */
    ldi   YL, lo8(EEPROM_IP_ADDR)
    ldi   YH, hi8(EEPROM_IP_ADDR)
    ldi   COUNTER_REG, IPV4_SIZE_IN_BYTES
IPV4_PREPARE_HEADER_GET_IP_FROM_EEPROM:
    rcall EEPROM_READ_N_INC
    st    Z+, RETURN_VALUE
    dec   COUNTER_REG
    brne  IPV4_PREPARE_HEADER_GET_IP_FROM_EEPROM

    /* DST IP Address */
    ldi   YL, lo8(SRAM_IP_ADDR_DST)
    ldi   YH, hi8(SRAM_IP_ADDR_DST)
    ldi   COUNTER_REG, IPV4_SIZE_IN_BYTES
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
    rcall INTERNET_CHECKSUM_RFC1071
    std   Z + (IPV4_H_CHECKSUM + 0), YH
    std   Z + (IPV4_H_CHECKSUM + 1), YL

    ldi   RETURN_VALUE, IPV4_DEFAULT_HEADER_LEN

    pop   ZL
    pop   ZH
    pop   YL
    pop   YH
    ret
/* }}} */

.end
