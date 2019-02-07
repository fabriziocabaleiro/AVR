/* This file contains only definitions and constants used globally */
#ifndef __DEFS_H__
#define __DEFS_H__

/*******************************************************************************
 * Registers
 ******************************************************************************/
#define MAIN_COUNTER_REG R16
#define TMP1             R17
#define ARG_REG1         R18
#define ARG_REG2         R19
#define RETURN_VALUE     R20

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
 * SRAM variables
 ******************************************************************************/
#define EEPROM_MAC_ADDR   0x0000
#define EEPROM_IP_ADDR    0x0006
#define EEPROM_MAC_DEBUG  0x000A
#define EEPROM_RECEIVE_STATUS_VECTOR_ERROR 0x001A /* holds 6 bytes TODO: get correct address for it */

/* Receive packet header */
#define RPKT_N_PKT_L      0x0060
#define RPKT_N_PKT_H      0x0061
#define RPKT_BYTE_COUNT_L 0x0062
#define RPKT_BYTE_COUNT_H 0x0063
#define RPKT_STATUS2      0x0065
#define RPKT_STATUS3      0x0066

/* Pending packages to process */
#define RPKT_PENDING_CNT  0x0067

/* Mac addresses */
#define ETH_HEADER        0x0068
#define MAC_ADDR_MYSELF   ETH_HEADER
#define MAC_ADDR_OTHER    0x006E
#define TYPE_LEN_H        0x0074
#define TYPE_LEN_L        0x0075

#define IP_ADDR_0         0x0076
#define IP_ADDR_1         0x0077
#define IP_ADDR_2         0x0078
#define IP_ADDR_3         0x0079

#define ARP_PAYLOAD       0x007A /* Need 28 bytes, next available memory: 0x96 */
#define ARP_PAYLOAD_LEN       28

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

#define IPV4_HEADER                      0x15E /* Max header size 15 * 4 = 60  therefore next available address 0x19A*/
#define IPV4_PAYLOAD                     0x19A /* Next available address 0x262 */
#define IPV4_PAYLOAD_LEN                   200

/*******************************************************************************
 * Miscellaneous
 ******************************************************************************/
#define ERR_ARP_ERR_BIT   PB0
#define ERR_ARP_SET_DDR   sbi _SFR_IO_ADDR(DDRB), ERR_ARP_ERR_BIT
#define ERR_ARP_SET_ERROR sbi _SFR_IO_ADDR(PORTB), ERR_ARP_ERR_BIT
#define ERR_ETH_SET_ERROR sbi _SFR_IO_ADDR(PORTB), ERR_ARP_ERR_BIT
#define ERR_ARP_CLR_ERROR cbi _SFR_IO_ADDR(PORTB), ERR_ARP_ERR_BIT

#define MAC_SIZE_IN_BYTES  6
#define IPV4_SIZE_IN_BYTES 4

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

/*******************************************************************************
 *
 ******************************************************************************/
DELAY_TMP:
    push R16
    push R17
    ldi  R17, 4
DELAY_TMP_W2:
    ldi  R16, 250
DELAY_TMP_W1:
    dec  R16
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    brne DELAY_TMP_W1
    dec  R17
    brne DELAY_TMP_W2
    pop  R17
    pop  R16
    ret

MAIN_WRITE_TO_LCD_AS_HEX:
    push TMP1
    push ARG_REG1
    push RETURN_VALUE
    set /* control the twice "loop", set T */
lcd_write_reg_as_hex_twice:
    swap ARG_REG1 /* higher part first */
    mov  TMP1, ARG_REG1
    andi TMP1, 0x0F
    cpi  TMP1, 0x0A
    brge lcd_write_reg_as_hex_over_9
    ori  TMP1, 0x30
    rjmp lcd_write_reg_as_hex_write
lcd_write_reg_as_hex_over_9:
    ori  TMP1, 0x40
    subi TMP1, 0x09
lcd_write_reg_as_hex_write:
    push ARG_REG1
    mov  ARG_REG1, TMP1
    SPI_SELECT_LCD
    rcall SPI_MASTER_TRANSMIT
    pop  ARG_REG1
    brtc  lcd_write_reg_as_hex_end /* end if T == 0 */
    clt   /* clear T */
    rjmp  lcd_write_reg_as_hex_twice
lcd_write_reg_as_hex_end:
    pop  RETURN_VALUE
    pop  ARG_REG1
    pop  TMP1
    ret

.macro  PRINT_REG bsel1 bsel0 reg
ldi   ARG_REG1, 0x1F
ldi   ARG_REG2, 0x3
rcall ETH_BIT_FIELD_CLEAR
ldi   ARG_REG1, 0x1F
ldi   ARG_REG2, \bsel1 | \bsel0
rcall ETH_BIT_FIELD_SET
ldi   ARG_REG1, \reg
rcall ETH_READ_CONTROL_REGISTER
mov   ARG_REG1, RETURN_VALUE
rcall MAIN_WRITE_TO_LCD_AS_HEX
.endm

.macro PRINT val
    push  ARG_REG1
    push  RETURN_VALUE
    ldi   ARG_REG1, \val
    SPI_SELECT_LCD
    rcall SPI_MASTER_TRANSMIT
    pop   RETURN_VALUE
    pop   ARG_REG1
.endm

#endif
