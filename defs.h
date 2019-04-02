/* vim: set foldmethod=marker: */
#ifndef _DEFS_H_
#define _DEFS_H_

#include "eeprom_data.h"

/*******************************************************************************
 * Global configuration {{{
 ******************************************************************************/
#define F_CPU 1000000 /* Default value of internal RC oscillator */
#define USE_DHT11
/* }}} */
/*******************************************************************************
 * Registers {{{
 ******************************************************************************/
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
/* TODO: Could be done without private register */
#define DEBUG_REG_COUNT  R25

#pragma GCC poison R15
#pragma GCC poison R16
#pragma GCC poison R17
#pragma GCC poison R18
#pragma GCC poison R19
#pragma GCC poison R20
#pragma GCC poison R21
#pragma GCC poison R22
/* }}} */
/*******************************************************************************
 * SPI Slave selection {{{
 ******************************************************************************/
#define SPI_SS_ETH       PB1
#define SPI_SS_LCD       PB2
#define SPI_SELECT_LCD   cbi _SFR_IO_ADDR(PORTB), SPI_SS_LCD
#define SPI_SELECT_ETH   cbi _SFR_IO_ADDR(PORTB), SPI_SS_ETH
#define SPI_END_LCD      sbi _SFR_IO_ADDR(PORTB), SPI_SS_LCD
#define SPI_END_ETH      sbi _SFR_IO_ADDR(PORTB), SPI_SS_ETH
/* }}} */
/*******************************************************************************
 * SRAM variables {{{
 ******************************************************************************/
/*************
 * DEBUGGING *
 *************/
#define EEPROM_COREDUMP_DISPLACEMENT    0x0060
/* Save TMP_REG1 during INT1_vect */
#define EEPROM_SREG                     EEPROM_COREDUMP_DISPLACEMENT
#define EEPROM_PCH                      0x0061
#define EEPROM_PCL                      0x0062
#define EEPROM_TMP_REG1_SAVE            0x0063

/* Pending packages to process */
#define RPKT_PENDING_CNT  0x0066

/* Mac addresses */
/* This fields are updated every time we receive a new packet */
#define ETH_HEADER        0x0067
#define MAC_ADDR_MYSELF   ETH_HEADER
#define MAC_ADDR_OTHER    0x006D
#define TYPE_LEN_H        0x0073
#define TYPE_LEN_L        0x0074

/* This is the default IP address to send packages to,
 * it should be set by password authentication or something else, but, for now,
 * just assigning it through ping request */
#define IP_ADDR_DST       0x0075

#define ARP_PAYLOAD       0x007A /* Need 28 bytes, next available memory: 0x96 */
#define ARP_PAYLOAD_LEN       28

/******** 
 * IPv4 * 
 ********/
/* Max header size 15 * 4 = 60  therefore next available address 0x0D2 */
#define IPV4_HEADER                     0x0096
#define IPV4_HEADER_MAX_LEN                 60
#define IPV4_DEFAULT_HEADER_LEN             20
#define IPV4_PACKET_FOR_ME              0x00D2
#define IPV4_IHL_IN_BYTES               0x00D3
/* Next available address 0x00D3 */
#define IPV4_PAYLOAD                    0x00D4
#define IPV4_PAYLOAD_LEN                   200
/* Next available address 0x019B */
#define MESSAGE_PAYLOAD                 0x019C
#define MESSAGE_PAYLOAD_LEN                 48
/* Next available address 0x01CC */

/************************************* 
 * DHT11 Temperature/Humidity sensor * 
 *************************************/
/* In which step is with respect to communication process */
#define DHT11_PAYLOAD                   0x01CC
#define DHT11_PAYLOAD_LEN                    5 /* 40 Bits */
/* Next available address 0x01D1 */

/*********************
 * ADC reading MQ135 *
 *********************/
#define MQ135_PAYLOAD                   0x01D1 /* 2 bytes */
#define MQ135_PAYLOAD_LEN                    2

/***************************
 * Communication variables *
 ***************************/
#define COMM_MAC_DST                    0x01D3 /* 6 bytes */
#define COMM_TYPE_LEN                   0x01D9 /* 2 bytes */
#define COMM_PKT_LEN                    0x01DB /* 1 byte  */

/* Pointer to Dst MAC address */
#define ENC_MAC_DST_PTR                 0x01DC /* 2 bytes */
/* Pointer to TYPE/LEN value */
#define ENC_TYPE_LEN_PTR                0x01DE /* 2 bytes */
/* Addresses in SRAM are 11 bits long, first MSB of the MAC Dst pointer set to
 * one means broadcast */
#define ENC_MAC_DST_PTR_BROADCAST_BIT        7
/* As above, if this bit is set, then TYPE/LEN is IPv4 */
#define ENC_TYPE_LEN_PTR_IPv4                7

/**************************
 * DHCP SERVER IP ADDRESS *
 **************************/
#define DHCP_SERVER_IP_ADDR             0x01E0 /* 4 bytes */
#define DHCP_XID_LAST_BYTE              0x01E4 /* 1 byte  */

/************************
 * BIT FIELDS VARIABLES *
 ***********************/
// #define BIT_FIELD_1               0x01EB
// #define BIT_FIELD_1_INT1_DHT11         7

/* Receive packet header, it is read continuously {{{ */
#define RPKT_N_PKT_L              0x01EC
#define RPKT_N_PKT_H              0x01ED
#define RPKT_BYTE_COUNT_L         0x01EE
#define RPKT_BYTE_COUNT_H         0x01EF
#define RPKT_STATUS2              0x01F0
#define RPKT_STATUS3              0x01F1
#define RPKT_STATUS_VECTOR_LEN         6
/* }}} */

/* }}} */
/*******************************************************************************
 * Miscellaneous {{{
 ******************************************************************************/
/* EtherType Protocol */
#define ETHER_TYPE_LEN         0x05DC /* Equal or smaller to this, then is a length */
#define ETHER_TYPE_IPV4        0x0800
#define ETHER_TYPE_ARP         0x0806
#define ETHER_TYPE_WAKE_ON_LAN 0x0842
#define ETHER_TYPE_IPV6        0x86DD
/* Error macros */
#define ERR_BIT                                PB0
#define ERR_SET_DDR   sbi _SFR_IO_ADDR(DDRB),  ERR_BIT
#define ERR_SET       sbi _SFR_IO_ADDR(PORTB), ERR_BIT
#define ERR_CLR       cbi _SFR_IO_ADDR(PORTB), ERR_BIT
/* IP address sizes */
#define MAC_SIZE_IN_BYTES  6
#define IPV4_SIZE_IN_BYTES 4
/* Own messages */
#define MESSAGE_TYPE_LEN 0x1987
/* Also defined in enc28j60.S */
#define ETH_END_LISTEN_ON_SPI SPI_END_ETH
/* }}} */

#if 0
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
#endif


#endif
