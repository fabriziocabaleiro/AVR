/* vim: set filetype=S foldmethod=marker: */
.NOLIST
#ifndef __AVR_ATmega8__
#   define __AVR_ATmega8__
#endif
#include <avr/io.h>
#include <avr/interrupt.h>
#include "defs.h"
#include "enc28j60.h"
#include "timer.h"
#include "eeprom_data.h"
.LIST

.global main
.global INT0_vect
//.global INT1_vect
.global TIMER0_OVF_vect

.global BIT_FIELD_1

.section .data
BIT_FIELD_1: .skip 1

.section .text

/*******************************************************************************
 * main, initialize everything {{{
 ******************************************************************************/
main:
    /* Interrupt on INT0: low level, which is the default
     * ISC00 = ISC01 = 0
     */

    /* Set LED errors */
    ERR_SET_DDR
    DDR_LED0
    DDR_LED1
    CLR_LED0
    CLR_LED1

    /* Zero out SRAM */
    rcall ZERO_OUT_SRAM

    /* Set global interrupt enable, sleep mode and sleep enable */
    in    TMP_REG1, _SFR_IO_ADDR(MCUCR)
    sbr   TMP_REG1, (1 << SE)
    out   _SFR_IO_ADDR(MCUCR), TMP_REG1

    /* INT1 will receive interrupt while reading DHT11, but, also will receive
     * interrupt if we want to generate a COREDUMP, so, using upper nibble of
     * port D to know what to do when INT1 triggered */
    cbi   _SFR_IO_ADDR(DDRD), PD4

    /* Enable timer and have initial delay */
    rcall TIMER_INIT
    sei
    sleep

#ifdef USE_DHT11
    rcall DHT11_SETUP
#endif
    rcall ARP_INIT
    rcall COMM_INIT
    rcall DHCP_INIT
    rcall SPI_MASTER_INIT
    rcall ETH_INIT

    /* Enable external interrupt 0 and 1 */
    in    TMP_REG1, _SFR_IO_ADDR(GICR)
    sbr   TMP_REG1, (1 << INT1)|(1 << INT0)
    out   _SFR_IO_ADDR(GICR), TMP_REG1
/* }}} */
/*******************************************************************************
 * LOOP {{{
 ******************************************************************************/
LOOP:
    /* Enable INT0, {{{ */
    in    TMP_REG1, _SFR_IO_ADDR(GICR)
    sbr   TMP_REG1, (1 << INT0)
    out   _SFR_IO_ADDR(GICR), TMP_REG1
    /* }}} */
    /* Enable timer interrupt {{{ */
    in    TMP_REG1, _SFR_IO_ADDR(TIMSK)
    sbr   TMP_REG1, (1 << OCIE1A)
    out   _SFR_IO_ADDR(TIMSK), TMP_REG1
    /* }}} */
    sleep
    CLR_LED0
    CLR_LED1
    /* Disable INT0, because can interfere with code using ENC28J60 {{{ */
    in    TMP_REG1, _SFR_IO_ADDR(GICR)
    cbr   TMP_REG1, (1 << INT0)
    out   _SFR_IO_ADDR(GICR), TMP_REG1
    /* }}} */
    /* Disable Timer interrupt {{{ */
    in    TMP_REG1, _SFR_IO_ADDR(TIMSK)
    cbr   TMP_REG1, (1 << OCIE1A)
    out   _SFR_IO_ADDR(TIMSK), TMP_REG1
    /* }}} */
    lds   TMP_REG1, SRAM_TIMER1_EVENTS
    sbrs  TMP_REG1, TIMER1_EVENTS_SECOND
    rjmp  LOOP
    cbr   TMP_REG1, (1 << TIMER1_EVENTS_SECOND)
    sts   SRAM_TIMER1_EVENTS, TMP_REG1

    rcall DHCP

    lds   TMP_REG1, SRAM_TIMER1_EVENTS
    sbrs  TMP_REG1, TIMER1_EVENTS_2S
    rjmp  LOOP
    cbr   TMP_REG1, (1 << TIMER1_EVENTS_2S)
    sts   SRAM_TIMER1_EVENTS, TMP_REG1

    rcall SEND_PACKET

    rjmp  LOOP
/* }}} */
/*******************************************************************************
 * INT0 handle. Received packet interrupt routine {{{
 * Within INT0 handle, INT0 is disable, interrupts are re-enabled
 ******************************************************************************/
INT0_vect:
    push  TMP_REG1
    in    TMP_REG1, _SFR_IO_ADDR(SREG)
    push  TMP_REG1

    /* Disable INT0 */
    in    TMP_REG1, _SFR_IO_ADDR(GICR)
    cbr   TMP_REG1, (1 << INT0)
    out   _SFR_IO_ADDR(GICR), TMP_REG1

    /* Re-enable interrupt within interrupt */
    sei

    /* Read Global interrupt register from ENC28J60 and execute routines
     * accordingly */
READ_ETHERNET_INTERRUPT_REQUEST:
    ldi   ARG_REG1, ENC_COMMON_EIR
    rcall ETH_READ_CONTROL_REGISTER
    mov   ETH_INT_RQST, RETURN_VALUE

    sbrc  ETH_INT_RQST, ENC_COMMON_EIR_PKTIF
    rcall HANDLE_PACKET
    sbrc  ETH_INT_RQST, ENC_COMMON_EIE_DMAIE
    rcall COREDUMP_N_CONTINUE
    sbrc  ETH_INT_RQST, ENC_COMMON_EIE_LINKIE
    rcall COREDUMP_N_CONTINUE
    sbrc  ETH_INT_RQST, ENC_COMMON_EIE_TXIE
    rcall COREDUMP_N_CONTINUE
    sbrc  ETH_INT_RQST, ENC_COMMON_EIE_TXERIE
    rcall COREDUMP_N_CONTINUE
    sbrc  ETH_INT_RQST, ENC_COMMON_EIE_RXERIE
    rcall HANDLE_RECEIVE_ERROR

    /* Check if still pending interrupts */
    sbis  _SFR_IO_ADDR(PIND), PD2
    rjmp  READ_ETHERNET_INTERRUPT_REQUEST

#if 1
    in    TMP_REG2, _SFR_IO_ADDR(GIFR)
    sbr   TMP_REG2, (1 << INTF0)
    out   _SFR_IO_ADDR(GIFR), TMP_REG2
#endif

    /* Enable INT0 */
    in    TMP_REG1, _SFR_IO_ADDR(GICR)
    sbr   TMP_REG1, (1 << INT0)
    out   _SFR_IO_ADDR(GICR), TMP_REG1

    pop   TMP_REG1
    out   _SFR_IO_ADDR(SREG), TMP_REG1
    pop   TMP_REG1
    reti
/* }}} */
/*******************************************************************************
 * Handle received packet {{{
 * enc28j60 will trigger an interrupt whenever a packet is received.
 ******************************************************************************/
HANDLE_PACKET:
    /* Packet and Ethernet headers {{{ */
    rcall ETH_READ_RECEIVE_HEADER
    rcall ETH_CHECK_RECEIVE_STATUS_VECTOR
    cpi   RETURN_VALUE, 0
    /* TODO: improve action upon this error */
    brne  RESET_ETH

    rcall ETH_READ_MAC_ADDRS_N_LEN_TYPE

    lds   TMP_REG2, SRAM_RPKT_STATUS3
    sbrs  TMP_REG2, RPKT_STATUS3_RECEIVE_BROADCAST_PACKET
    rjmp  CHK_RPKT_STATUS2
    /* Check if broadcast was sent by me {{{ */
    ldi   YH, hi8(EEPROM_MAC_ADDR)
    ldi   YL, lo8(EEPROM_MAC_ADDR)
    ldi   ZH, hi8(SRAM_MAC_ADDR_OTHER)
    ldi   ZL, lo8(SRAM_MAC_ADDR_OTHER)
    ldi   TMP_REG1, MAC_ADDR_LEN
CHECK_BROADCAST_MAC_ADDR:
    rcall EEPROM_READ_N_INC
    ld    TMP_REG2, Z+
    cp    TMP_REG2, RETURN_VALUE
    brne  CHK_RPKT_STATUS2
    dec   TMP_REG1
    brne  CHECK_BROADCAST_MAC_ADDR
    /* Src MAC addr from broadcast is mine, skip packet */
    rjmp  SKIP_ETH_PKT /* }}} */

CHK_RPKT_STATUS2:
    lds   TMP_REG2, SRAM_RPKT_STATUS2
    sbrc  TMP_REG2, RPKT_STATUS2_LENGTH_OUT_OF_RANGE
    rjmp  TYPE_LEN_TYPE
    rjmp  SKIP_ETH_PKT /* no support for type/length = length packets */
    /* }}} */
TYPE_LEN_TYPE: /* {{{ */
    lds   ZH, SRAM_TYPE_LEN_H
    lds   ZL, SRAM_TYPE_LEN_L
TYPE_LEN_IPV4: /* {{{ */
    /* Check Type/Len is IPv4 or jump to next type/len */
    cpi   ZH, hi8(ETHER_TYPE_IPV4)
    brne  TYPE_LEN_ARP
    cpi   ZL, lo8(ETHER_TYPE_IPV4)
    brne  TYPE_LEN_ARP

    rcall IPV4_HANDLE_PKT
    cpi   RETURN_VALUE, 0
    brne  ERROR
    rjmp  PACKET_END
    /* }}} */
TYPE_LEN_ARP: /* {{{ */
    /* Check Type/Len is ARP or jump to next type/len */
    cpi   ZH, hi8(ETHER_TYPE_ARP)
    brne  TYPE_LEN_UNKNOWN
    cpi   ZL, lo8(ETHER_TYPE_ARP)
    brne  TYPE_LEN_UNKNOWN

    rcall ARP_HANDLE_PKT
    rjmp  PACKET_END
    /* }}} */
TYPE_LEN_UNKNOWN: /* }}} */
PACKET_END:
SKIP_ETH_PKT:
    rcall ETH_PKT_PROCESSED
#if 0 // {{{
    // IF THIS BLOCK IS COMMENT, THEN PING DOESN'T WORK, REPLY HAS RUBBISH AT
    // THE END 
    rjmp  SKIP_MESSAGE
#ifdef USE_DHT11
    //rcall DHT11_READ
#endif
    //rcall SEND_PACKET
    //rcall DHCP_DISCOVER
SKIP_MESSAGE:
#endif // }}} 
    ret

ERROR:
    rjmp  SKIP_ETH_PKT
RESET_ETH:
    rcall ETH_INIT
    ret
/* }}} */
/*******************************************************************************
 * INT1 handle {{{
 ******************************************************************************/
#if 0
INT1_vect:
    /* Save and restore TMP_REG1 for EEPROM_COREDUMP */
    sts   SRAM_EEPROM_TMP_REG1_SAVE, TMP_REG1
    push  TMP_REG1
    in    TMP_REG1, _SFR_IO_ADDR(SREG)
    sts   SRAM_EEPROM_SREG, TMP_REG1
    push  TMP_REG1
    lds   TMP_REG1, SRAM_EEPROM_TMP_REG1_SAVE

/* TODO: Fix connections in breadboard */
//    /* Deliver interrupt to corresponding routine */
//    sbic  _SFR_IO_ADDR(PIND), PD4
//    rjmp  COREDUMP
//
//    sbic  _SFR_IO_ADDR(PIND), PD5
//    rjmp  SEND_DHCP_DISCOVER

#ifdef USE_DHT11
    //lds   TMP_REG1, BIT_FIELD_1
    //sbrc  TMP_REG1, BIT_FIELD_1_INT1_DHT11
    rcall DHT11_INT1_vect
#endif
INT1_vect_EXIT:
    pop   TMP_REG1
    out   _SFR_IO_ADDR(SREG), TMP_REG1
    pop   TMP_REG1
    reti

COREDUMP:
    rcall EEPROM_COREDUMP
    //ERR_SET
    rjmp  INT1_vect_EXIT

SEND_DHCP_DISCOVER:
    rcall DHCP
    rjmp  INT1_vect_EXIT
#endif
/* }}} */
/*******************************************************************************
 * Testing at the moment other interrupts {{{
 ******************************************************************************/
COREDUMP_N_CONTINUE:
    //rcall EEPROM_COREDUMP
    ERR_SET
    ret
/* }}} */
/*******************************************************************************
 * Error handling {{{
 ******************************************************************************/
HANDLE_RECEIVE_ERROR:
    //ERR_SET
    ldi   ARG_REG1, ENC_COMMON_EIR
    ldi   ARG_REG2, (1 << ENC_COMMON_EIR_RXERIF)
    rcall ETH_BIT_FIELD_CLEAR
    ret
/* }}} */
/*******************************************************************************
 * Error handling {{{
 ******************************************************************************/
TIMER0_OVF_vect:
   reti
 /* }}} */
/*******************************************************************************
 * Zero out SRAM {{{
 ******************************************************************************/
ZERO_OUT_SRAM:
    ldi   ZL, lo8(RAMSTART)
    ldi   ZH, hi8(RAMSTART)
    clr   TMP_REG1
ZERO_OUT_SRAM_LOOP:
    st    Z+, TMP_REG1
    cpi   ZL, lo8(RAMEND - 2)
    brne  ZERO_OUT_SRAM_LOOP
    cpi   ZH, hi8(RAMEND - 2)
    brne  ZERO_OUT_SRAM_LOOP
    ret
 /* }}} */

.end
