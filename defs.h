/* This file contains only definitions and constants used globally */
#ifndef __DEFS_H__
#define __DEFS_H__

/*******************************************************************************
 * Registers
 ******************************************************************************/
#define INT_TMP_REG0     R15
#define MAIN_TMP_REG     R16
#define MAIN_COUNTER_REG R17
#define TMP1             R18
#define SPI_DATA         R19
#define DELAY_BUF1       R20
#define DELAY_BUF2       R21
#define ETH_TMP_REG1     R22
#define RETURN_VALUE     R23
#define ARG_REG1         R24
#define ARG_REG2         R25

/*******************************************************************************
 * SPI Slave selection
 ******************************************************************************/
#define SPI_SS_ETH       PB1
#define SPI_SS_LCD       PB2
#define SPI_SELECT_LCD   cbi _SFR_IO_ADDR(PORTB), SPI_SS_LCD
#define SPI_SELECT_ETH   cbi _SFR_IO_ADDR(PORTB), SPI_SS_ETH
#define SPI_END_LCD      sbi _SFR_IO_ADDR(PORTB), SPI_SS_LCD
#define SPI_END_ETH      sbi _SFR_IO_ADDR(PORTB), SPI_SS_ETH

/*******************************************************************************
 * SRAM variables
 ******************************************************************************/
#define EEPROM_MAC_ADDR   0x0000
#define EEPROM_IP_ADDR    0x0006
#define EEPROM_MAC_DEBUG  0x000A
#define EEPROM_RECEIVE_STATUS_VECTOR_ERROR 0x001A /* holds 6 bytes TODO: get correct address for it */

/* Receive packet header */
#define RPKT_N_PKT_L      0x0060
#define RPKT_N_PKT_H      0x0061
#define RPKT_BYTE_COUNT_L 0x0062
#define RPKT_BYTE_COUNT_H 0x0063
#define RPKT_STATUS2      0x0065
#define RPKT_STATUS3      0x0066

/* Pending packages to process */
#define RPKT_PENDING_CNT  0x0067

/* Mac addresses */
#define ETH_HEADER        0x0068
#define MAC_ADDR_MYSELF   ETH_HEADER
#define MAC_ADDR_OTHER    0x006E
#define TYPE_LEN_H        0x0074
#define TYPE_LEN_L        0x0075

#define IP_ADDR_0         0x0076
#define IP_ADDR_1         0x0077
#define IP_ADDR_2         0x0078
#define IP_ADDR_3         0x0079

#define ARP_PAYLOAD       0x007A /* Need 28 bytes, next available memory: 0x96 */

/* DEBUGGING FUNCTIONALITY */
#define DEBUG_OPT                0x0196
#define DEBUG_OPT_WRITE_SRAM     0
#define DEBUG_OPT_RECEIVE_BUFFER 1
#define DEBUG_ADDR_L             0x0097
#define DEBUG_ADDR_H             0x0098
#define DEBUG_LEN                0x0099

/* DEBUGGING */
#define PER_PACKET_CONTROL_BYTE_SIZE     1
#define ETH_HEADER_SIZE                  14
#define TRANSMISSION_STATUS_VECTOR_SIZE  7
#define DEBUG_PAYLOAD_SIZE               250
#define DEBUG_FRAME_SIZE                 (DEBUG_PAYLOAD_SIZE + ETH_HEADER_SIZE + PER_PACKET_CONTROL_BYTE_SIZE + TRANSMISSION_STATUS_VECTOR_SIZE)
#define DEBUG_PAYLOAD                    0x0096 /* Lets leave 200 bytes here, therefore next available address is 0x15E */

/*******************************************************************************
 * Miscellaneous
 ******************************************************************************/
#define ERR_ARP_ERR_BIT   PB0
#define ERR_ARP_SET_DDR   sbi _SFR_IO_ADDR(DDRB), ERR_ARP_ERR_BIT
#define ERR_ARP_SET_ERROR sbi _SFR_IO_ADDR(PORTB), ERR_ARP_ERR_BIT
#define ERR_ETH_SET_ERROR sbi _SFR_IO_ADDR(PORTB), ERR_ARP_ERR_BIT
#define ERR_ARP_CLR_ERROR cbi _SFR_IO_ADDR(PORTB), ERR_ARP_ERR_BIT

#define MAC_SIZE_IN_BYTES  6
#define IPV4_SIZE_IN_BYTES 4

/*******************************************************************************
 *
 ******************************************************************************/
DELAY_TMP:
  push DELAY_BUF1
  push DELAY_BUF2
  ldi DELAY_BUF2, 4
DELAY_TMP_W2:
  ldi DELAY_BUF1, 250
DELAY_TMP_W1:
  dec DELAY_BUF1
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  brne DELAY_TMP_W1
  dec DELAY_BUF2
  brne DELAY_TMP_W2
  pop DELAY_BUF2
  pop DELAY_BUF1
  ret

MAIN_WRITE_TO_LCD_AS_HEX:
   push TMP1
   set /* control the twice "loop", set T */
lcd_write_reg_as_hex_twice:
   swap ARG_REG1 /* higher part first */
   mov  TMP1, ARG_REG1
   andi TMP1, 0x0F
   cpi  TMP1, 0x0A
   brge lcd_write_reg_as_hex_over_9
   ori  TMP1, 0x30
   rjmp lcd_write_reg_as_hex_write
lcd_write_reg_as_hex_over_9:
   ori  TMP1, 0x40
   subi TMP1, 0x09
lcd_write_reg_as_hex_write:
   mov  SPI_DATA, TMP1
   SPI_SELECT_LCD
   rcall SPI_MASTER_TRANSMIT
   brtc  lcd_write_reg_as_hex_end /* end if T == 0 */
   clt   /* clear T */
   rjmp  lcd_write_reg_as_hex_twice
lcd_write_reg_as_hex_end:
   pop TMP1
   ret

.macro  PRINT_REG bsel1 bsel0 reg
ldi   ARG_REG1, 0x1F
ldi   ARG_REG2, 0x3
rcall ETH_BIT_FIELD_CLEAR
ldi   ARG_REG1, 0x1F
ldi   ARG_REG2, \bsel1 | \bsel0
rcall ETH_BIT_FIELD_SET
ldi   SPI_DATA, \reg
rcall ETH_READ_CONTROL_REGISTER
mov   ARG_REG1, RETURN_VALUE
rcall MAIN_WRITE_TO_LCD_AS_HEX
.endm

#endif
