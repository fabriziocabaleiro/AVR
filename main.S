/* vim: set filetype=S foldmethod=marker: */
.NOLIST
#ifndef __AVR_ATmega8__
#   define __AVR_ATmega8__
#endif
#include <avr/io.h>
#include <avr/interrupt.h>
#include "defs.h"
#include "enc28j60.h"
.LIST

.section .text
.global main
.global INT0_vect
.global INT1_vect

/*******************************************************************************
 * TODO: remove {{{
 ******************************************************************************/
#if 1
.global DELAY_TMP
DELAY_TMP:
    push TMP_REG2
    push TMP_REG1
    ldi  TMP_REG1, 4
DELAY_TMP_W2:
    ldi  TMP_REG2, 250
DELAY_TMP_W1:
    dec  TMP_REG2
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    brne DELAY_TMP_W1
    dec  TMP_REG1
    brne DELAY_TMP_W2
    pop  TMP_REG1
    pop  TMP_REG2
    ret

.global MAIN_WRITE_TO_LCD_AS_HEX
MAIN_WRITE_TO_LCD_AS_HEX:
    push TMP_REG2
    push ARG_REG1
    push RETURN_VALUE
    set /* control the twice "loop", set T */
lcd_write_reg_as_hex_twice:
    swap ARG_REG1 /* higher part first */
    mov  TMP_REG2, ARG_REG1
    andi TMP_REG2, 0x0F
    cpi  TMP_REG2, 0x0A
    brge lcd_write_reg_as_hex_over_9
    ori  TMP_REG2, 0x30
    rjmp lcd_write_reg_as_hex_write
lcd_write_reg_as_hex_over_9:
    ori  TMP_REG2, 0x40
    subi TMP_REG2, 0x09
lcd_write_reg_as_hex_write:
    push ARG_REG1
    mov  ARG_REG1, TMP_REG2
    SPI_SELECT_LCD
    rcall SPI_MASTER_TRANSMIT
    pop  ARG_REG1
    brtc  lcd_write_reg_as_hex_end /* end if T == 0 */
    clt   /* clear T */
    rjmp  lcd_write_reg_as_hex_twice
lcd_write_reg_as_hex_end:
    SPI_END_LCD
    pop  RETURN_VALUE
    pop  ARG_REG1
    pop  TMP_REG2
    ret

.macro  PRINT_REG bsel1 bsel0 reg
ldi   ARG_REG1, 0x1F
ldi   ARG_REG2, 0x3
rcall ETH_BIT_FIELD_CLEAR
ldi   ARG_REG1, 0x1F
ldi   ARG_REG2, \bsel1 | \bsel0
rcall ETH_BIT_FIELD_SET
ldi   ARG_REG1, \reg
rcall ETH_READ_CONTROL_REGISTER
mov   ARG_REG1, RETURN_VALUE
rcall MAIN_WRITE_TO_LCD_AS_HEX
.endm

.macro PRINT val
    push  ARG_REG1
    push  RETURN_VALUE
    ldi   ARG_REG1, \val
    SPI_SELECT_LCD
    rcall SPI_MASTER_TRANSMIT
    SPI_END_LCD
    pop   RETURN_VALUE
    pop   ARG_REG1
.endm

.macro PRINTR reg
    push  ARG_REG1
    push  RETURN_VALUE
    mov   ARG_REG1, \reg
    rcall MAIN_WRITE_TO_LCD_AS_HEX
    pop   RETURN_VALUE
    pop   ARG_REG1
.endm
#endif /* }}} */
/*******************************************************************************
 * main, initialize everything {{{
 ******************************************************************************/
main:
    /* Set interrupt on INT0 falling edge */
    in    TMP_REG2, _SFR_IO_ADDR(MCUCR)
    // TODO: Decide which one to use
    ori   TMP_REG2, (1 << ISC01)
    andi  TMP_REG2, ~((1 << ISC00)|(1 << ISC01))
    out   _SFR_IO_ADDR(MCUCR), TMP_REG2

    in    TMP_REG2, _SFR_IO_ADDR(GICR)
    ori   TMP_REG2, (1 << INT1)|(1 << INT0)
    out   _SFR_IO_ADDR(GICR), TMP_REG2

    cbi   _SFR_IO_ADDR(DDRD), PD2

    /* Set global interrupt enable, sleep mode and sleep enable */
    in   TMP_REG2, _SFR_IO_ADDR(MCUCR)
    sbr  TMP_REG2, (1 << SE)
    out  _SFR_IO_ADDR(MCUCR), TMP_REG2

    ldi   TMP_REG1, 255
MAIN_DELAY:
    rcall DELAY_TMP
    dec TMP_REG1
    brne MAIN_DELAY

#ifdef USE_DHT11
    rcall DHT11_SETUP
#endif
    rcall SPI_MASTER_INIT
    rcall ETH_SOFTWARE_RESET
    rcall ETH_BUFFER_INIT
    rcall ETH_MAC_INIT
    rcall ETH_ENABLE_RECEIVE
    rcall ETH_ENABLE_RECEIVE_INTERRUPT
    /* Set LED errors */
    ERR_ARP_SET_DDR

    ldi DEBUG_REG_COUNT, 0
    /* Get IP from DHCP */
    sts   DHCP_XID_LAST_BYTE, DEBUG_REG_COUNT
    rcall DHCP_DISCOVER
    sei

/* }}} */
/*******************************************************************************
 * LOOP {{{
 ******************************************************************************/
LOOP:
    sleep
    rjmp LOOP
/* }}} */
/*******************************************************************************
 * INT0 handle. Received packet interrupt routine {{{
 ******************************************************************************/
INT0_vect:
    push  TMP_REG2
    in    TMP_REG2, _SFR_IO_ADDR(SREG)
    push  TMP_REG2

    /* Read Global interrupt register from ENC28J60 and execute routines
     * accordingly */
    set
READ_ETHERNET_INTERRUPT_REQUEST:
    ldi   ARG_REG1, ENC_COMMON_EIR
    rcall ETH_READ_CONTROL_REGISTER

    brts here
    ERR_ETH_SET_ERROR
here:
    clt
    /* NOT WORKING... SEEMS TO BE WRONG SOMEHOW */
    sbrc  RETURN_VALUE, ENC_COMMON_EIR_PKTIF
    rcall HANDLE_PACKET

    /* TODO: handle other sources of interrupt */

    sbis  _SFR_IO_ADDR(PIND), PD2
    rjmp  READ_ETHERNET_INTERRUPT_REQUEST

    pop   TMP_REG2
    out   _SFR_IO_ADDR(SREG), TMP_REG2
    pop   TMP_REG2
    ERR_ARP_CLR_ERROR
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
    brne  SKIP_ETH_PKT

    rcall ETH_READ_MAC_ADDRS_N_LEN_TYPE

    lds   TMP_REG2, RPKT_STATUS3
    sbrs  TMP_REG2, RPKT_STATUS3_RECEIVE_BROADCAST_PACKET
    rjmp  CHK_RPKT_STATUS2
    /* Check if broadcast was sent by me {{{ */
    ldi   YH, hi8(EEPROM_MAC_ADDR)
    ldi   YL, lo8(EEPROM_MAC_ADDR)
    ldi   ZH, hi8(MAC_ADDR_OTHER)
    ldi   ZL, lo8(MAC_ADDR_OTHER)
    ldi   TMP_REG1, MAC_SIZE_IN_BYTES
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
    lds   TMP_REG2, RPKT_STATUS2
    sbrc  TMP_REG2, RPKT_STATUS2_LENGTH_OUT_OF_RANGE
    rjmp  TYPE_LEN_TYPE
    rjmp  SKIP_ETH_PKT /* no support for type/length = length packets */
    /* }}} */
TYPE_LEN_TYPE: /* {{{ */
    lds   ZH, TYPE_LEN_H
    lds   ZL, TYPE_LEN_L
TYPE_LEN_IPV4: /* {{{ */
    /* Check Type/Len is IPv4 or jump to next type/len */
    cpi   ZH, hi8(ETHER_TYPE_IPV4)
    brne  TYPE_LEN_ARP
    cpi   ZL, lo8(ETHER_TYPE_IPV4)
    brne  TYPE_LEN_ARP

    ERR_ETH_SET_ERROR
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
    cpi   RETURN_VALUE, 0
    brne  ERROR
    rjmp  PACKET_END
    /* }}} */
TYPE_LEN_UNKNOWN: /* }}} */
PACKET_END:
SKIP_ETH_PKT:
    rcall ETH_PKT_PROCESSED
#if 0 // {{{
    inc   DEBUG_REG_COUNT
    cpi   DEBUG_REG_COUNT, 40
    brne  SKIP_MESSAGE
#ifdef USE_DHT11
    //rcall DHT11_READ
#endif
    //rcall SEND_PACKET
    ldi   DEBUG_REG_COUNT, 0
    rcall DHCP_DISCOVER
SKIP_MESSAGE:
#endif // }}} 
    ret

ERROR:
    //ERR_ETH_SET_ERROR
    rjmp  SKIP_ETH_PKT
/* }}} */
/*******************************************************************************
 * INT1 handle {{{
 ******************************************************************************/
INT1_vect:
    /* Save and restore TMP_REG1 for EEPROM_COREDUMP */
    sts   EEPROM_TMP_REG1_SAVE, TMP_REG1
    push  TMP_REG1
    in    TMP_REG1, _SFR_IO_ADDR(SREG)
    sts   EEPROM_SREG, TMP_REG1
    push  TMP_REG1
    lds   TMP_REG1, EEPROM_TMP_REG1_SAVE

    lds   TMP_REG1, BIT_FIELD_1
    sbrc  TMP_REG1, BIT_FIELD_1_INT1_DHT11
    rcall DHT11_INT1_vect

    lds   TMP_REG1, BIT_FIELD_1
    sbrs  TMP_REG1, BIT_FIELD_1_INT1_DHT11
    rcall EEPROM_COREDUMP

    pop   TMP_REG1
    out   _SFR_IO_ADDR(SREG), TMP_REG1
    pop   TMP_REG1
    reti
/* }}} */
