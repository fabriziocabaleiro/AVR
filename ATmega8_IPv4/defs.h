/* LICENSE {{{ -----------------------------------------------------------------
 * IPv4 stack for AVR (ATmega8) microcontroller.
 * Copyright (C) 2020 Fabrizio Cabaleiro
 * 
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, version 2.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 * 
 * You should have received a copy of the GNU General Public License along with
 * this program. If not, see <https://www.gnu.org/licenses/>.
 * ------------------------------------------------------------------------}}}*/
#ifndef _DEFS_H_
#define _DEFS_H_

/* Global configuration {{{1 --------------------------------------------------*/
/* Default value of internal RC oscillator */
#define F_CPU 1000000 /* Auto-updated by makefile set-clock */
#define USE_DHT11

/* Registers {{{1 -------------------------------------------------------------*/
/* Multiplication output */
#define ml     R0
#define mh     R1

/* Push Word, register used instead of push xl + push xh, then pop xh + pop xl.
 * These aren't push to stack, just using regular register to store X, Y and Z
 * values during a routine call. Be extremely careful when using them. */
#define p1     R2
#define p2     R4

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

/* Poison registers that are used under a macro */
#pragma GCC poison R0
#pragma GCC poison R1
#pragma GCC poison R2
#pragma GCC poison R4
#pragma GCC poison R10
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

/**********************
 * EtherType Protocol *
 **********************/
#define ETHER_TYPE_LEN         0x05DC /* Equal or smaller to this, then is a length */
#define ETHER_TYPE_IPV4        0x0800
#define ETHER_TYPE_ARP         0x0806
#define ETHER_TYPE_WAKE_ON_LAN 0x0842
#define ETHER_TYPE_IPV6        0x86DD

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
