/* vim: set filetype=S foldmethod=marker: */
/* INCLUDES {{{1 */
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
#include "dht11.h"
#include "macros.S"
.LIST

/* GLOBAL {{{1 ---------------------------------------------------------------*/
.global main
.global INT0_vect
.global BIT_FIELD_1

/* DATA  {{{1 ----------------------------------------------------------------*/
.section .data
BIT_FIELD_1: .skip 1

/* TEXT {{{1 -----------------------------------------------------------------*/
.section .text

/* main, initialize everything {{{2 ------------------------------------------*/
main:
    /* Keep register with zero value to avoid using clr over and over */
    clr   zero

    /* Set LED errors */
    ERR_SET_DDR

    /* Set global interrupt enable, sleep mode and sleep enable
     * Interrupt on INT0: falling edge */
    in    t1, _SFR_IO_ADDR(MCUCR)
    sbr   t1, ((1 << SE)|(1 << ISC01))
    out   _SFR_IO_ADDR(MCUCR), t1

    /* Enable timer and have initial delay */
    rcall TIMER_INIT
    sei
    sleep

#ifdef USE_DHT11
    rcall DHT11_INIT
#endif
    rcall ARP_INIT
    rcall COMM_INIT
    rcall DHCP_INIT
    rcall SPI_MASTER_INIT
    rcall ETH_INIT
    DEBUG(rcall UART_INIT)

    DEBUG(PRINT_STR STR_START)

    /* Enable external interrupt 0 and 1 */
    in    t1, _SFR_IO_ADDR(GICR)
    sbr   t1, (1 << INT1)|(1 << INT0)
    out   _SFR_IO_ADDR(GICR), t1

/* LOOP {{{2 -----------------------------------------------------------------*/
LOOP:
    sbic  _SFR_IO_ADDR(PIND), PD2
    sleep
    sbis  _SFR_IO_ADDR(PIND), PD2
    rcall ENC_INTERRUPT_HANDLE
    /* Event triggered by timer {{{ */
    lds   t1, SRAM_TIMER1_EVENTS
    sbrs  t1, TIMER1_EVENTS_SECOND
    rjmp  LOOP
    cbr   t1, (1 << TIMER1_EVENTS_SECOND)
    sts   SRAM_TIMER1_EVENTS, t1

    rcall DHCP

    lds   t1, SRAM_TIMER1_EVENTS
    sbrs  t1, TIMER1_EVENTS_2S
    rjmp  LOOP
    cbr   t1, (1 << TIMER1_EVENTS_2S)
    sts   SRAM_TIMER1_EVENTS, t1

    /* Collect data */
    rcall DHT11_READ

    rcall ADC_ENABLE_N_START

    ldi   xh, hi8(SRAM_DHT11_PAYLOAD)
    ldi   xl, lo8(SRAM_DHT11_PAYLOAD)
    ldi   zl, lo8(SRAM_COMM_PAYLOAD)
    ldi   zh, hi8(SRAM_COMM_PAYLOAD)
    ldi   a1, DHT11_PAYLOAD_LEN
    rcall MEMCPY

    ldi   xh, hi8(SRAM_ADC0)
    ldi   xl, lo8(SRAM_ADC0)
    ldi   a1, MQ135_PAYLOAD_LEN
    cli   /* Avoid race condition with SRAM_ADC0 */
    rcall MEMCPY
    sei

    /* Send data */
    ldi   a1, (DHT11_PAYLOAD_LEN + MQ135_PAYLOAD_LEN)
    rcall SEND_PACKET
    /* }}} */
    rjmp  LOOP

/* INT0 handle. {{{2 ----------------------------------------------------------
 * Don't do anything within the routine, we want the system to wake up and
 * within LOOP to do everything */
INT0_vect:
    reti

/* ENC28J60 INTERRUPT HANDLE {{{2  ---------------------------------------------
 * ENC28J60 has multiple sources of interrupt, but only one output pin, this pin
 * will be held down until all sources of interrupts are cleared */
ENC_INTERRUPT_HANDLE:
    push  s1 /* Not really necessary as LOOP is not using s1 at all */
    /* Read Global interrupt register from ENC28J60 and execute routines
     * accordingly */
    ldi   a1, ENC_COMMON_EIR
    rcall ETH_READ_CONTROL_REGISTER
    mov   s1, a4

    /* First check for errors */
#if USE_DMAIF
    sbrc  s1, ENC_COMMON_EIE_DMAIE
    TODO
#endif
#if USE_LINKIF
    sbrc  s1, ENC_COMMON_EIE_LINKIE
    TODO
#endif
#if USE_TXIF
    sbrc  s1, ENC_COMMON_EIE_TXIE
    TODO
#endif
#if USE_TXERIF
    sbrc  s1, ENC_COMMON_EIE_TXERIE
    TODO
#endif
#if USE_RXERIF
    sbrc  s1, ENC_COMMON_EIE_RXERIE
    TODO
#endif
    /* The system would be useless if this is not in use */
    sbrc  s1, ENC_COMMON_EIR_PKTIF
    rcall HANDLE_PACKET

    pop   s1
    ret

/* Handle received packet {{{2 -------------------------------------------------
 * enc28j60 will trigger an interrupt whenever a packet is received. */
HANDLE_PACKET:
    /* Packet and Ethernet headers */
    /* TODO: merge ETH_READ_RECEIVE_HEADER and ETH_READ_MAC_ADDRS_N_LEN_TYPE */
    rcall ETH_READ_RECEIVE_HEADER
    rcall ETH_CHECK_RECEIVE_STATUS_VECTOR
    cpi   a4, 0
    /* Error seen commonly after programming */
    brne  RESET_ETH

    rcall ETH_READ_MAC_ADDRS_N_LEN_TYPE

    lds   t2, SRAM_RPKT_STATUS3
    sbrs  t2, RPKT_STATUS3_RECEIVE_BROADCAST_PACKET
    rjmp  CHK_RPKT_STATUS2

    /* Check if broadcast was sent by me */
    ldi   xh, hi8(EEPROM_MAC_ADDR)
    ldi   xl, lo8(EEPROM_MAC_ADDR)
    ldi   zh, hi8(SRAM_ENC_SRC_ADDR)
    ldi   zl, lo8(SRAM_ENC_SRC_ADDR)
    ldi   a1, MAC_ADDR_LEN
    rcall ES_MEMCMP
    brne  CHK_RPKT_STATUS2
    rjmp  SKIP_ETH_PKT

CHK_RPKT_STATUS2:
    lds   t2, SRAM_RPKT_STATUS2
    sbrc  t2, RPKT_STATUS2_LENGTH_OUT_OF_RANGE
    rjmp  TYPE_LEN_TYPE
    rjmp  SKIP_ETH_PKT /* no support for type/length = length packets */

TYPE_LEN_TYPE: /* Call handler based on TYPE */
    lds   t1, SRAM_TYPE_LEN_H
    lds   t2, SRAM_TYPE_LEN_L
TYPE_LEN_IPV4:
    /* Check Type/Len is IPv4 or jump to next type/len */
    cpi   t1, hi8(ETHER_TYPE_IPV4)
    brne  TYPE_LEN_ARP
    cpi   t2, lo8(ETHER_TYPE_IPV4)
    brne  TYPE_LEN_ARP

    rcall IPV4_HANDLE_PKT
    rjmp  PACKET_END

TYPE_LEN_ARP:
    /* Check Type/Len is ARP or jump to next type/len */
    cpi   t1, hi8(ETHER_TYPE_ARP)
    brne  TYPE_LEN_UNKNOWN
    cpi   t2, lo8(ETHER_TYPE_ARP)
    brne  TYPE_LEN_UNKNOWN

    rcall ARP_HANDLE_PKT

TYPE_LEN_UNKNOWN:
PACKET_END:
SKIP_ETH_PKT:
    rcall ETH_PKT_PROCESSED
    ret

RESET_ETH:
    DEBUG(PRINT_STR STR_ENC_STATUS_VECTOR_ERROR)
    DEBUG(PRINT_REG a4)
    DEBUG(PRINT_NEWLINE)
    rcall ETH_INIT
    ret

.end
