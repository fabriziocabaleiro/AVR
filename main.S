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
    clr   ZERO_REG

    /* Set LED errors */
    ERR_SET_DDR

    /* Set global interrupt enable, sleep mode and sleep enable
     * Interrupt on INT0: falling edge */
    in    TMP_REG1, _SFR_IO_ADDR(MCUCR)
    sbr   TMP_REG1, ((1 << SE)|(1 << ISC01))
    out   _SFR_IO_ADDR(MCUCR), TMP_REG1

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
    in    TMP_REG1, _SFR_IO_ADDR(GICR)
    sbr   TMP_REG1, (1 << INT1)|(1 << INT0)
    out   _SFR_IO_ADDR(GICR), TMP_REG1

/* LOOP {{{2 -----------------------------------------------------------------*/
LOOP:
    sbic  _SFR_IO_ADDR(PIND), PD2
    sleep
    sbis  _SFR_IO_ADDR(PIND), PD2
    rcall ENC_INTERRUPT_HANDLE
    /* Event triggered by timer {{{ */
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

    /* Collect data */
    rcall DHT11_READ

    rcall ADC_ENABLE_N_START
    sleep
    rcall ADC_DISABLE

    ldi   YH, hi8(SRAM_DHT11_PAYLOAD)
    ldi   YL, lo8(SRAM_DHT11_PAYLOAD)
    ldi   ZL, lo8(SRAM_COMM_PAYLOAD)
    ldi   ZH, hi8(SRAM_COMM_PAYLOAD)
    ldi   ARG_REG1, DHT11_PAYLOAD_LEN
    rcall MEMCPY

    ldi   YH, hi8(SRAM_MQ135_PAYLOAD)
    ldi   YL, lo8(SRAM_MQ135_PAYLOAD)
    ldi   ARG_REG1, MQ135_PAYLOAD_LEN
    rcall MEMCPY

    /* Send data */
    ldi   ARG_REG1, (DHT11_PAYLOAD_LEN + MQ135_PAYLOAD_LEN)
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
    /* Read Global interrupt register from ENC28J60 and execute routines
     * accordingly */
    ldi   ARG_REG1, ENC_COMMON_EIR
    rcall ETH_READ_CONTROL_REGISTER
    mov   ENC_INT_RQST_REG, RTV_L_REG

    /* First check for errors */
#if USE_DMAIF
    sbrc  ENC_INT_RQST_REG, ENC_COMMON_EIE_DMAIE
    TODO
#endif
#if USE_LINKIF
    sbrc  ENC_INT_RQST_REG, ENC_COMMON_EIE_LINKIE
    TODO
#endif
#if USE_TXIF
    sbrc  ENC_INT_RQST_REG, ENC_COMMON_EIE_TXIE
    TODO
#endif
#if USE_TXERIF
    sbrc  ENC_INT_RQST_REG, ENC_COMMON_EIE_TXERIE
    TODO
#endif
#if USE_RXERIF
    sbrc  ENC_INT_RQST_REG, ENC_COMMON_EIE_RXERIE
    TODO
#endif
    /* The system would be useless if this is not in use */
    sbrc  ENC_INT_RQST_REG, ENC_COMMON_EIR_PKTIF
    rcall HANDLE_PACKET

    ret

/* Handle received packet {{{2 -------------------------------------------------
 * enc28j60 will trigger an interrupt whenever a packet is received. */
HANDLE_PACKET:
    /* Packet and Ethernet headers */
    /* TODO: merge ETH_READ_RECEIVE_HEADER and ETH_READ_MAC_ADDRS_N_LEN_TYPE */
    rcall ETH_READ_RECEIVE_HEADER
    rcall ETH_CHECK_RECEIVE_STATUS_VECTOR
    cpi   RTV_L_REG, 0
    /* Error seen commonly after programming */
    brne  RESET_ETH

    rcall ETH_READ_MAC_ADDRS_N_LEN_TYPE

    lds   TMP_REG2, SRAM_RPKT_STATUS3
    sbrs  TMP_REG2, RPKT_STATUS3_RECEIVE_BROADCAST_PACKET
    rjmp  CHK_RPKT_STATUS2

    /* Check if broadcast was sent by me */
    ldi   YH, hi8(EEPROM_MAC_ADDR)
    ldi   YL, lo8(EEPROM_MAC_ADDR)
    ldi   ZH, hi8(SRAM_ENC_SRC_ADDR)
    ldi   ZL, lo8(SRAM_ENC_SRC_ADDR)
    ldi   ARG_REG1, MAC_ADDR_LEN
    rcall ES_MEMCMP
    brne  CHK_RPKT_STATUS2
    rjmp  SKIP_ETH_PKT

CHK_RPKT_STATUS2:
    lds   TMP_REG2, SRAM_RPKT_STATUS2
    sbrc  TMP_REG2, RPKT_STATUS2_LENGTH_OUT_OF_RANGE
    rjmp  TYPE_LEN_TYPE
    rjmp  SKIP_ETH_PKT /* no support for type/length = length packets */

TYPE_LEN_TYPE: /* Call handler based on TYPE */
    lds   TMP_REG1, SRAM_TYPE_LEN_H
    lds   TMP_REG2, SRAM_TYPE_LEN_L
TYPE_LEN_IPV4:
    /* Check Type/Len is IPv4 or jump to next type/len */
    cpi   TMP_REG1, hi8(ETHER_TYPE_IPV4)
    brne  TYPE_LEN_ARP
    cpi   TMP_REG2, lo8(ETHER_TYPE_IPV4)
    brne  TYPE_LEN_ARP

    rcall IPV4_HANDLE_PKT
    rjmp  PACKET_END

TYPE_LEN_ARP:
    /* Check Type/Len is ARP or jump to next type/len */
    cpi   TMP_REG1, hi8(ETHER_TYPE_ARP)
    brne  TYPE_LEN_UNKNOWN
    cpi   TMP_REG2, lo8(ETHER_TYPE_ARP)
    brne  TYPE_LEN_UNKNOWN

    rcall ARP_HANDLE_PKT

TYPE_LEN_UNKNOWN:
PACKET_END:
SKIP_ETH_PKT:
    rcall ETH_PKT_PROCESSED
    ret

RESET_ETH:
    DEBUG(PRINT_STR STR_ENC_STATUS_VECTOR_ERROR)
    DEBUG(PRINT_REG RTV_L_REG)
    DEBUG(PRINT_NEWLINE)
    rcall ETH_INIT
    ret

.end
