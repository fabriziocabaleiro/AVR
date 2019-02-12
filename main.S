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
#include "dht11.S"

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
.global INT1_vect

main:
    /* Set interrupt on INT0 falling edge */
    in    TMP1, _SFR_IO_ADDR(MCUCR)
    // TODO: Decide which one to use
    ori   TMP1, (1 << ISC01)
    andi  TMP1, ~((1 << ISC00)|(1 << ISC01))
    out   _SFR_IO_ADDR(MCUCR), TMP1

    in    TMP1, _SFR_IO_ADDR(GICR)
    ori   TMP1, (1 << INT0)
    out   _SFR_IO_ADDR(GICR), TMP1

    cbi   _SFR_IO_ADDR(DDRD), PD2

    /* Set global interrupt enable, sleep mode and sleep enable */
    in   TMP1, _SFR_IO_ADDR(MCUCR)
    sbr  TMP1, (1 << SE)
    out  _SFR_IO_ADDR(MCUCR), TMP1

    /* Set LED errors */
    ERR_ARP_SET_DDR

    ldi   MAIN_COUNTER_REG, 255
MAIN_DELAY:
    rcall DELAY_TMP
    dec MAIN_COUNTER_REG
    brne MAIN_DELAY

    rcall DHT11_SETUP
    rcall SPI_MASTER_INIT
    rcall ETH_SOFTWARE_RESET
    rcall ETH_BUFFER_INIT
    rcall ETH_MAC_INIT
    rcall ETH_MISC_INIT
    rcall ETH_ENABLE_RECEIVE
    rcall ETH_ENABLE_RECEIVE_INTERRUPT

    ldi DEBUG_REG_COUNT, 0
    sei

loop:
    sleep
    rjmp loop

MAIN_PACKET:
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
    brne  PROCESS_PACKET
    ret
PROCESS_PACKET:

    /* Next Read Pointer */
    rcall ETH_READ_RECEIVE_HEADER
    rcall ETH_CHECK_RECEIVE_STATUS_VECTOR
    cpi   RETURN_VALUE, 0
    brne  SKIP_ETH_PKT

    rcall ETH_READ_MAC_ADDRS_N_LEN_TYPE

    /* TYPE/LENGTH, values below 0x05DC are length, otherwise, type.
     * enc28j60 tells us if type or length */
    lds   TMP1, RPKT_STATUS2
    sbrc  TMP1, RPKT_STATUS2_LENGTH_OUT_OF_RANGE
    rjmp  TYPE_LEN_TYPE
    rjmp  TYPE_LEN_LENGTH

TYPE_LEN_LENGTH:
    rjmp  PACKET_END

TYPE_LEN_TYPE:
    lds   ZH, TYPE_LEN_H
    lds   ZL, TYPE_LEN_L
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
    rjmp  PACKET_END

TYPE_LEN_UNKNOWN:
    ERR_ETH_SET_ERROR
    rjmp PACKET_END

PACKET_END:
NO_ARP_PACKET:
SKIP_ETH_PKT:
    rcall ETH_PKT_PROCESSED

    inc   DEBUG_REG_COUNT
    cpi   DEBUG_REG_COUNT, 4
    brne  SKIP_MESSAGE
    rcall SEND_MESSAGE
    ldi   DEBUG_REG_COUNT, 0
SKIP_MESSAGE:
    ret //rjmp loop

ERROR:
    ERR_ETH_SET_ERROR
    rjmp  SKIP_ETH_PKT

/*******************************************************************************
 * Write message to PC
 ******************************************************************************/
SEND_MESSAGE:
    push ZL
    push ZH

    lds   TMP1, TYPE_LEN_H
    push  TMP1
    lds   TMP1, TYPE_LEN_L
    push  TMP1
    ldi   TMP1, hi8(MESSAGE_TYPE_LEN)
    sts   TYPE_LEN_H, TMP1
    ldi   TMP1, lo8(MESSAGE_TYPE_LEN)
    sts   TYPE_LEN_L, TMP1

    ldi   ZL, lo8(MESSAGE_PAYLOAD)
    ldi   ZH, hi8(MESSAGE_PAYLOAD)
    ldi   TMP1, 0xFF
    st    Z+, TMP1
    in    TMP1, _SFR_IO_ADDR(TCNT1H)
    st    Z+, TMP1
    in    TMP1, _SFR_IO_ADDR(TCNT1L)
    st    Z+, TMP1
    ldi   TMP1, 0xFF
    st    Z+, TMP1

    rcall ETH_WRITE_BUFFER_PACKET_HEADER
    ldi   ZL, lo8(MESSAGE_PAYLOAD)
    ldi   ZH, hi8(MESSAGE_PAYLOAD)
    ldi   ARG_REG1, 16
    rcall ETH_WRITE_BUFFER_PACKET_PAYLOAD

    rcall DHT11_READ
    ldi   ZL, lo8(DHT11_PAYLOAD)
    ldi   ZH, hi8(DHT11_PAYLOAD)
    ldi   ARG_REG1, 16 ; DHT11_PAYLOAD_LEN + 2
    rcall ETH_WRITE_BUFFER_PACKET_PAYLOAD

    rcall ETH_WRITE_BUFFER_PACKET_PAYLOAD_FINISH

    pop   TMP1
    sts   TYPE_LEN_H, TMP1
    pop   TMP1
    sts   TYPE_LEN_L, TMP1

    pop  ZH
    pop  ZL
    ret

INT0_vect:
    push  TMP1
    in    TMP1, _SFR_IO_ADDR(SREG)
    push  TMP1
    rcall MAIN_PACKET
    ldi   ARG_REG1, EIR
    ldi   ARG_REG2, EIR_PKTIF
    rcall ETH_BIT_FIELD_CLEAR
    pop   TMP1
    out   _SFR_IO_ADDR(SREG), TMP1
    pop   TMP1
    reti

