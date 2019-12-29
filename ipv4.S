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

/* Using (EEPROM_IP_HEADER_END - EEPROM_IP_HEADER) within ipv4.h is hacking, as
 * including eeprom_data.h in ipv4.h doesn't work, so don't use those macros in
 * ipv4.h, but check that we are defining the correct value.
 * We define the default IPv4 header in the EERPOM. */
#if (IPV4_DEFAULT_HEADER_LEN != (EEPROM_IP_HEADER_END - EEPROM_IP_HEADER))
#   error "IPV4_DEFAULT_HEADER_LEN != (EEPROM_IP_HEADER_END - EEPROM_IP_HEADER)"
#endif

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
    push  zh
    push  zl
    push  s1 /* IPv4 broadcast and unicast to me flags */

    /* Read IPv4 Header */
    ldi   zl, lo8(SRAM_IPV4_HEADER)
    ldi   zh, hi8(SRAM_IPV4_HEADER)
    rcall ETH_READ_BUFFER_START

    /* Read the first byte, which contains the version and the header length,
     * assign counter with the length and check that version is 4, if not,
     * return 1 and exit */
    ETH_READ_NEXT_BYTE
    st    z+, a4
    mov   t3, a4
    /* Check if IPv4 */
    andi  a4, 0xF0
    cpi   a4, 0x40
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
    st    z+, a4
    dec   t3
    brne  READ_HEADER
    ETH_READ_BUFFER_END

    push  xl
    push  xh
    /* Check if Dst IP Address is ours */
    clr   s1
    ldi   xh, hi8(EEPROM_IP_ADDR)
    ldi   xl, lo8(EEPROM_IP_ADDR)
    ldi   zl, lo8(SRAM_IPV4_HEADER + IPV4_DST_ADDR)
    ldi   zh, hi8(SRAM_IPV4_HEADER + IPV4_DST_ADDR)
    ldi   a1, IPV4_ADDR_LEN
    rcall ES_MEMCMP
    brne  0f
    sbr   s1, (1 << RECEIVED_IP_IS_MINE_BIT)
0:

    /* Check if Dst IP Address is broadcast */
    movw  xl, zl
    ldi   a2, 0xFF
    rcall REG_MEMCMP
    brne  0f
    sbr   s1, (1 << RECEIVED_IP_IS_BROADCAST_BIT)
0:

    /* Get and store IPv4 Payload length in bytes */
    sbiw  xl, (IPV4_DST_ADDR - IPV4_TOTAL_LENGTH - 1)
    ld    t1, x
    lds   t2, SRAM_IPV4_IHL_IN_BYTES
    sub   t1, t2 /* total length - header */
    /* TODO: use STD which is lighter than STS */
    sts   SRAM_IPV4_PAYLOAD_LENGTH_IN_BYTES + 1, t1
    ld    t1, -x
    sbc   t1, zero
    sts   SRAM_IPV4_PAYLOAD_LENGTH_IN_BYTES, t1

    pop   xh
    pop   xl

    sts   SRAM_IPV4_FLAGS, s1

    /* Deliver packet using IPv4 protocol {{{ */
    sbiw  zl, IPV4_DST_ADDR
    /* Load Internet protocol number */
    ldd   t1, z + IPV4_PROTOCOL

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
    pop   zl
    pop   zh
    ret

/* Internet Checksum RFC 1071 {{{2 ---------------------------------------------
 * Byte order independent
 *
 * Input:
 *   zh:zl Address to start reading from
 *   a1    Bytes to read.
 *   a2[0] == 1 ? Include Pseudo header.
 *
 * Return value (checksum) in [a3:a4]
 * previous value of x is lost, caller must take care of it. */
INTERNET_CHECKSUM_RFC1071:
    push  zl
    push  zh
    push  xl
    push  xh
    push  s1
    push  s2
    push  a1

    mov   s2, a1
    clr   a4
    clr   a3
    clr   t2

    clc   /* Clear any carry from before */

IPV4_PING_CHECKSUM_LOOP:
    ld    t1, z+
    sbrs  t2, 0
    adc   a3, t1
    sbrc  t2, 0
    adc   a4, t1
    inc   t2
    dec   a1
    brne  IPV4_PING_CHECKSUM_LOOP

    /* pseudo header */
    sbrs  a2, 0
    rjmp  INTERNET_CHECKSUM_LOOP_END

    /* Save Status Register to continue summation with pseudo header */
    in    s1, _SFR_IO_ADDR(SREG)

    /* Copy src/dst IP addresses */
    ldi   xl, lo8(SRAM_IPV4_HEADER + IPV4_SRC_ADDR)
    ldi   xh, hi8(SRAM_IPV4_HEADER + IPV4_SRC_ADDR)
    ldi   zl, lo8(SRAM_IPV4_PSEUDO_HEADER)
    ldi   zh, hi8(SRAM_IPV4_PSEUDO_HEADER)
    ldi   a1, IPV4_ADDR_LEN * 2
    rcall MEMCPY

    /* Reserve byte and IPv4 Protocol */
    st    z+, zero
    lds   t1, (SRAM_IPV4_HEADER + IPV4_PROTOCOL)
    st    z+, t1

    /* Length, this length does NOT include the pseudo header length */
    st    z+, zero
    st    z+, s2
    
    cbr   a2, 1
    clr   t2
    ldi   zl, lo8(SRAM_IPV4_PSEUDO_HEADER)
    ldi   zh, hi8(SRAM_IPV4_PSEUDO_HEADER)
    ldi   a1, IPV4_PSEUDO_HEADER_LEN
    out   _SFR_IO_ADDR(SREG), s1
    rjmp  IPV4_PING_CHECKSUM_LOOP

INTERNET_CHECKSUM_LOOP_END:
    /* If the last addition generated a Carry, then add zero with carry, which
     * could also generate a Carry into a3, so, add zero with carry as
     * well */
    adc   a3, zero
    adc   a4, zero

    com   a4
    com   a3

    pop   a1
    pop   s2
    pop   s1
    pop   xh
    pop   xl
    pop   zh
    pop   zl
    ret

/* Prepare IPv4 header {{{2 ----------------------------------------------------
 * a1 total size */
IPV4_PREPARE_DEFAULT_HEADER_20_40_BYTES:
    push  a1

    /* Get default header from EEPROM (don't include src/dst ip addresses */
    ldi   xl, lo8(EEPROM_IP_HEADER)
    ldi   xh, hi8(EEPROM_IP_HEADER)
    ldi   zl, lo8(SRAM_IPV4_HEADER)
    ldi   zh, hi8(SRAM_IPV4_HEADER)
    ldi   a1, (EEPROM_IP_HEADER_TIL_SRC_IP_ADDR - EEPROM_IP_HEADER)
    rcall ES_MEMCPY

    /* SRC IP Address */
    ldi   xl, lo8(EEPROM_IP_ADDR)
    ldi   xh, hi8(EEPROM_IP_ADDR)
    ldi   a1, IPV4_ADDR_LEN
    rcall ES_MEMCPY

    /* DST IP Address */
    ldi   xl, lo8(SRAM_IP_ADDR_DST)
    ldi   xh, hi8(SRAM_IP_ADDR_DST)
    ldi   a1, IPV4_ADDR_LEN
    rcall MEMCPY

    /* Update Total length and calculate Checksum */
    sbiw  zl, IPV4_DEFAULT_HEADER_LEN
    pop   a1
    std   z + (IPV4_TOTAL_LENGTH + 1), a1

    /* Calculate and set checksum */
    ldi   a1, IPV4_DEFAULT_HEADER_LEN
    clr   a2
    rcall INTERNET_CHECKSUM_RFC1071
    std   z + (IPV4_H_CHECKSUM + 0), a3
    std   z + (IPV4_H_CHECKSUM + 1), a4

    ret

/* Using incoming IPv4 header for outgoing IPv4 header {{{2 --------------------
   a1: IPv4 Total Length in bytes
   z will be left pointing to SRAM_IPV4_HEADER
   */
IPV4_PREPARE_INCOMING_HEADER_FOR_RESPONSE:
    push  xl
    push  xh

    /* IPv4 payload length */
    ldi   zl, lo8(SRAM_IPV4_HEADER)
    ldi   zh, hi8(SRAM_IPV4_HEADER)
    std   z + (IPV4_TOTAL_LENGTH + 0), zero
    std   z + (IPV4_TOTAL_LENGTH + 1), a1

    /* Swap SRC/DST IP Addresses */
    adiw  zl, IPV4_SRC_ADDR
    ldi   xl, lo8(SRAM_IPV4_HEADER + IPV4_DST_ADDR)
    ldi   xh, hi8(SRAM_IPV4_HEADER + IPV4_DST_ADDR)
    ldi   a1, IPV4_ADDR_LEN
    rcall MEMSWAP

    /* ipv4 checksum */
    /* Zero out checksum */
    sbiw  zl, (IPV4_SRC_ADDR + IPV4_ADDR_LEN - IPV4_H_CHECKSUM)
    st    z+, zero
    st    z+, zero
    sbiw  zl, (IPV4_H_CHECKSUM + 2) /* set z to IPv4 header */
    /* TODO: handle identification ? */
    lds   a1, SRAM_IPV4_IHL_IN_BYTES
    ldi   a2, 0
    rcall INTERNET_CHECKSUM_RFC1071
    std   z + IPV4_H_CHECKSUM + 0, a3
    std   z + IPV4_H_CHECKSUM + 1, a4

    pop   xh
    pop   xl
    ret

.end
