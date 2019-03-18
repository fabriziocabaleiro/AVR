/* This file contains only definitions and constants used globally */
#ifndef _DEFS_H_
#define _DEFS_H_

/*******************************************************************************
 * Global configuration
 ******************************************************************************/
#define F_CPU 1000000 /* Default value of internal RC oscillator */
#define USE_DHT11

/*******************************************************************************
 * Registers
 ******************************************************************************/
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

#pragma GCC poison R16
#pragma GCC poison R17
#pragma GCC poison R18
#pragma GCC poison R19
#pragma GCC poison R20
#pragma GCC poison R21
#pragma GCC poison R22
/*******************************************************************************
 * SPI Slave selection
 ******************************************************************************/
#define SPI_SS_ETH       PB1
#define SPI_SS_LCD       PB2
#define SPI_SELECT_LCD   cbi _SFR_IO_ADDR(PORTB), SPI_SS_LCD
#define SPI_SELECT_ETH   cbi _SFR_IO_ADDR(PORTB), SPI_SS_ETH
#define SPI_END_LCD      sbi _SFR_IO_ADDR(PORTB), SPI_SS_LCD
#define SPI_END_ETH      sbi _SFR_IO_ADDR(PORTB), SPI_SS_ETH

/*******************************************************************************
 * EEPROM variables
 ******************************************************************************/
// #define EEPROM_MAC_ADDR                0x0000 /* [0x0000, 0x0005] */
// #define EEPROM_IP_ADDR                 0x0006 /* [0x0006, 0x0009] */
// #define EEPROM_MAC_DEBUG               0x000A /* [0x000A, 0x000F] */
// #define EEPROM_IP_HEADER               0x0010 /* [0x0010, 0x0019] */
/* Only storing 10 bytes of 20, missing checksum and IP addrs */
#define EEPROM_IP_HEADER_LEN_TIL_CHK_SUM   10
#define EEPROM_IP_HEADER_LEN               20

// #define EEPROM_DHCP_HEADER             0x0024
#define EEPROM_DHCP_HEADER_LEN              8

// #define EEPROM_DHCP_MAGIC_COOKIE       0x002C
#define EEPROM_DHCP_MAGIC_COOKIE_LEN        4

// #define EEPROM_DEBUG                   0x0040

/*******************************************************************************
 * SRAM variables
 ******************************************************************************/
/* Receive packet header */
#define RPKT_N_PKT_L            0x0060
#define RPKT_N_PKT_H            0x0061
#define RPKT_BYTE_COUNT_L       0x0062
#define RPKT_BYTE_COUNT_H       0x0063
#define RPKT_STATUS2            0x0064
#define RPKT_STATUS3            0x0065
#define RPKT_STATUS_VECTOR_LEN       6

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


/*******************************************************************************
 * Miscellaneous
 ******************************************************************************/
#define ERR_ARP_ERR_BIT   PB0
#define ERR_ARP_SET_DDR   sbi _SFR_IO_ADDR(DDRB),  ERR_ARP_ERR_BIT
#define ERR_ARP_SET_ERROR sbi _SFR_IO_ADDR(PORTB), ERR_ARP_ERR_BIT
#define ERR_ETH_SET_ERROR sbi _SFR_IO_ADDR(PORTB), ERR_ARP_ERR_BIT
#define ERR_ARP_CLR_ERROR cbi _SFR_IO_ADDR(PORTB), ERR_ARP_ERR_BIT

#define MAC_SIZE_IN_BYTES  6
#define IPV4_SIZE_IN_BYTES 4

/* Own messages */
#define MESSAGE_TYPE_LEN 0x1987

/* Also defined in enc28j60.S */
#define ETH_END_LISTEN_ON_SPI SPI_END_ETH

/* Ethernet type from wikipedia {{{ */
// EtherType Protocol
#define ETHER_TYPE_LEN   0x05DC /* Equal or smaller to this, then is a length */
#define ETHER_TYPE_IPV4  0x0800 /* Internet Protocol version 4 (IPv4) */
#define ETHER_TYPE_ARP   0x0806 /* Address Resolution Protocol (ARP)  */
#if 0
0x0842 Wake-on-LAN[9]
0x22F3 IETF TRILL Protocol
0x22EA Stream Reservation Protocol
0x6003 DECnet Phase IV
0x8035 Reverse Address Resolution Protocol
0x809B AppleTalk (Ethertalk)
0x80F3 AppleTalk Address Resolution Protocol (AARP)
0x8100 VLAN-tagged frame (IEEE 802.1Q) and Shortest Path Bridging IEEE 802.1aq with NNI compatibility[10]
0x8137 IPX
0x8204 QNX Qnet
0x86DD Internet Protocol Version 6 (IPv6)
0x8808 Ethernet flow control
0x8809 Ethernet Slow Protocols[11] such as the Link Aggregation Control Protocol
0x8819 CobraNet
0x8847 MPLS unicast
0x8848 MPLS multicast
0x8863 PPPoE Discovery Stage
0x8864 PPPoE Session Stage
0x886D Intel Advanced Networking Services [12]
0x8870 Jumbo Frames (Obsoleted draft-ietf-isis-ext-eth-01)
0x887B HomePlug 1.0 MME
0x888E EAP over LAN (IEEE 802.1X)
0x8892 PROFINET Protocol
0x889A HyperSCSI (SCSI over Ethernet)
0x88A2 ATA over Ethernet
0x88A4 EtherCAT Protocol
0x88A8 Provider Bridging (IEEE 802.1ad) & Shortest Path Bridging IEEE 802.1aq[10]
0x88AB Ethernet Powerlink[citation needed]
0x88B8 GOOSE (Generic Object Oriented Substation event)
0x88B9 GSE (Generic Substation Events) Management Services
0x88BA SV (Sampled Value Transmission)
0x88CC Link Layer Discovery Protocol (LLDP)
0x88CD SERCOS III
0x88DC WSMP, WAVE Short Message Protocol
0x88E1 HomePlug AV MME[citation needed]
0x88E3 Media Redundancy Protocol (IEC62439-2)
0x88E5 MAC security (IEEE 802.1AE)
0x88E7 Provider Backbone Bridges (PBB) (IEEE 802.1ah)
0x88F7 Precision Time Protocol (PTP) over Ethernet (IEEE 1588)
0x88F8 NC-SI
0x88FB Parallel Redundancy Protocol (PRP)
0x8902 IEEE 802.1ag Connectivity Fault Management (CFM) Protocol / ITU-T Recommendation Y.1731 (OAM)
0x8906 Fibre Channel over Ethernet (FCoE)
0x8914 FCoE Initialization Protocol
0x8915 RDMA over Converged Ethernet (RoCE)
0x891D TTEthernet Protocol Control Frame (TTE)
0x892F High-availability Seamless Redundancy (HSR)
0x9000 Ethernet Configuration Testing Protocol[13]
0x9100 VLAN-tagged (IEEE 802.1Q) frame with double tagging
#endif
/* }}} */

#endif
