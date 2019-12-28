/* vim: set filetype=S foldmethod=marker: */
/* INCLUDES {{{1 */
#include "dhcp.h"
#include "enc28j60.h"
#include "comm.h"
#include "arp.h"
#include "ipv4.h"
#include "defs.h"

/* MACORS {{{1 ---------------------------------------------------------------*/
#define MAC_ADDR_0 0xFA
#define MAC_ADDR_1 0xB2
#define MAC_ADDR_2 0x13
#define MAC_ADDR_3 0x10
#define MAC_ADDR_4 0x00
#define MAC_ADDR_5 0xCA

/* DATA  {{{1 ----------------------------------------------------------------*/
.section .data

EEPROM_DHCP_REQUEST_OPS: /* {{{2 */
    /* Name of the device */
    .byte DHCP_OPTION_HOSTNAME
    .byte 4
    .byte 'C', 'o', 't', 'e'
    /* We set the Option and length here and the code is going to write the IP
     * address */
    .byte DHCP_OPTION_ADDRESS_REQUEST
    .byte DHCP_OPTION_ADDRESS_REQUEST_LEN
EEPROM_DHCP_REQUEST_OPS_END:
EEPROM_IP_ADDR: /* {{{2 */
    /* Initial IP address, this one gets overwritten by DHCP */
#if 0
    .byte 192, 168, 2, 4
#else
    .byte   0,   0, 0, 0
#endif
EEPROM_IP_ADDR_END:
EEPROM_MAC_ADDR: /* {{{2 */
    .byte MAC_ADDR_0
    .byte MAC_ADDR_1
    .byte MAC_ADDR_2
    .byte MAC_ADDR_3
    .byte MAC_ADDR_4
    .byte MAC_ADDR_5
EEPROM_MAC_ADDR_END:
EEPROM_IP_HEADER: /* {{{2 */
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
    /* Checksum to zero, so it can be calculated and set when necessary */
    .byte 0x00
    .byte 0x00
EEPROM_IP_HEADER_TIL_SRC_IP_ADDR:
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
EEPROM_IP_HEADER_END:
EEPROM_UDP_DHCP_PORT: /* {{{2 */
    /* Must be next to EEPROM_IP_HEADER_END because we used in DHCP_SEND as a
     * continuous array of data */
    .byte hi8(DHCP_UDP_SRC_PORT)
    .byte lo8(DHCP_UDP_SRC_PORT)
    .byte hi8(DHCP_UDP_DST_PORT)
    .byte lo8(DHCP_UDP_DST_PORT)
EEPROM_UDP_DHCP_PORT_END:
EEPROM_DHCP_HEADER: /* {{{2 */
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
EEPROM_DHCP_HEADER_END:
EEPROM_DHCP_MAGIC_COOKIE: /* {{{2 */
    .byte 0x63
    .byte 0x82
    .byte 0x53
    .byte 0x63
EEPROM_DHCP_MAGIC_COOKIE_END:
EEPROM_DHCP_OPTION_MSG_N_LEN: /* {{{2 */
    .byte DHCP_OPTION_DHCP_MSG_TYPE
    .byte DHCP_OPTION_DHCP_MSG_TYPE_LEN
EEPROM_DHCP_OPTION_MSG_N_LEN_END:
EEPROM_DHCP_TIMERS: /* {{{2 */
    .byte   2
    .byte   4
    .byte  16
EEPROM_DHCP_TIMERS_T2:
    .byte  20
    .byte  24
    .byte  28
EEPROM_DHCP_TIMERS_END:
EEPROM_ENC_BUFFER_INIT: /* {{{2 */
    /* SET BANK 0 */
    .byte ENC_COMMON_ECON1 | ETH_SPI_CMD_BFC
    .byte ENC_COMMON_ECON1_BSEL0 | ENC_COMMON_ECON1_BSEL1

    /* Memory in range [ERXST, ERXND] dedicated to receive HW */
    /* ERXST 13 bits, need to program: (recommended even number) */
    /* ERXND 13 bits, need to program: */

    /* Setting transmission to [0:0x1AFF] and Receive to 0x1F00 */

    /* Transmit start */
    .byte ENC_BANK0_ETXSTL | ETH_SPI_CMD_WCR
    .byte BUF_TX_ST_L
    .byte ENC_BANK0_ETXSTH | ETH_SPI_CMD_WCR
    .byte BUF_TX_ST_H

    /* Transmit end */
    .byte ENC_BANK0_ETXNDL | ETH_SPI_CMD_WCR
    .byte BUF_TX_ND_L
    .byte ENC_BANK0_ETXNDH | ETH_SPI_CMD_WCR
    .byte BUF_TX_ND_H

    /* JUST NEED 7 BYTES FOR STATUS VECTOR BETWEEN TRANSMIT AND RECEIVE */
    /* Receive start */
    .byte ENC_BANK0_ERXSTL | ETH_SPI_CMD_WCR
    .byte BUF_RX_ST_L
    .byte ENC_BANK0_ERXSTH | ETH_SPI_CMD_WCR
    .byte BUF_RX_ST_H

    /* Programming ERXRDPTx to the same value than ERXSTx
     * The ERXRDPT registers define a location within the FIFO where the receive
     * hardware is forbidden to write to. In normal operation, the receive
     * hardware will write data up to, but not including, the memory pointed to
     * by ERXRDPT.
     */
    .byte ENC_BANK0_ERXRDPTL | ETH_SPI_CMD_WCR
    .byte BUF_RX_ST_L
    .byte ENC_BANK0_ERXRDPTH | ETH_SPI_CMD_WCR
    .byte BUF_RX_ST_H

    /* Programming ERDPT (read point for RBM) to the start of receive area */
    .byte ENC_BANK0_ERDPTL | ETH_SPI_CMD_WCR
    .byte BUF_RX_ST_L
    .byte ENC_BANK0_ERDPTH | ETH_SPI_CMD_WCR
    .byte BUF_RX_ST_H

    /* Receive end */
    .byte ENC_BANK0_ERXNDL | ETH_SPI_CMD_WCR
    .byte BUF_RX_ND_L
    .byte ENC_BANK0_ERXNDH | ETH_SPI_CMD_WCR
    .byte BUF_RX_ND_H

    /* SET BANK 1 */
    /* filter */
    .byte ENC_COMMON_ECON1 | ETH_SPI_CMD_BFS
    .byte ENC_COMMON_ECON1_BSEL0

    /* Promiscuous mode */
    .byte ENC_BANK1_ERXFCON | ETH_SPI_CMD_WCR
    .byte ENC_BANK1_ERXFCON_UCEN | ENC_BANK1_ERXFCON_CRCEN | ENC_BANK1_ERXFCON_BCEN
EEPROM_ENC_BUFFER_INIT_END:
EEPROM_ENC_MAC_INIT: /* {{{2 */
    /* SET BANK 2 */
    .byte ENC_COMMON_ECON1 | ETH_SPI_CMD_BFC
    .byte ENC_COMMON_ECON1_BSEL0
    .byte ENC_COMMON_ECON1 | ETH_SPI_CMD_BFS
    .byte ENC_COMMON_ECON1_BSEL1

    /* ENC_BANK2_MACON1 */
    .byte ENC_BANK2_MACON1 | ETH_SPI_CMD_BFS
    .byte ENC_BANK2_MACON1_MARXEN | ENC_BANK2_MACON1_FULL_DUPLEX

    /* ENC_BANK2_MACON3 */
    .byte ENC_BANK2_MACON3 | ETH_SPI_CMD_BFS
    .byte ENC_BANK2_MACON3_PADCFG0 | ENC_BANK2_MACON3_TXCRCEN | ENC_BANK2_MACON3_FULL_DUPLEX | ENC_BANK2_MACON3_FRMLNEN

    /* ENC_BANK2_MACON4  */
    .byte ENC_BANK2_MACON4 | ETH_SPI_CMD_BFS
    .byte ENC_BANK2_MACON4_DEFER

    /* Max frame length */
    /* Normal network nodes are designed to handle packets that are 1518 bytes or
     * less. 1518 -> 0x5EE
     */
    .byte ENC_BANK2_MAMXFLL | ETH_SPI_CMD_WCR
    .byte 0xEE
    .byte ENC_BANK2_MAMXFLH | ETH_SPI_CMD_WCR
    .byte 0x05

    /* ENC_BANK2_MABBIPG. */
    /* Most applications will program this register with 15h when Full-Duplex
     * mode is used and 12h when Half-Duplex mode is used.
     */
    .byte ENC_BANK2_MABBIPG | ETH_SPI_CMD_WCR
    .byte ENC_BANK2_MABBIPG_FULL_DUPLEX

    /* ENC_BANK2_MAIPGL. */
    /* Configure the Non-Back-to-Back Inter-Packet Gap register low byte, ENC_BANK2_MAIPGL.
     * Most applications will program this register with 12h.
     */
    .byte ENC_BANK2_MAIPGL | ETH_SPI_CMD_WCR
    .byte 0x12

    /* ENC_BANK2_MAIPGH for full duplex to 0x0C */
    .byte ENC_BANK2_MAIPGH | ETH_SPI_CMD_WCR
    .byte 0x0C

    /* ENC_BANK2_MACLCON1 & ENC_BANK2_MACLCON2 default should be ok */

    /* SEST BANK 3 */
    .byte ENC_COMMON_ECON1 | ETH_SPI_CMD_BFS
    .byte ENC_COMMON_ECON1_BSEL1 | ENC_COMMON_ECON1_BSEL0

EEPROM_ENC_MAC_INIT_END:
EEPROM_ENC_WRITE_BUFFER_PACKET_HEADER_PRESET:
    /* Set BANK 0 */
    .byte ENC_COMMON_ECON1 | ETH_SPI_CMD_BFC
    .byte ENC_COMMON_ECON1_BSEL0 | ENC_COMMON_ECON1_BSEL1

    /* Set Write Pointer EWRPT to start of transmit buffer */
    .byte ENC_BANK0_EWRPTL | ETH_SPI_CMD_WCR
    .byte BUF_TX_ST_L

    .byte ENC_BANK0_EWRPTH | ETH_SPI_CMD_WCR
    .byte BUF_TX_ST_H

EEPROM_ENC_WRITE_BUFFER_PACKET_HEADER_PRESET_END:
EEPROM_DHCP_SRC_DST_PORT: /* {{{2 */
    .byte hi8(INTERNET_SERVICE_BOOTPS_67_UDP)
    .byte lo8(INTERNET_SERVICE_BOOTPS_67_UDP)
    .byte hi8(INTERNET_SERVICE_BOOTPC_68_TCP)
    .byte lo8(INTERNET_SERVICE_BOOTPC_68_TCP)
EEPROM_DHCP_SRC_DST_PORT_END:
EEPROM_COMM_SRC_DST_PORT: /* {{{2 */
    .byte hi8(COMM_SRC_PORT)
    .byte lo8(COMM_SRC_PORT)
    .byte hi8(COMM_DST_PORT)
    .byte lo8(COMM_DST_PORT)
EEPROM_COMM_SRC_DST_PORT_END:
EEPROM_HTTP_DST_PORT: /* {{{2 */
    .byte hi8(INTERNET_SERVICE_HTTP_80_TCP)
    .byte lo8(INTERNET_SERVICE_HTTP_80_TCP)
EEPROM_HTTP_DST_PORT_END:
EEPROM_ARP_REQUEST: /* {{{2 */
    /* HTYPE 0x0001 for Ethernet */
    .byte 0x00
    .byte 0x01
    /* PTYPE 0x0800 protocol type IPv4 */
    .byte 0x08
    .byte 0x00
    /* HLEN Hardware address length 6 */
    .byte    6
    /* PLEN Protocol address length 4 */
    .byte    4
    /* Operation (request or reply) */
    .byte 0
    .byte ARP_OPER_REQUEST
    /* SHA Sender HW address */
    .byte MAC_ADDR_0
    .byte MAC_ADDR_1
    .byte MAC_ADDR_2
    .byte MAC_ADDR_3
    .byte MAC_ADDR_4
    .byte MAC_ADDR_5
    /* SPA Sender IP address, putting here a placeholder */
    .skip IPV4_ADDR_LEN, 0
    /* THA Target hardware address, all zeros as unknown */
    .skip MAC_ADDR_LEN, 0
EEPROM_ARP_REQUEST_END:
EEPROM_HTTP_RESPONSE: /* {{{2 */
    .byte 'H','T','T','P','/','1','.','1',' ','2','0','0',' ','O','K','\r','\n'
    .byte 'c','o','n','t','e','n','t','-','l','e','n','g','t','h',':','1','6','\r','\n'
    .byte '\r','\n'
EEPROM_HTTP_BODY:
    .byte 'R','H',':'
EEPROM_HTTP_RH_OFFSET:
    .byte '0','0','.','0'
    .byte '\n'
    .byte 'T','*',':'
    .byte '0','0','.','0'
    .byte '\n'
EEPROM_HTTP_BODY_END:
EEPROM_HTTP_RESPONSE_END:
EEPROM_DEBUG_PREFIX: /* {{{2 */
    .byte 0xAB
    .byte 0xAB
    .byte 0xAB
    .byte 0xAB
EEPROM_DEBUG:

.end
