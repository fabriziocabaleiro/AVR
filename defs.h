/* vim: set foldmethod=marker: */
#ifndef _DEFS_H_
#define _DEFS_H_

/*******************************************************************************
 * Global configuration {{{
 ******************************************************************************/
#define F_CPU 1000000 /* Default value of internal RC oscillator */
#define USE_DHT11
/* }}} */
/*******************************************************************************
 * Registers {{{
 ******************************************************************************/
/*  */
#define ETH_INT_RQST     R15
/* Register used for temporary values, they may be change after any rcall */
#define TMP_REG1         R16
#define TMP_REG2         R17
#define TMP_REG3         R18
/* Register used to pass arguments to routines */
#define ARG_REG1         R19
#define ARG_REG2         R20
/* Register used to pass values back from routines */
#define RETURN_VALUE     R21
/* Counter */
#define COUNTER_REG      R22

#pragma GCC poison R15
#pragma GCC poison R16
#pragma GCC poison R17
#pragma GCC poison R18
#pragma GCC poison R19
#pragma GCC poison R20
#pragma GCC poison R21
#pragma GCC poison R22
/* Poison [R27:R31] to avoid overwriting X, Y and Z without noticing */
#pragma GCC poison R27
#pragma GCC poison R28
#pragma GCC poison R29
#pragma GCC poison R30
#pragma GCC poison R31
/* }}} */
/*******************************************************************************
 * SPI Slave selection {{{
 ******************************************************************************/
#define SPI_SS_ETH       PB2
#define SPI_SELECT_ETH   cbi _SFR_IO_ADDR(PORTB), SPI_SS_ETH
#define SPI_END_ETH      sbi _SFR_IO_ADDR(PORTB), SPI_SS_ETH
/* }}} */
/*******************************************************************************
 * Miscellaneous {{{
 ******************************************************************************/
/* ADC reading MQ135 */
#define MQ135_PAYLOAD_LEN 2
/* Own messages type/len */
#define MESSAGE_TYPE_LEN 0x1987
/* End SPI communication with ENC28J60 */
#define ETH_END_LISTEN_ON_SPI SPI_END_ETH

/************************
 * BIT FIELDS VARIABLES *
 ************************/
#define BIT_FIELD_1_INT1_DHT11 7

/**********************
 * EtherType Protocol *
 **********************/
#define ETHER_TYPE_LEN         0x05DC /* Equal or smaller to this, then is a length */
#define ETHER_TYPE_IPV4        0x0800
#define ETHER_TYPE_ARP         0x0806
#define ETHER_TYPE_WAKE_ON_LAN 0x0842
#define ETHER_TYPE_IPV6        0x86DD

/**************** 
 * Error macros * 
 ****************/
#define ERR_BIT                                PB0
#define ERR_SET_DDR   sbi _SFR_IO_ADDR(DDRB),  ERR_BIT
#define ERR_SET       sbi _SFR_IO_ADDR(PORTB), ERR_BIT
#define ERR_CLR       cbi _SFR_IO_ADDR(PORTB), ERR_BIT

/**************
 * LED macros *
 **************/
#define PIN_LED0      PD0
#define DDR_LED0      sbi _SFR_IO_ADDR(DDRD),  PIN_LED0
#define SET_LED0      cbi _SFR_IO_ADDR(PORTD), PIN_LED0
#define CLR_LED0      sbi _SFR_IO_ADDR(PORTD), PIN_LED0

#define PIN_LED1      PD1
#define DDR_LED1      sbi _SFR_IO_ADDR(DDRD),  PIN_LED1
#define SET_LED1      cbi _SFR_IO_ADDR(PORTD), PIN_LED1
#define CLR_LED1      sbi _SFR_IO_ADDR(PORTD), PIN_LED1

/********************
 * IP address sizes *
 *******************/
#define MAC_ADDR_LEN       6
#define IPV4_SIZE_IN_BYTES 4

/* }}} */

#endif
