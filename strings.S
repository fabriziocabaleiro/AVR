/* vim: set filetype=S foldmethod=marker: */
/* INCLUDES {{{1 */
.NOLIST
#include <avr/io.h>
#include <avr/interrupt.h>
#include "defs.h"
.LIST

/* MACORS {{{1 ---------------------------------------------------------------*/

/* GLOBAL {{{1 ---------------------------------------------------------------*/
.global STR_START
.global STR_DHCP_HANDLE_START
.global STR_DHCP_SEND_START
.global STR_DHCP_VARS
.global STR_DHCP_SERVER_IP_ADDR
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

.align 1
#endif
