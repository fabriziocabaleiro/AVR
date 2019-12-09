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

/* DATA  {{{1 ----------------------------------------------------------------*/
.section .data

/* TEXT {{{1 -----------------------------------------------------------------*/

/* TODO: At the moment, strings are required to be word aligned. Automate the
 * alignment */
.section .text
#ifndef NDEBUG
STR_START:
.string "=START=\r\n"
STR_DHCP_HANDLE_START:
.string "-DHCP handle-\r\n"
STR_DHCP_SEND_START:
.string "-DHCP send-\r\n"
STR_INCOMING_XID:
.string "Incoming XID "
STR_LOCAL_XID:
.string "Local    XID "
STR_OPT_ACK:
.string "ACK \r\n"
STR_DONE:
.string "Done\r\n"
STR_FAILURE:
.string "Failure\r\n"
STR_ENC_STATUS_VECTOR_ERROR:
.string "ENC status vector error: "
STR_TIMER0:
.string "*Timer0 interrupt handler* "
STR_STATE:
.string "STATE  "
#endif
