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
/* INCLUDES {{{1 -------------------------------------------------------------*/
.NOLIST
#include <avr/io.h>
#include <avr/interrupt.h>
#include "defs.h"
.LIST

/* MACROS {{{1 ---------------------------------------------------------------*/

/* GLOBAL {{{1 ---------------------------------------------------------------*/
.global STR_START
.global STR_DHCP_HANDLE_START
.global STR_DHCP_SEND_START
.global STR_DHCP_VARS
.global STR_DHCP_SERVER_IP_ADDR
.global STR_DHCP_IP_ADDR
.global STR_DHCP_XID_LAST_BYTE
.global STR_DHCP_ADDRESS_TIME
.global STR_DHCP_SECONDS
.global STR_DHCP_SUBNET_MASK
.global STR_DHCP_DOMAIN_SERVER
.global STR_DHCP_STATE
.global STR_DHCP_TIMER_SUBTRAHEND_PTR_L
.global STR_INCOMING_XID
.global STR_LOCAL_XID
.global STR_OPT_SERVER_ID
.global STR_OPT_ADDRESS_TIME
.global STR_OPT_SUBNET_MASK
.global STR_OPT_DOMAIN_SERVER
.global STR_OPT_ACK
.global STR_COOKIE
.global STR_DONE
.global STR_FAILURE
.global STR_ENC_STATUS_VECTOR_ERROR
.global STR_TIMER0
.global STR_STATE
.global STR_ARP_WR_TBL_ENTRY
.global STR_ARP_REPLACE
.global STR_TIMER_CURRENT_TIME
.global STR_DHT11_DATA
.global STR_ENC_RECEIVE_VECTOR
.global STR_TCP_OPTION_ERR
.global STR_RXC_MSG
.global STR_ERXRDPT
.global STR_ETHERNET_INTERRUPT_HANDLER
.global STR_HANDLE_PKT

/* DATA  {{{1 ----------------------------------------------------------------*/
.section .data

/* TEXT {{{1 -----------------------------------------------------------------*/

.section .text
#ifndef NDEBUG
STR_START:
.string "=START=\r\n"
STR_DHCP_HANDLE_START:
.string "-DHCP handle-\r\n"
STR_DHCP_SEND_START:
.string "-DHCP send-\r\n"
STR_DHCP_VARS:
.string "DHCP VARS\r\n"
STR_DHCP_IP_ADDR:
.string "IP Address     : "
STR_DHCP_SERVER_IP_ADDR:
.string "Server IP ADDR : "
STR_DHCP_XID_LAST_BYTE:
.string "XID Last Byte  : "
STR_DHCP_ADDRESS_TIME:
.string "Address Time   : "
STR_DHCP_SECONDS:
.string "Seconds        : "
STR_DHCP_SUBNET_MASK:
.string "Subnet Mask    : "
STR_DHCP_DOMAIN_SERVER:
.string "Domain Server  : "
STR_DHCP_STATE:
.string "State          : "
STR_DHCP_TIMER_SUBTRAHEND_PTR_L:
.string "Timer Sub Ptr L: "
STR_INCOMING_XID:
.string "Incoming XID "
STR_LOCAL_XID:
.string "Local    XID "
STR_OPT_ACK:
.string "ACK\r\n"
STR_DONE:
.string "Done\r\n"
STR_FAILURE:
.string "Failure\r\n"
STR_ENC_STATUS_VECTOR_ERROR:
.string "ENC received packet with error\r\n"
STR_ENC_RECEIVE_VECTOR:
.string "ENC rcv vec [npkt l:h], [bc l:h], st1/2\r\n"
STR_TIMER0:
.string "*Timer0 interrupt handler*"
STR_STATE:
.string "STATE  "
STR_ARP_WR_TBL_ENTRY:
.string "ARP writing to table entry: "
STR_ARP_REPLACE:
.string "ARP replacing oldest entry in ARP table\r\n"
STR_TIMER_CURRENT_TIME:
.string "TIMER current time: "
STR_DHT11_DATA:
.string "DHT11 data: "
STR_TCP_OPTION_ERR:
.string "TCP Unknown option\r\n"
STR_RXC_MSG:
.string "$ "
STR_ERXRDPT:
.string "ERXRDPT: "
STR_ETHERNET_INTERRUPT_HANDLER:
.string "Eth Int Handler\r\n"
STR_HANDLE_PKT:
.string "Packet Handler\r\n"

.align 1
#endif
