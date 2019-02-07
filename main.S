; vim: set filetype=S:
.NOLIST
#ifndef __AVR_ATmega8__
#define __AVR_ATmega8__
#include <unistd.h>
#endif
#include <avr/io.h>
#include <avr/interrupt.h>
.LIST

#include "defs.h"
#include "spi.S"
#include "enc28j60.S"
#include "arp.S"
#include "ipv4.S"

#if 0 /* Testing */
.section .data
.global MAC_ADDRESS

MAC_ADDRESS:
.byte 0xFAB312100000 // "fabrizio" //0x00, 0xB3, 0x12, 0x10, 0x00, 0x00

//.global __do_copy_data
//.global __do_clear_bss
#endif

.section .text // Don't know if necessary
.global main
.global INT0_vect

/* Run once with #define WRITE_MAC_IN_EEPROM to write the eeprom, save it's
 * content and then remove the definition, then after writing the flash, write
 * the eeprom content with the saved file.
 */

main:
    /* Set interrupt on INT0 falling edge */
#if 0 // Not using interrupt at the moment
    in   TMP1, _SFR_IO_ADDR(MCUCR)
    ori  TMP1, (1 << ISC01)
    andi TMP1, ~(1 << ISC00)
    out  _SFR_IO_ADDR(MCUCR), TMP1

    in   TMP1, _SFR_IO_ADDR(GICR)
    ori  TMP1, (1 << INT0)
    out  _SFR_IO_ADDR(GICR), TMP1
#endif

    cbi  _SFR_IO_ADDR(DDRD), PD2

    /* Set global interrupt enable, sleep mode and sleep enable */
    in   TMP1, _SFR_IO_ADDR(MCUCR)
    ori  TMP1, (1 << SE) | (1 << SM0)
    andi TMP1, ~((1 << SM2) | (1 << SM1))
    out  _SFR_IO_ADDR(MCUCR), TMP1
    sei

    /* Set LED errors */
    ERR_ARP_SET_DDR

    rcall DELAY_TMP
    rcall SPI_MASTER_INIT
    rcall ETH_SOFTWARE_RESET
    rcall ETH_BUFFER_INIT
    rcall ETH_MAC_INIT
    rcall ETH_MISC_INIT
    rcall ETH_ENABLE_RECEIVE
    //rcall ETH_ENABLE_RECEIVE_INTERRUPT

loop:
    ERR_ARP_CLR_ERROR

    /* select bank */
    ldi   ARG_REG1, ECON1
    ldi   ARG_REG2, ECON1_BSEL0
    rcall ETH_BIT_FIELD_SET
    ldi   ARG_REG1, ECON1
    ldi   ARG_REG2, ECON1_BSEL1
    rcall ETH_BIT_FIELD_CLEAR
    ldi   ARG_REG1, EPKTCNT
    rcall ETH_READ_CONTROL_REGISTER
    sts   RPKT_PENDING_CNT, RETURN_VALUE

    /* Start loop again if not pending packet */
    tst   RETURN_VALUE
    breq  loop

    /* Next Read Pointer */
    rcall ETH_READ_RECEIVE_HEADER
    rcall ETH_CHECK_RECEIVE_STATUS_VECTOR
    cpi   RETURN_VALUE, 0
    brne  SKIP_ETH_PKT

    rcall ETH_READ_MAC_ADDRS_N_LEN_TYPE

    /* TYPE/LENGTH, values below 0x05DC are length, otherwise, type. */
    lds   ZH, TYPE_LEN_H
    lds   ZL, TYPE_LEN_L
    cpi   ZH, hi8(ETHER_TYPE_LEN + 0x0100) /* plus one, so we can do brge */
    brge  TYPE_LEN_IPV4 /* TypeLen greater or equal to 0x0600 */
    cpi   ZH, hi8(ETHER_TYPE_LEN)
    brne  TYPE_LEN_LENGTH /* if not equal, then less than 0x0600 */
    cpi   ZL, lo8(ETHER_TYPE_LEN + 1) /* plus one to do brge */
    brge  TYPE_LEN_IPV4 /* 0x05DD+ */

TYPE_LEN_LENGTH:
    rjmp  PACKET_END

TYPE_LEN_IPV4:
    /* Check Type/Len is IPv4 or jump to next type/len */
    cpi   ZH, hi8(ETHER_TYPE_IPV4)
    brne  TYPE_LEN_ARP
    cpi   ZL, lo8(ETHER_TYPE_IPV4)
    brne  TYPE_LEN_ARP

    rcall IPV4_READ_HEADER
    rcall IPV4_RESPONSE_IF_PING
    cpi   RETURN_VALUE, 0
    brne  ERROR
    rjmp  PACKET_END

TYPE_LEN_ARP:
    /* Check Type/Len is ARP or jump to next type/len */
    cpi   ZH, hi8(ETHER_TYPE_ARP)
    brne  TYPE_LEN_UNKNOWN
    cpi   ZL, lo8(ETHER_TYPE_ARP)
    brne  TYPE_LEN_UNKNOWN

    // sbrc  TMP1, STATUS2_LENGTH_OUT_OF_RANGE
    rcall ARP_PROCESS
    cpi   RETURN_VALUE, 0
    brne  NO_ARP_PACKET
    /* Write ARP Reply */
    rcall ETH_WRITE_BUFFER_PACKET_HEADER
    ldi   ZH, 0
    ldi   ZL, ARP_PAYLOAD
    ldi   ARG_REG1, 28
    rcall ETH_WRITE_BUFFER_PACKET_PAYLOAD
    rcall ETH_WRITE_BUFFER_PACKET_PAYLOAD_FINISH
    ERR_ETH_SET_ERROR
    rjmp  PACKET_END

TYPE_LEN_UNKNOWN:
    ERR_ETH_SET_ERROR
    rjmp PACKET_END

PACKET_END:
NO_ARP_PACKET:
SKIP_ETH_PKT:
    rcall ETH_PKT_PROCESSED
#if 0
    /* DEBUGGING */
    ldi   TMP1, DEBUG_OPT_RECEIVE_BUFFER
    sts   DEBUG_OPT, TMP1
    rcall ETH_SEND_DEBUG
#endif
    rjmp loop

ERROR:
    ERR_ETH_SET_ERROR
    rjmp  SKIP_ETH_PKT


INT0_vect:
#if 0
    cli
    push INT_TMP_REG0
    in   INT_TMP_REG0, _SFR_IO_ADDR(SREG)
    out  _SFR_IO_ADDR(SREG), INT_TMP_REG0
    pop  INT_TMP_REG0
    sei
#endif
    reti

