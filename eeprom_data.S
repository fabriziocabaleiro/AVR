/* vim: set filetype=S foldmethod=marker: */
#include "dhcp.h"

.section .data

EEPROM_MAC_ADDR: /* {{{ */
    .byte 0xFA
    .byte 0xB2
    .byte 0x13
    .byte 0x10
    .byte 0x00
    .byte 0xCA
EEPROM_MAC_ADDR_END: /* }}} */
EEPROM_IP_ADDR: /* {{{ */
    /* Initial IP address, this one gets overwritten by DHCP */
#if 0
    .byte 192
    .byte 168
    .byte   2
    .byte   4
#else
    .byte   0
    .byte   0
    .byte   0
    .byte   0
#endif
EEPROM_IP_ADDR_END: /* }}} */
EEPROM_MAC_DEBUG: /* {{{ */
    .byte 0xF0
    .byte 0x1F
    .byte 0xAF
    .byte 0x4C
    .byte 0x19
    .byte 0x15
EEPROM_MAC_DEBUG_END: /* }}} */
EEPROM_IP_HEADER: /* {{{ */
    /* Default header for UDP packages */
    /* Version 4, IHL 5 */
    .byte 0x45
    /* Type of service 0 */
    .byte 0x00
    /* Total length, 60 bytes */
    .byte 0x00
    .byte 0x3C
    /* Identification */
    .byte 0xDA
    .byte 0xD1
    /* Don't fragment, fragment offset 0 */
    .byte 0x40
    .byte 0x00
    /* Time to leave max */
    .byte 0xFF
    /* Protocol 17 (UDP) */
    .byte 0x11
EEPROM_IP_HEADER_TIL_CHK_SUM: /* {{{ */
    /* Checksum to zero, so it can be calculated and set when necessary */
    .byte 0x00
    .byte 0x00
    /* Source IP address, non-routable meta address */
    .byte 0x00
    .byte 0x00
    .byte 0x00
    .byte 0x00
    /* Destination IP address broadcast */
    .byte 0xFF
    .byte 0xFF
    .byte 0xFF
    .byte 0xFF
EEPROM_IP_HEADER_TIL_CHK_SUM_END: /* }}} */
EEPROM_IP_HEADER_END: /* }}} */
EEPROM_DHCP_HEADER: /* {{{ */
    /* OP, BOOTREQUEST */
    .byte 0x01
    /* HType Ethernet */
    .byte 0x01
    /* Hardware address length */
    .byte 0x06
    /* HOPS */
    .byte 0x00
    /* XID is four bytes, but, we use the last one for counter */
    .byte 0xCA
    .byte 0xCA
    .byte 0x00
EEPROM_DHCP_HEADER_END: /* }}} */
EEPROM_DHCP_MAGIC_COOKIE: /* {{{ */
    .byte 0x63
    .byte 0x82
    .byte 0x53
    .byte 0x63
EEPROM_DHCP_MAGIC_COOKIE_END: /* }}} */
EEPROM_DHCP_REQUEST_OPS: /* {{{ */
    /* Name of the device */
    .byte DHCP_OPTION_HOSTNAME
    .byte 4
    .byte 'C'
    .byte 'o'
    .byte 't'
    .byte 'e'
    /* We set the Option and length here and the code is going to write the IP
     * address */
    .byte DHCP_OPTION_ADDRESS_REQUEST
    .byte DHCP_OPTION_ADDRESS_REQUEST_LEN
EEPROM_DHCP_REQUEST_OPS_END: /* }}} */
EEPROM_DHCP_TIMERS: /* {{{ */
    .byte   2
    .byte   4
    .byte  16
EEPROM_DHCP_TIMERS_T2:
    .byte  20
    .byte  24
    .byte  28
EEPROM_DHCP_TIMERS_END: /* }}} */
EEPROM_DEBUG_PREFIX: /* {{{ */
    .byte 0xAB
    .byte 0xAB
    .byte 0xAB
    .byte 0xAB
EEPROM_DEBUG: /* }}} */

.end
