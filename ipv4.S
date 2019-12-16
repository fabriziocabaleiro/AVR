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
.global IPV4_PREPARE_INCOMING_HEADER_FOR_RESPONSE

.global SRAM_IPV4_IHL_IN_BYTES
.global SRAM_IPV4_PAYLOAD_LENGTH_IN_BYTES
.global SRAM_IPV4_HEADER
.global SRAM_IPV4_PAYLOAD
.global SRAM_IP_ADDR_DST

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
IPV4_HANDLE_PKT:
    push  ZH
    push  ZL
    push  s1 /* IPv4 broadcast and unicast to me flags */

    /* Read IPv4 Header */
    ldi   ZL, lo8(SRAM_IPV4_HEADER)
    ldi   ZH, hi8(SRAM_IPV4_HEADER)
    rcall ETH_READ_BUFFER_START

    /* Read the first byte, which contains the version and the header length,
     * assign counter with the length and check that version is 4, if not,
     * return 1 and exit */
    ETH_READ_NEXT_BYTE
    st    Z+, x4
    mov   t3, x4
    /* Check if IPv4 */
    andi  x4, 0xF0
    cpi   x4, 0x40
    /* Only IPv4 will be handle, other versions will be ignore */
    breq  PACKET_IS_IPV4
    rjmp  IPV4_HANDLE_EXIT
PACKET_IS_IPV4:
    andi  t3, 0x0F
    /* Length is in 32bits words, as reading bytes, then IHL * 4, then subtract
     * one as the first bytes was already read */
    lsl   t3
    lsl   t3
    /* Taking the chance to store the Internet Header Length in bytes */
    sts   SRAM_IPV4_IHL_IN_BYTES, t3
    /* We already read one byte (version|IHL), so, subtract 1 */
    subi  t3, 1
    /* Read the rest of the IPv4 header */
READ_HEADER:
    ETH_READ_NEXT_BYTE
    st    Z+, x4
    dec   t3
    brne  READ_HEADER
    ETH_READ_BUFFER_END

    push  YL
    push  YH
    /* Check if Dst IP Address is ours */
    clr   s1
    ldi   YH, hi8(EEPROM_IP_ADDR)
    ldi   YL, lo8(EEPROM_IP_ADDR)
    ldi   ZL, lo8(SRAM_IPV4_HEADER + IPV4_DST_ADDR)
    ldi   ZH, hi8(SRAM_IPV4_HEADER + IPV4_DST_ADDR)
    ldi   x1, IPV4_ADDR_LEN
    rcall ES_MEMCMP
    brne  0f
    sbr   s1, (1 << RECEIVED_IP_IS_MINE_BIT)
0:

    /* Check if Dst IP Address is broadcast */
    movw  YL, ZL
    ldi   x2, 0xFF
    rcall REG_MEMCMP
    brne  0f
    sbr   s1, (1 << RECEIVED_IP_IS_BROADCAST_BIT)
0:

    /* Get and store IPv4 Payload length in bytes */
    sbiw  YL, (IPV4_DST_ADDR - IPV4_TOTAL_LENGTH - 1)
    ld    t1, Y
    lds   t2, SRAM_IPV4_IHL_IN_BYTES
    sub   t1, t2 /* total length - header */
    /* TODO: use STD which is lighter than STS */
    sts   SRAM_IPV4_PAYLOAD_LENGTH_IN_BYTES + 1, t1
    ld    t1, -Y
    sbc   t1, zero
    sts   SRAM_IPV4_PAYLOAD_LENGTH_IN_BYTES, t1

    pop   YH
    pop   YL

    sts   SRAM_IPV4_FLAGS, s1

    /* Deliver packet using IPv4 protocol {{{ */
    sbiw  ZL, IPV4_DST_ADDR
    /* Load Internet protocol number */
    ldd   t1, Z + IPV4_PROTOCOL

    /* We may receive a DHCP packet that doesn't have our current IP address,
     * therefore we don't check if Dst IP Addr is ours */
    cpi   t1, INTERNET_PROTOCOL_NUMBER_USER_DATAGRAM
    brne  RETURN_IF_IP_PACKET_NOT_FOR_ME
    rcall UDP_HANDLE_PKT
    rjmp  IPV4_HANDLE_EXIT

    /* Stop processing IP packet if Dst IP address is not mine */
RETURN_IF_IP_PACKET_NOT_FOR_ME:
    sbrs  s1, RECEIVED_IP_IS_MINE_BIT
    rjmp  IPV4_HANDLE_EXIT

TRY_PROTOCOL_ICMP:
    cpi   t1, INTERNET_PROTOCOL_NUMBER_ICMP
    brne  TRY_PROTOCOL_TCP
    rcall ICMP_HANDLE_PKT
    rjmp  IPV4_HANDLE_EXIT

TRY_PROTOCOL_TCP:
    cpi   t1, INTERNET_PROTOCOL_NUMBER_TCP
    brne  IPV4_HANDLE_EXIT
    /* TCP not implemented yet */
    rcall TCP_HANDLE_PKT
    rjmp  IPV4_HANDLE_EXIT
    /* }}} */

IPV4_HANDLE_EXIT:
    pop   s1
    pop   ZL
    pop   ZH
    ret

/* Internet Checksum RFC 1071 {{{2 ---------------------------------------------
 * Byte order independent
 *
 * Input:
 *   ZH:ZL Address to start reading from
 *   x1    Bytes to read.
 *   x2[0] == 1 ? Include Pseudo header.
 *
 * Return value (checksum) in [x3:x4]
 * previous value of Y is lost, caller must take care of it. */
INTERNET_CHECKSUM_RFC1071:
    push  ZL
    push  ZH
    push  YL
    push  YH
    push  s1
    push  s2
    push  x1

    mov   s2, x1
    clr   x4
    clr   x3
    clr   t2

    clc   /* Clear any carry from before */

IPV4_PING_CHECKSUM_LOOP:
    ld    t1, Z+
    sbrs  t2, 0
    adc   x3, t1
    sbrc  t2, 0
    adc   x4, t1
    inc   t2
    dec   x1
    brne  IPV4_PING_CHECKSUM_LOOP

    /* pseudo header */
    sbrs  x2, 0
    rjmp  INTERNET_CHECKSUM_LOOP_END

    /* Save Status Register to continue summation with pseudo header */
    in    s1, _SFR_IO_ADDR(SREG)

    /* Copy src/dst IP addresses */
    ldi   YL, lo8(SRAM_IPV4_HEADER + IPV4_SRC_ADDR)
    ldi   YH, hi8(SRAM_IPV4_HEADER + IPV4_SRC_ADDR)
    ldi   ZL, lo8(SRAM_IPV4_PSEUDO_HEADER)
    ldi   ZH, hi8(SRAM_IPV4_PSEUDO_HEADER)
    ldi   x1, IPV4_ADDR_LEN * 2
    rcall MEMCPY

    /* Reserve byte and IPv4 Protocol */
    st    Z+, zero
    lds   t1, (SRAM_IPV4_HEADER + IPV4_PROTOCOL)
    st    Z+, t1

    /* Length, this length does NOT include the pseudo header length */
    st    Z+, zero
    st    Z+, s2
    
    cbr   x2, 1
    clr   t2
    ldi   ZL, lo8(SRAM_IPV4_PSEUDO_HEADER)
    ldi   ZH, hi8(SRAM_IPV4_PSEUDO_HEADER)
    ldi   x1, IPV4_PSEUDO_HEADER_LEN
    out   _SFR_IO_ADDR(SREG), s1
    rjmp  IPV4_PING_CHECKSUM_LOOP

INTERNET_CHECKSUM_LOOP_END:
    /* If the last addition generated a Carry, then add zero with carry, which
     * could also generate a Carry into x3, so, add zero with carry as
     * well */
    adc   x3, zero
    adc   x4, zero

    com   x4
    com   x3

    pop   x1
    pop   s2
    pop   s1
    pop   YH
    pop   YL
    pop   ZH
    pop   ZL
    ret

/* Prepare IPv4 header {{{2 ----------------------------------------------------
 * x1 total size */
IPV4_PREPARE_DEFAULT_HEADER_20_40_BYTES:
    push  YH
    push  YL
    push  ZH
    push  ZL

    /* Read from */
    /* TODO: ES_MEMCMP */
    ldi   YL, lo8(EEPROM_IP_HEADER)
    ldi   YH, hi8(EEPROM_IP_HEADER)
    ldi   t3, (EEPROM_IP_HEADER_TIL_CHK_SUM - EEPROM_IP_HEADER)
    /* Write to */
    ldi   ZL, lo8(SRAM_IPV4_HEADER)
    ldi   ZH, hi8(SRAM_IPV4_HEADER)
IPV4_PREPARE_HEADER_GET_FROM_EEPROM:
    rcall EEPROM_READ_N_INC
    st    Z+, x4
    dec   t3
    brne  IPV4_PREPARE_HEADER_GET_FROM_EEPROM
    /* till here we have 10 bytes written. Now we have to write checksum and
     * src/dst IP addresses */
    /* Write zero checksum for the moment */
    st    Z+, zero
    st    Z+, zero

    /* SRC IP Address */
    ldi   YL, lo8(EEPROM_IP_ADDR)
    ldi   YH, hi8(EEPROM_IP_ADDR)
    ldi   t3, IPV4_ADDR_LEN
IPV4_PREPARE_HEADER_GET_IP_FROM_EEPROM:
    rcall EEPROM_READ_N_INC
    st    Z+, x4
    dec   t3
    brne  IPV4_PREPARE_HEADER_GET_IP_FROM_EEPROM

    /* DST IP Address */
    /* TODO: MEMCPY */
    ldi   YL, lo8(SRAM_IP_ADDR_DST)
    ldi   YH, hi8(SRAM_IP_ADDR_DST)
    ldi   t3, IPV4_ADDR_LEN
IPV4_PREPARE_HEADER_GET_IP_FROM_EEPROM_DST:
    ld    t1, Y+
    st    Z+, t1
    dec   t3
    brne  IPV4_PREPARE_HEADER_GET_IP_FROM_EEPROM_DST

    /* Update Total length and calculate Checksum */
    ldi   ZL, lo8(SRAM_IPV4_HEADER)
    ldi   ZH, hi8(SRAM_IPV4_HEADER)
    std   Z + (IPV4_TOTAL_LENGTH + 1), x1

    ldi   x1, IPV4_DEFAULT_HEADER_LEN
    ldi   x2, 0
    rcall INTERNET_CHECKSUM_RFC1071
    std   Z + (IPV4_H_CHECKSUM + 0), x3
    std   Z + (IPV4_H_CHECKSUM + 1), x4

    pop   ZL
    pop   ZH
    pop   YL
    pop   YH
    ret

/* Using incoming IPv4 header for outgoing IPv4 header {{{2 --------------------
   x1: IPv4 Total Length in bytes
   Z will be left pointing to SRAM_IPV4_HEADER
   */
IPV4_PREPARE_INCOMING_HEADER_FOR_RESPONSE:
    push  YL
    push  YH

    /* IPv4 payload length */
    ldi   ZL, lo8(SRAM_IPV4_HEADER)
    ldi   ZH, hi8(SRAM_IPV4_HEADER)
    std   Z + (IPV4_TOTAL_LENGTH + 0), zero
    std   Z + (IPV4_TOTAL_LENGTH + 1), x1

    /* Swap SRC/DST IP Addresses */
    adiw  ZL, IPV4_SRC_ADDR
    ldi   YL, lo8(SRAM_IPV4_HEADER + IPV4_DST_ADDR)
    ldi   YH, hi8(SRAM_IPV4_HEADER + IPV4_DST_ADDR)
    ldi   x1, IPV4_ADDR_LEN
    rcall MEMSWAP

    /* ipv4 checksum */
    /* Zero out checksum */
    sbiw  ZL, (IPV4_SRC_ADDR + IPV4_ADDR_LEN - IPV4_H_CHECKSUM)
    st    Z+, zero
    st    Z+, zero
    sbiw  ZL, (IPV4_H_CHECKSUM + 2) /* set Z to IPv4 header */
    /* TODO: handle identification ? */
    lds   x1, SRAM_IPV4_IHL_IN_BYTES
    ldi   x2, 0
    rcall INTERNET_CHECKSUM_RFC1071
    std   Z + IPV4_H_CHECKSUM + 0, x3
    std   Z + IPV4_H_CHECKSUM + 1, x4

    pop   YH
    pop   YL
    ret

.end
