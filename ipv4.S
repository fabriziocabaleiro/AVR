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
.global SRAM_IPV4_DST_IP_ADDR

/* DATA  {{{1 ----------------------------------------------------------------*/
.section .data
SRAM_IPV4_DATA:
/* Internet Header Length in bytes */
SRAM_IPV4_IHL_IN_BYTES:            .skip  1
/* Internet Payload Length in bytes */
SRAM_IPV4_PAYLOAD_LENGTH_IN_BYTES: .skip  2
/* Destination IP Address, when sending an IP packet, caller routine should set
 * the DST IP address here */
SRAM_IPV4_DST_IP_ADDR:             .skip  IPV4_ADDR_LEN
/* TODO: Review this flags */
SRAM_IPV4_G_FLAGS:                 .skip  1
SRAM_IPV4_HEADER:                  .skip  IPV4_MAX_HEADER_LEN
/* TODO: change SRAM_IPV4_PAYLOAD to be a generic memory area, ARP could also
 * use this memory space */
SRAM_IPV4_PAYLOAD:                 .skip  IPV4_PAYLOAD_LEN

/* TEXT {{{1 -----------------------------------------------------------------*/
.section .text

/* Handle IPv4 packet {{{2 -----------------------------------------------------
 * Check protocol (tcp, udp, etc) and port to deliver to corresponding routine
 * IP version != 4 will be ignore */
IPV4_HANDLE_PKT:
    push  yl
    push  yh
    push  s1 /* IPv4 broadcast and unicast to me flags */

    /* Set Y to beginning of IPv4 data to use ldd/std */
    ldi   yl, lo8(SRAM_IPV4_DATA)
    ldi   yh, hi8(SRAM_IPV4_DATA)

    /* Set Ethernet Type/Len to IPv4 */
    ldi   t2, (EEPROM_TYPE_LEN_IPV4 - EEPROM_TYPE_LEN)
    sts   SRAM_ENC_TYPE_LEN_OFFSET, t2

    /* Read IPv4 Header */
    ldi   zl, lo8(SRAM_IPV4_HEADER)
    ldi   zh, hi8(SRAM_IPV4_HEADER)
    rcall ETH_READ_BUFFER_START

    /* Read the first byte, which contains the version and the header length,
     * assign counter with the length and check that version is 4, if not,
     * return 1 and exit */
    ETH_READ_NEXT_BYTE
    st    z+, a4
    mov   a1, a4
    /* Check if IPv4 */
    andi  a4, 0xF0
    cpi   a4, 0x40
    /* Only IPv4 will be handle, other versions will be ignore */
    brne  9f /* end of routine */

    andi  a1, 0x0F
    /* Length is in 32bits words, as reading bytes, then IHL * 4, then subtract
     * one as the first bytes was already read */
    lsl   a1
    lsl   a1
    /* Store the Internet Header Length in bytes */
    std   y + IPV4_DO_IHL_IN_BYTES, a1
    /* We already read one byte (version|IHL), so, subtract 1 */
    subi  a1, 1
    /* Read the rest of the IPv4 header */
    rcall S_MEMCPY

    ETH_READ_BUFFER_END

    /* Check if Dst IP Address is ours */
    clr   s1
    ldi   xh, hi8(EEPROM_IP_ADDR)
    ldi   xl, lo8(EEPROM_IP_ADDR)
    ldi   zl, lo8(SRAM_IPV4_HEADER + IPV4_DST_ADDR)
    ldi   zh, hi8(SRAM_IPV4_HEADER + IPV4_DST_ADDR)
    ldi   a1, IPV4_ADDR_LEN
    rcall E_MEMCMP
    brne  0f
    sbr   s1, (1 << RECEIVED_IP_IS_MINE_BIT)

    /* Check if Dst IP Address is broadcast */
0:  movw  xl, zl
    ldi   a2, 0xFF
    rcall R_MEMCMP
    brne  0f
    sbr   s1, (1 << RECEIVED_IP_IS_BROADCAST_BIT)

0:  std   y + IPV4_DO_G_FLAGS, s1

    /* Get and store IPv4 Payload length in bytes */
    ldd   t2, y + (IPV4_DO_TOTAL_LENGTH + 0)
    ldd   t1, y + (IPV4_DO_TOTAL_LENGTH + 1)
    ldd   t3, y + IPV4_DO_IHL_IN_BYTES
    /* total length - header => [t2:t1] - t3 */
    sub   t1, t3
    sbc   t2, zero
    std   y + IPV4_DO_PAYLOAD_LENGTH_IN_BYTES + 0, t2
    std   y + IPV4_DO_PAYLOAD_LENGTH_IN_BYTES + 1, t1

    /* Deliver packet using IPv4 protocol */
    ldd   t1, y + IPV4_DO_PROTOCOL

    /* UDP */
    /* We may receive a DHCP packet that doesn't have our current IP address,
     * therefore we don't check if Dst IP Addr is ours */
    cpi   t1, INTERNET_PROTOCOL_NUMBER_USER_DATAGRAM
    brne  0f
    rcall UDP_HANDLE_PKT
    rjmp  9f

    /* Check Dst IP Address is ours, if not, return */
0:  sbrs  s1, RECEIVED_IP_IS_MINE_BIT
    rjmp  9f

    /* ICMP */
    cpi   t1, INTERNET_PROTOCOL_NUMBER_ICMP
    brne  0f
    rcall ICMP_HANDLE_PKT
    rjmp  9f

    /* TCP */
0:  cpi   t1, INTERNET_PROTOCOL_NUMBER_TCP
    brne  9f
    rcall TCP_HANDLE_PKT

9:  pop   s1
    pop   yh
    pop   yl
    ret

/* Internet Checksum RFC 1071 {{{2 ---------------------------------------------
 * Byte order independent
 *
 * Z and a1 must not be modified.
 *
 * Input:
 *   zh:zl Address to start reading from
 *   a1    Bytes to read.
 *   a2 != 0, then include Pseudo header and a2 <= Protocol
 *
 * Return value (checksum) in [a3:a4] */
INTERNET_CHECKSUM_RFC1071:
    push  zl
    push  zh

    /* Clear a3, a4 and Carry */
    clr   a3
    sub   a4, a4 /* equal to clr a4; clc */

    /* add with carry to a3 all bytes in even locations, i.e. 0, 2, 4...
     * add with carry to a4 all bytes in odd locations, i.e. 1, 3, 5...
     * Clear carry before starting the accumulative addition */
    mov   t3, a1
1:  clr   t2 /* LSB used to switch between even/odd -> adc to a3/a4 */
0:  ld    t1, z+
    sbrs  t2, 0
    adc   a3, t1
    sbrc  t2, 0
    adc   a4, t1
    inc   t2
    dec   t3 /* Byte counter */
    brne  0b

    tst   a2
    breq  0f /* Skip Pseudo header checksum calculation */

    /* if a1 is even, then adc zero */
    sbrs  a1, 0
    adc   a3, zero

    /* Add protocol and length */
    adc   a4, a2
    adc   a3, zero
    adc   a4, a1

    clr   a2
    ldi   zl, lo8(SRAM_IPV4_HEADER + IPV4_SRC_ADDR)
    ldi   zh, hi8(SRAM_IPV4_HEADER + IPV4_SRC_ADDR)
    ldi   t3, IPV4_ADDR_LEN * 2
    rjmp  1b

    /* If the last addition generated a Carry, then add zero with carry, which
     * could also generate a Carry into a3, so, add zero with carry as
     * well */
0:  adc   a3, zero
    adc   a4, zero

    com   a4
    com   a3

    pop   zh
    pop   zl
    ret

/* Prepare IPv4 header {{{2 ----------------------------------------------------
 * a2: total size
 * By using a2 instead of a1 we avoid the need of saving the value of the input
 * register till the point that is used */
IPV4_PREPARE_DEFAULT_HEADER_20_40_BYTES:
    /* Get default header from EEPROM (don't include src/dst ip addresses */
    ldi   xl, lo8(EEPROM_IP_HEADER)
    ldi   xh, hi8(EEPROM_IP_HEADER)
    ldi   zl, lo8(SRAM_IPV4_HEADER)
    ldi   zh, hi8(SRAM_IPV4_HEADER)
    ldi   a1, (EEPROM_IP_HEADER_TIL_SRC_IP_ADDR - EEPROM_IP_HEADER)
    rcall E_MEMCPY

    /* SRC IP Address */
    ldi   xl, lo8(EEPROM_IP_ADDR)
    ldi   xh, hi8(EEPROM_IP_ADDR)
    ldi   a1, IPV4_ADDR_LEN
    rcall E_MEMCPY

    /* DST IP Address */
    ldi   xl, lo8(SRAM_IPV4_DST_IP_ADDR)
    ldi   xh, hi8(SRAM_IPV4_DST_IP_ADDR)
    ldi   a1, IPV4_ADDR_LEN
    rcall MEMCPY

    /* Update Total length and calculate Checksum */
    sbiw  zl, IPV4_DEFAULT_HEADER_LEN
    std   z + (IPV4_TOTAL_LENGTH + 1), a2

    /* Calculate and set checksum */
    ldi   a1, IPV4_DEFAULT_HEADER_LEN
    ldi   a2, 0
    rcall INTERNET_CHECKSUM_RFC1071
    std   z + (IPV4_H_CHECKSUM + 0), a3
    std   z + (IPV4_H_CHECKSUM + 1), a4

    ret

/* Using incoming IPv4 header for outgoing IPv4 header {{{2 --------------------
   a1: IPv4 Total Length in bytes
   y must be set to SRAM_IPV4_DATA by calling routine
   z will be left pointing to SRAM_IPV4_HEADER
   */
IPV4_PREPARE_INCOMING_HEADER_FOR_RESPONSE:
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
    std   y + IPV4_DO_H_CHECKSUM + 0, zero
    std   y + IPV4_DO_H_CHECKSUM + 1, zero
    /* TODO: handle identification ? */
    sbiw  zl, IPV4_DST_ADDR /* set z to IPv4 header */
    ldd   a1, y + IPV4_DO_IHL_IN_BYTES
    ldi   a2, 0
    rcall INTERNET_CHECKSUM_RFC1071
    std   z + IPV4_H_CHECKSUM + 0, a3
    std   z + IPV4_H_CHECKSUM + 1, a4

    ret

.end
