/* vim: set foldmethod=marker: */
#ifndef _DEFS_H_
#define _DEFS_H_

/* Global configuration {{{1 --------------------------------------------------*/
/* Default value of internal RC oscillator */
#define F_CPU 1000000
#define USE_DHT11

/* Registers {{{1 -------------------------------------------------------------*/
#define XMULX_RTV_L_REG  R0
#define XMULX_RTV_H_REG  R1
#define SAVED1_REG       R2
#define SAVED2_REG       R3
#define ZERO_REG         R10
#define ENC_INT_RQST_REG R15
/* Register used for temporary values, they may be change after any rcall */
#define TMP_REG1         R16
#define TMP_REG2         R17
/* Register used to pass arguments to routines, some routines will change their
 * values, other won't */
#define ARG_REG1         R18
#define ARG_REG2         R19
/* Registers used to pass values back from routines.
 * Routines may change them even though they don't return anything */
#define RTV_L_REG        R20
#define RTV_H_REG        R21
/* Counter */
#define COUNTER_REG      R22

/* When multiplying two registers, the results is store in R1:R0, therefore
 * avoid using them */
#pragma GCC poison R0
#pragma GCC poison R1
#pragma GCC poison R10
#pragma GCC poison R15
#pragma GCC poison R16
#pragma GCC poison R17
#pragma GCC poison R18
#pragma GCC poison R19
#pragma GCC poison R20
#pragma GCC poison R21
#pragma GCC poison R22
/* Poison [R26:R31] to avoid overwriting X, Y and Z without noticing */
#pragma GCC poison R26
#pragma GCC poison R27
#pragma GCC poison R28
#pragma GCC poison R29
#pragma GCC poison R30
#pragma GCC poison R31

/* SPI Slave selection {{{1 ---------------------------------------------------*/
#define SPI_SS_ETH                PB2
#define SPI_SELECT_ETH            cbi   _SFR_IO_ADDR(PORTB), SPI_SS_ETH
#define SPI_SKIP_IF_SELECTED_ETH  sbic  _SFR_IO_ADDR(PORTB), SPI_SS_ETH
#define SPI_END_ETH               sbi   _SFR_IO_ADDR(PORTB), SPI_SS_ETH

/* Miscellaneous {{{1 ---------------------------------------------------------*/
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

/********************
 * IP address sizes *
 *******************/
#define MAC_ADDR_LEN       6

/*************
 * Debugging *
 ************/
#ifndef NDEBUG
#   define DEBUG(x) x
#else
#   define DEBUG(x)
#endif

/* }}} */

#endif
