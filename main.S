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
#ifdef WRITE_MAC_IN_EEPROM
WRITE_MAC_TO_EEPROM:
   push R16
   push R24
   push R25
   ldi  R25, hi8(EEPROM_MAC_ADDR)
   ldi  R24, lo8(EEPROM_MAC_ADDR)

EEPROM_B1:
   sbic _SFR_IO_ADDR(EECR), EEWE
   rjmp EEPROM_B1
   out  _SFR_IO_ADDR(EEARH), R25
   out  _SFR_IO_ADDR(EEARL), R24
   adiw R24, 1
   ldi  R16, 0xFA
   out  _SFR_IO_ADDR(EEDR), R16
   sbi  _SFR_IO_ADDR(EECR), EEMWE
   sbi  _SFR_IO_ADDR(EECR), EEWE

EEPROM_B2:
   sbic _SFR_IO_ADDR(EECR), EEWE
   rjmp EEPROM_B2
   out  _SFR_IO_ADDR(EEARH), R25
   out  _SFR_IO_ADDR(EEARL), R24
   adiw R24, 1
   ldi  R16, 0xB2
   out  _SFR_IO_ADDR(EEDR), R16
   sbi  _SFR_IO_ADDR(EECR), EEMWE
   sbi  _SFR_IO_ADDR(EECR), EEWE

EEPROM_B3:
   sbic _SFR_IO_ADDR(EECR), EEWE
   rjmp EEPROM_B3
   out  _SFR_IO_ADDR(EEARH), R25
   out  _SFR_IO_ADDR(EEARL), R24
   adiw R24, 1
   ldi  R16, 0x13
   out  _SFR_IO_ADDR(EEDR), R16
   sbi  _SFR_IO_ADDR(EECR), EEMWE
   sbi  _SFR_IO_ADDR(EECR), EEWE

EEPROM_B4:
   sbic _SFR_IO_ADDR(EECR), EEWE
   rjmp EEPROM_B4
   out  _SFR_IO_ADDR(EEARH), R25
   out  _SFR_IO_ADDR(EEARL), R24
   adiw R24, 1
   ldi  R16, 0x10
   out  _SFR_IO_ADDR(EEDR), R16
   sbi  _SFR_IO_ADDR(EECR), EEMWE
   sbi  _SFR_IO_ADDR(EECR), EEWE

EEPROM_B5:
   sbic _SFR_IO_ADDR(EECR), EEWE
   rjmp EEPROM_B5
   out  _SFR_IO_ADDR(EEARH), R25
   out  _SFR_IO_ADDR(EEARL), R24
   adiw R24, 1
   ldi  R16, 0x00
   out  _SFR_IO_ADDR(EEDR), R16
   sbi  _SFR_IO_ADDR(EECR), EEMWE
   sbi  _SFR_IO_ADDR(EECR), EEWE

EEPROM_B6:
   sbic _SFR_IO_ADDR(EECR), EEWE
   rjmp EEPROM_B6
   out  _SFR_IO_ADDR(EEARH), R25
   out  _SFR_IO_ADDR(EEARL), R24
   adiw R24, 1
   ldi  R16, 0xCA
   out  _SFR_IO_ADDR(EEDR), R16
   sbi  _SFR_IO_ADDR(EECR), EEMWE
   sbi  _SFR_IO_ADDR(EECR), EEWE

   pop  R25
   pop  R24
   pop  R16
   ret
#endif

main:
   /* Set interrupt on INT0 falling edge */
#if 0 // Not using interrupt at the moment
   in   MAIN_TMP_REG, _SFR_IO_ADDR(MCUCR)
   ori  MAIN_TMP_REG, (1 << ISC01)
   andi MAIN_TMP_REG, ~(1 << ISC00)
   out  _SFR_IO_ADDR(MCUCR), MAIN_TMP_REG

   in   MAIN_TMP_REG, _SFR_IO_ADDR(GICR)
   ori  MAIN_TMP_REG, (1 << INT0)
   out  _SFR_IO_ADDR(GICR), MAIN_TMP_REG
#endif

   cbi  _SFR_IO_ADDR(DDRD), PD2

   /* Set global interrupt enable, sleep mode and sleep enable */
   in   MAIN_TMP_REG, _SFR_IO_ADDR(MCUCR)
   ori  MAIN_TMP_REG, (1 << SE) | (1 << SM0)
   andi MAIN_TMP_REG, ~((1 << SM2) | (1 << SM1))
   out  _SFR_IO_ADDR(MCUCR), MAIN_TMP_REG
   sei

   /* Set LED errors */
   ERR_ARP_SET_DDR

#ifdef WRITE_MAC_IN_EEPROM
   /* Set MAC in EEPROM */
   rcall WRITE_MAC_TO_EEPROM
#endif

   rcall DELAY_TMP
   rcall SPI_MASTER_INIT
   rcall MAIN_WRITE_INIT
   rcall ETH_SOFTWARE_RESET
   // delay {
ETH_RESET:
   ldi MAIN_COUNTER_REG, 4
ETH_RESET_delay_1:
   ldi MAIN_TMP_REG, 20
ETH_RESET_delay_2:
   rcall DELAY_TMP
   dec MAIN_TMP_REG
   brne ETH_RESET_delay_2
   dec MAIN_COUNTER_REG
   brne ETH_RESET_delay_1
   // }
   rcall ETH_BUFFER_INIT
   rcall ETH_MAC_INIT
   rcall ETH_MISC_INIT
   rcall ETH_ENABLE_RECEIVE
   //rcall ETH_ENABLE_RECEIVE_INTERRUPT

loop:
   ldi MAIN_COUNTER_REG, 4
loop_delay_1:
   ldi MAIN_TMP_REG, 2
loop_delay_2:
   rcall DELAY_TMP
   dec MAIN_TMP_REG
   brne loop_delay_2
   dec MAIN_COUNTER_REG
   brne loop_delay_1

   ERR_ARP_CLR_ERROR

   /* select bank */
   ldi   ARG_REG1, ECON1
   ldi   ARG_REG2, ECON1_BSEL0
   rcall ETH_BIT_FIELD_SET
   ldi   ARG_REG1, ECON1
   ldi   ARG_REG2, ECON1_BSEL1
   rcall ETH_BIT_FIELD_CLEAR
   ldi   SPI_DATA, EPKTCNT
   rcall ETH_READ_CONTROL_REGISTER
   sts   RPKT_PENDING_CNT, RETURN_VALUE
   nop

   /* Start loop again if not pending packet */
   tst   RETURN_VALUE
   breq  loop

#if 0
   /* SET BANK 0 */
   ldi   ARG_REG1, ECON1
   ldi   ARG_REG2, ECON1_BSEL0 | ECON1_BSEL1
   rcall ETH_BIT_FIELD_CLEAR
   ldi   SPI_DATA, ERDPTH
   rcall ETH_READ_CONTROL_REGISTER
   mov   ARG_REG1, RETURN_VALUE
   rcall MAIN_WRITE_TO_LCD_AS_HEX
   ldi   SPI_DATA, ERDPTL
   rcall ETH_READ_CONTROL_REGISTER
   mov   ARG_REG1, RETURN_VALUE
   rcall MAIN_WRITE_TO_LCD_AS_HEX
   PRINT_REG 0 0 ERXWRPTH
   PRINT_REG 0 0 ERXWRPTL
#endif
   /* Next Read Pointer */
   rcall ETH_READ_RECEIVE_HEADER
   rcall ETH_CHECK_RECEIVE_STATUS_VECTOR
   cpi   RETURN_VALUE, 0
   brne  SKIP_ETH_PKT

   rcall ETH_READ_MAC_ADDRS_N_LEN_TYPE

   /* TODO: do checks on RPKT_STATUS[23] */
   lds   MAIN_TMP_REG, RPKT_STATUS2
   /* if bit is set, then package has a type, not a length */
   sbrc  MAIN_TMP_REG, STATUS2_LENGTH_OUT_OF_RANGE
      rcall ARP_PROCESS
   cpi RETURN_VALUE, 0
   brne NO_ARP_PACKET

   /* Write ARP Reply */
   rcall ETH_WRITE_BUFFER_PACKET_HEADER
   ldi ZH, 0
   ldi ZL, ARP_PAYLOAD
   ldi ARG_REG1, 28
   rcall ETH_WRITE_BUFFER_PACKET_PAYLOAD

NO_ARP_PACKET:
SKIP_ETH_PKT:
   rcall ETH_PKT_PROCESSED
#if 1
   /* DEBUGGING */
   ldi   TMP1, DEBUG_OPT_RECEIVE_BUFFER
   sts   DEBUG_OPT, TMP1
   rcall ETH_SEND_DEBUG
#endif
   rjmp loop


INT0_vect:
#if 0
   cli
   push INT_TMP_REG0
   in   INT_TMP_REG0, _SFR_IO_ADDR(SREG)
   push SPI_DATA
   ldi  SPI_DATA, 'I'
   SPI_SELECT_LCD
   rcall SPI_MASTER_TRANSMIT
   pop  SPI_DATA
   out  _SFR_IO_ADDR(SREG), INT_TMP_REG0
   pop  INT_TMP_REG0
   sei
#endif
   reti
  
MAIN_WRITE_INIT:
   rcall DELAY_TMP
   SPI_SELECT_LCD
   ldi SPI_DATA, 'S'
   rcall SPI_MASTER_TRANSMIT
   SPI_SELECT_LCD
   ldi SPI_DATA, 't'
   rcall SPI_MASTER_TRANSMIT
   SPI_SELECT_LCD
   ldi SPI_DATA, 'a'
   rcall SPI_MASTER_TRANSMIT
   SPI_SELECT_LCD
   ldi SPI_DATA, 'r'
   rcall SPI_MASTER_TRANSMIT
   SPI_SELECT_LCD
   ldi SPI_DATA, 't'
   rcall SPI_MASTER_TRANSMIT
   ldi TMP1, 0x0B
KEEP_WRITING_SPACES:
   SPI_SELECT_LCD
   ldi SPI_DATA, ' '
   rcall SPI_MASTER_TRANSMIT
   dec TMP1
   brne KEEP_WRITING_SPACES
   ret

