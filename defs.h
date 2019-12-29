/* vim: set foldmethod=marker: */
#ifndef _DEFS_H_
#define _DEFS_H_

/* Global configuration {{{1 --------------------------------------------------*/
/* Default value of internal RC oscillator */
#define F_CPU 8000000 /* Auto-updated by makefile set-clock */
#define USE_DHT11

/* Registers {{{1 -------------------------------------------------------------*/
/* Multiplication output */
#define ml     R0
#define mh     R1

/* This register is set to zero at the beginning of main and must stay like that
 * forever */
#define zero   R10

/* Register for exchanging values with routines.
 * All of this registers may change after calling a routine.
 * We prefer to:
 * - Populate input values from a1 to a4.
 * - Populate return values from a4 to a1.
 * By doing this, we may be able to retain the value of the input register,
 * avoiding the need of resetting them. */
#define a1     R16
#define a2     R17
#define a3     R18 /* used with movw */
#define a4     R19

/* Register used for temporary values, they may be change after calling a
 * routine */
#define t1     R20
#define t2     R21
#define t3     R22 /* Used normally as counter */

/* Register that hold saved values, we guarantee that this register will have
 * the same value after calling a routine */
#define s3     R23
#define s1     R24 /* used with sbiw */
#define s2     R25

/* Note: X and Z are normally used as exchange registers, some functions do
 * change them and others don't, depending on what will generate the smallest
 * footprint.
 * Normally using X as Src pointer and Z as Dst pointer.
 * Using Y as saved pointer. */

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
#pragma GCC poison R23
#pragma GCC poison R24
#pragma GCC poison R25
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
