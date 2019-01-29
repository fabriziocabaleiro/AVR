/* vim: set filetype=S:set foldmethod=marker: */
#include "spi.S"
#ifndef __ENC28J60_S__
#define __ENC28J60_S__

/* Ethernet type from wikipedia {{{ */
// EtherType Protocol
#define ETHER_TYPE_IPV4_H 0x08 /* Internet Protocol version 4 (IPv4) */
#define ETHER_TYPE_IPV4_L 0x00 /* Internet Protocol version 4 (IPv4) */
#define ETHER_TYPE_ARP_H  0x08 /* Address Resolution Protocol (ARP)  */
#define ETHER_TYPE_ARP_L  0x06 /* Address Resolution Protocol (ARP)  */
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

/* Receive status vector {{{ */
// TODO: REMOVE DUPLICATED
/* In SRAM:
 * #define RPKT_STATUS2      0x65
 * #define RPKT_STATUS3      0x66
 */

/* RPKT_STATUS3 bits */
// zero
#define STATUS3_VLAN_TYPE                   6
#define STATUS3_RECEIVE_UNKNOWN_OPCODE      5
#define STATUS3_RECEIVE_PAUSE_CONTROL_FRAME 4
#define STATUS3_RECEIVE_CONTROL_FRAME       3
#define STATUS3_DRIBBLE_NIBBLE              2
#define STATUS3_RECEIVE_BROADCAST_PACKET    1
#define STATUS3_RECEIVE_MULTICAST_PACKET    0

/* RPKT_STATUS2 bits */
#define STATUS2_RECEIVED_OK                    7
#define STATUS2_LENGTH_OUT_OF_RANGE            6
#define STATUS2_LENGTH_CHECK_ERROR             5
#define STATUS2_CRC_ERROR                      4
// RESERVED                                    3
#define STATUS2_CARRIER_EVENT_PREVIOUSLY_SEEN  2
// RESERVED                                    1
#define STATUS2_LONG_EVENT_DROP_EVENT          0

/* }}} */

/* Extract from datasheet {{{ */
#if 0
EIE                 INTIE       PKTIE       DMAIE          LINKIE        TXIE           r        TXERIE      RXERIE       0000 0000
EIR                  —          PKTIF       DMAIF          LINKIF        TXIF           r        TXERIF       RXERIF      -000 0000
ESTAT                INT       BUFER              r       LATECOL         —         RXBUSY       TXABRT     CLKRDY(1)     0000 -000
ECON2             AUTOINC      PKTDEC       PWRSV             r         VRPS           —            —           —         1000 0---
ECON1              TXRST       RXRST        DMAST         CSUMEN        TXRTS        RXEN        BSEL1        BSEL0       0000 0000
ERDPTL           Read Pointer Low Byte ERDPT<7:0>)                                                                        1111 1010
ERDPTH               —            —              —       Read Pointer High Byte (ERDPT<12:8>)                             ---0 0101
EWRPTL           Write Pointer Low Byte (EWRPT<7:0>)                                                                      0000 0000
EWRPTH               —            —              —       Write Pointer High Byte (EWRPT<12:8>)                            ---0 0000
ETXSTL           TX Start Low Byte (ETXST<7:0>)                                                                           0000 0000
ETXSTH               —            —              —       TX Start High Byte (ETXST<12:8>)                                 ---0 0000
ETXNDL           TX End Low Byte (ETXND<7:0>)                                                                             0000 0000
ETXNDH               —            —              —       TX End High Byte (ETXND<12:8>)                                   ---0 0000
ERXSTL           RX Start Low Byte (ERXST<7:0>)                                                                           1111 1010
ERXSTH               —            —              —       RX Start High Byte (ERXST<12:8>)                                 ---0 0101
ERXNDL           RX End Low Byte (ERXND<7:0>)                                                                             1111 1111
ERXNDH               —            —              —       RX End High Byte (ERXND<12:8>)                                   ---1 1111
ERXRDPTL         RX RD Pointer Low Byte (ERXRDPT<7:0>)                                                                    1111 1010
ERXRDPTH             —            —              —       RX RD Pointer High Byte (ERXRDPT<12:8>)                          ---0 0101
ERXWRPTL         RX WR Pointer Low Byte (ERXWRPT<7:0>)                                                                    0000 0000
ERXWRPTH             —            —              —       RX WR Pointer High Byte (ERXWRPT<12:8>)                          ---0 0000
EDMASTL          DMA Start Low Byte (EDMAST<7:0>)                                                                         0000 0000
EDMASTH              —            —              —       DMA Start High Byte (EDMAST<12:8>)                               ---0 0000
EDMANDL          DMA End Low Byte (EDMAND<7:0>)                                                                           0000 0000
EDMANDH              —            —              —       DMA End High Byte (EDMAND<12:8>)                                 ---0 0000
EDMADSTL         DMA Destination Low Byte (EDMADST<7:0>)                                                                  0000 0000
EDMADSTH             —            —              —       DMA Destination High Byte (EDMADST<12:8>)                        ---0 0000
EDMACSL          DMA Checksum Low Byte (EDMACS<7:0>)                                                                      0000 0000
EDMACSH          DMA Checksum High Byte (EDMACS<15:8>)                                                                    0000 0000
EHT0             Hash Table Byte 0 (EHT<7:0>)                                                                             0000 0000
EHT1             Hash Table Byte 1 (EHT<15:8>)                                                                            0000 0000
EHT2             Hash Table Byte 2 (EHT<23:16>)                                                                           0000 0000
EHT3             Hash Table Byte 3 (EHT<31:24>)                                                                           0000 0000
EHT4             Hash Table Byte 4 (EHT<39:32>)                                                                           0000 0000
EHT5             Hash Table Byte 5 (EHT<47:40>)                                                                           0000 0000
EHT6             Hash Table Byte 6 (EHT<55:48>)                                                                           0000 0000
EHT7             Hash Table Byte 7 (EHT<63:56>)                                                                           0000 0000
EPMM0            Pattern Match Mask Byte 0 (EPMM<7:0>)                                                                    0000 0000
EPMM1            Pattern Match Mask Byte 1 (EPMM<15:8>)                                                                   0000 0000
EPMM2            Pattern Match Mask Byte 2 (EPMM<23:16>)                                                                  0000 0000
EPMM3            Pattern Match Mask Byte 3 (EPMM<31:24>)                                                                  0000 0000
EPMM4            Pattern Match Mask Byte 4 (EPMM<39:32>)                                                                  0000 0000
EPMM5            Pattern Match Mask Byte 5 (EPMM<47:40>)                                                                  0000 0000
EPMM6            Pattern Match Mask Byte 6 (EPMM<55:48>)                                                                  0000 0000
EPMM7            Pattern Match Mask Byte 7 (EPMM<63:56>)                                                                  0000 0000
Legend:    x = unknown, u = unchanged, - = unimplemented, q = value depends on condition, r = reserved, do not modify.
Note 1:    CLKRDY resets to ‘0’ on Power-on Reset but is unaffected on all other Resets.
      2:   EREVID is a read-only register.
      3:   ECOCON resets to ‘---- -100’ on Power-on Reset and ‘---- -uuu’ on all other Resets.

EPMCSL          Pattern Match Checksum Low Byte (EPMCS<7:0>)                                                              0000 0000     51
EPMCSH          Pattern Match Checksum High Byte (EPMCS<15:0>)                                                            0000 0000     51
EPMOL           Pattern Match Offset Low Byte (EPMO<7:0>)                                                                 0000 0000     51
EPMOH                —            —             —        Pattern Match Offset High Byte (EPMO<12:8>)                      ---0 0000     51
ERXFCON            UCEN        ANDOR         CRCEN            PMEN       MPEN        HTEN         MCEN           BCEN     1010 0001     48
EPKTCNT         Ethernet Packet Count                                                                                     0000 0000     43
MACON1               —            —             —               r       TXPAUS      RXPAUS       PASSALL        MARXEN    ---0 0000     34
MACON3           PADCFG2      PADCFG1       PADCFG0          TXCRCEN    PHDREN     HFRMEN       FRMLNEN         FULDPX    0000 0000     35
MACON4               —          DEFER         BPEN           NOBKOFF       —           —               r           r      -000 --00     36
MABBIPG              —       Back-to-Back Inter-Packet Gap (BBIPG<6:0>)                                                   -000 0000     36
MAIPGL               —       Non-Back-to-Back Inter-Packet Gap Low Byte (MAIPGL<6:0>)                                     -000 0000     34
MAIPGH               —       Non-Back-to-Back Inter-Packet Gap High Byte (MAIPGH<6:0>)                                    -000 0000     34
MACLCON1             —            —             —              —       Retransmission Maximum (RETMAX<3:0>)               ---- 1111     34
MACLCON2             —            —        Collision Window (COLWIN<5:0>)                                                 --11 0111     34
MAMXFLL         Maximum Frame Length Low Byte (MAMXFL<7:0>)                                                               0000 0000     34
MAMXFLH         Maximum Frame Length High Byte (MAMXFL<15:8>)                                                             0000 0110     34
MICMD                —            —             —              —           —           —         MIISCAN         MIIRD    ---- --00     21
MIREGADR             —            —             —        MII Register Address (MIREGADR<4:0>)                             ---0 0000     19
MIWRL           MII Write Data Low Byte (MIWR<7:0>)                                                                       0000 0000     19
MIWRH           MII Write Data High Byte (MIWR<15:8>)                                                                     0000 0000     19
MIRDL           MII Read Data Low Byte (MIRD<7:0>)                                                                        0000 0000     19
MIRDH           MII Read Data High Byte(MIRD<15:8>)                                                                       0000 0000     19
MAADR5          MAC Address Byte 5 (MAADR<15:8>)                                                                          0000 0000     34
MAADR6          MAC Address Byte 6 (MAADR<7:0>)                                                                           0000 0000     34
MAADR3          MAC Address Byte 3 (MAADR<31:24>), OUI Byte 3                                                             0000 0000     34
MAADR4          MAC Address Byte 4 (MAADR<23:16>)                                                                         0000 0000     34
MAADR1          MAC Address Byte 1 (MAADR<47:40>), OUI Byte 1                                                             0000 0000     34
MAADR2          MAC Address Byte 2 (MAADR<39:32>), OUI Byte 2                                                             0000 0000     34
EBSTSD          Built-in Self-Test Fill Seed (EBSTSD<7:0>)                                                                0000 0000     76
EBSTCON            PSV2          PSV1         PSV0            PSEL      TMSEL1      TMSEL0         TME          BISTST    0000 0000     75
EBSTCSL         Built-in Self-Test Checksum Low Byte (EBSTCS<7:0>)                                                        0000 0000     76
EBSTCSH         Built-in Self-Test Checksum High Byte (EBSTCS<15:8>)                                                      0000 0000     76
MISTAT               —            —             —              —            r       NVALID        SCAN           BUSY     ---- 0000     21
EREVID (2)           —            —             —        Ethernet Revision ID (EREVID<4:0>)                               ---q qqqq     22
ECOCON (3)           —            —             —              —           —       COCON2        COCON1         COCON0    ---- -100     6
EFLOCON              —            —             —              —           —       FULDPXS        FCEN1         FCEN0     ---- -000     56
EPAUSL          Pause Timer Value Low Byte (EPAUS<7:0>)                                                                   0000 0000     57
EPAUSH          Pause Timer Value High Byte (EPAUS<15:8>)                                                                 0001 0000     57
#endif
/* }}} */

/* Common set of registers {{{ */
/* INTIE PKTIE DMAIE LINKIE TXIE r TXERIE RXERIE 0000 0000 */
#define EIE         0x1B
#define EIE_INTIE   0x80
#define EIE_PKTIE   0x40
#define EIE_DMAIE   0x20
#define EIE_LINKIE  0x10
#define EIE_TXIE    0x08
/* #define EIE_r       0x04 */
#define EIE_TXERIE  0x02
#define EIE_RXERIE  0x01

/* — PKTIF DMAIF LINKIF TXIF r TXERIF RXERIF -000 0000 */
#define EIR         0x1C
//#define -        0x80
#define EIR_PKTIF  0x40
#define EIR_DMAIF  0x20
#define EIR_LINKIF 0x10
#define EIR_TXIF   0x08
#define EIR_r      0x04
#define EIR_TXERIF 0x02
#define EIR_RXERIF 0x01

/* INT BUFER r LATECOL — RXBUSY TXABRT CLKRDY(1) 0000 -000 */
#define ESTAT       0x1D
#define ESTAT_INT      0x80
#define ESTAT_BUFER    0x40
#define ESTAT_r        0x20
#define ESTAT_LATECOL  0x10
//#define ESTAT_—        0x08
#define ESTAT_RXBUSY   0x04
#define ESTAT_TXABRT   0x02
#define ESTAT_CLKRDY   0x01
/* AUTOINC PKTDEC PWRSV r VRPS — — — 1000 0--- */
#define ECON2       0x1E
#define ECON2_AUTOINC    0x80
#define ECON2_PKTDEC     0x40
#define ECON2_PWRSV      0x20
#define ECON2_r          0x10
#define ECON2_VRPS       0x08
/* #define ECON2_—          0x04 */
/* #define ECON2_—          0x02 */
/* #define ECON2_—          0x01 */

/* TXRST RXRST DMAST CSUMEN TXRTS RXEN BSEL1 BSEL0 0000 0000 */
#define ECON1       0x1F
/* ECON1 Fields */
#define ECON1_TXRST       0x80
#define ECON1_RXRST       0x40
#define ECON1_DMAST       0x20
#define ECON1_CSUMEN      0x10
#define ECON1_TXRTS       0x08
#define ECON1_RXEN        0x04
#define ECON1_BSEL1       0x02
#define ECON1_BSEL0       0x01
/* }}} */

/* Control registers in banks 0 - 3 */
/* Bank 0 {{{ */
/* Read Pointer Low Byte ERDPT<7:0>) 1111 1010 */
#define ERDPTL      0x00
/* — — — Read Pointer High Byte (ERDPT<12:8>) ---0 0101 */
#define ERDPTH      0x01
/* Write Pointer Low Byte (EWRPT<7:0>) 0000 0000 */
#define EWRPTL      0x02
/* — — — Write Pointer High Byte (EWRPT<12:8>) ---0 0000 */
#define EWRPTH      0x03
/* TX Start Low Byte (ETXST<7:0>) 0000 0000 */
#define ETXSTL      0x04
/* — — — TX Start High Byte (ETXST<12:8>) ---0 0000 */
#define ETXSTH      0x05
/* TX End Low Byte (ETXND<7:0>) 0000 0000 */
#define ETXNDL      0x06
/* — — — TX End High Byte (ETXND<12:8>) ---0 0000 */
#define ETXNDH      0x07
/* RX Start Low Byte (ERXST<7:0>) 1111 1010 */
#define ERXSTL      0x08
/* — — — RX Start High Byte (ERXST<12:8>) ---0 0101 */
#define ERXSTH      0x09
/* RX End Low Byte (ERXND<7:0>) 1111 1111 */
#define ERXNDL      0x0A
/* — — — RX End High Byte (ERXND<12:8>) ---1 1111 */
#define ERXNDH      0x0B
/* RX RD Pointer Low Byte (ERXRDPT<7:0>) 1111 1010 */
#define ERXRDPTL    0x0C
/* — — — RX RD Pointer High Byte (ERXRDPT<12:8>) ---0 0101 */
#define ERXRDPTH    0x0D
/* RX WR Pointer Low Byte (ERXWRPT<7:0>) 0000 0000 */
#define ERXWRPTL    0x0E
/* — — — RX WR Pointer High Byte (ERXWRPT<12:8>) ---0 0000 */
#define ERXWRPTH    0x0F
/* DMA Start Low Byte (EDMAST<7:0>) 0000 0000 */
#define EDMASTL     0x10
/* — — — DMA Start High Byte (EDMAST<12:8>) ---0 0000 */
#define EDMASTH     0x11
/* DMA End Low Byte (EDMAND<7:0>) 0000 0000 */
#define EDMANDL     0x12
/* — — — DMA End High Byte (EDMAND<12:8>) ---0 0000 */
#define EDMANDH     0x13
/* DMA Destination Low Byte (EDMADST<7:0>) 0000 0000 */
#define EDMADSTL    0x14
/* — — — DMA Destination High Byte (EDMADST<12:8>) ---0 0000 */
#define EDMADSTH    0x15
/* DMA Checksum Low Byte (EDMACS<7:0>) 0000 0000 */
#define EDMACSL     0x16
/* DMA Checksum High Byte (EDMACS<15:8>) 0000 0000 */
#define EDMACSH     0x17
/* - 0x18 */
/* - 0x19 */
/* #define Reserved    0x1A */
/* }}} */

/* Bank 1  {{{ */
/* Hash Table Byte 0 (EHT<7:0>) 0000 0000 */
#define EHT0        0x00
/* Hash Table Byte 1 (EHT<15:8>) 0000 0000 */
#define EHT1        0x01
/* Hash Table Byte 2 (EHT<23:16>) 0000 0000 */
#define EHT2        0x02
/* Hash Table Byte 3 (EHT<31:24>) 0000 0000 */
#define EHT3        0x03
/* Hash Table Byte 4 (EHT<39:32>) 0000 0000 */
#define EHT4        0x04
/* Hash Table Byte 5 (EHT<47:40>) 0000 0000 */
#define EHT5        0x05
/* Hash Table Byte 6 (EHT<55:48>) 0000 0000 */
#define EHT6        0x06
/* Hash Table Byte 7 (EHT<63:56>) 0000 0000 */
#define EHT7        0x07
/* Pattern Match Mask Byte 0 (EPMM<7:0>) 0000 0000 */
#define EPMM0       0x08
/* Pattern Match Mask Byte 1 (EPMM<15:8>) 0000 0000 */
#define EPMM1       0x09
/* Pattern Match Mask Byte 2 (EPMM<23:16>) 0000 0000 */
#define EPMM2       0x0A
/* Pattern Match Mask Byte 3 (EPMM<31:24>) 0000 0000 */
#define EPMM3       0x0B
/* Pattern Match Mask Byte 4 (EPMM<39:32>) 0000 0000 */
#define EPMM4       0x0C
/* Pattern Match Mask Byte 5 (EPMM<47:40>) 0000 0000 */
#define EPMM5       0x0D
/* Pattern Match Mask Byte 6 (EPMM<55:48>) 0000 0000 */
#define EPMM6       0x0E
/* Pattern Match Mask Byte 7 (EPMM<63:56>) 0000 0000 */
#define EPMM7       0x0F
/* Pattern Match Checksum Low Byte (EPMCS<7:0>) 0000 0000 */
#define EPMCSL      0x10
/* Pattern Match Checksum High Byte (EPMCS<15:0>) 0000 0000 */
#define EPMCSH      0x11
/* - 0x12 */
/* - 0x13 */
/* Pattern Match Offset Low Byte (EPMO<7:0>) 0000 0000 51 */
#define EPMOL       0x14
/* — — — Pattern Match Offset High Byte (EPMO<12:8>) ---0 0000 51 */
#define EPMOH       0x15
/* #define Reserved    0x16 */
/* #define Reserved    0x17 */
/* UCEN ANDOR CRCEN PMEN MPEN HTEN MCEN BCEN 1010 0001
 * bit 7        UCEN: Unicast Filter Enable bit
 *              When ANDOR = 1:
 *              1 = Packets not having a destination address matching the local MAC address will be discarded
 *              0 = Filter disabled
 *              When ANDOR = 0:
 *              1 = Packets with a destination address matching the local MAC address will be accepted
 *              0 = Filter disabled
 * bit 6        ANDOR: AND/OR Filter Select bit
 *              1 = AND: Packets will be rejected unless all enabled filters accept the packet
 *              0 = OR: Packets will be accepted unless all enabled filters reject the packet
 * bit 5        CRCEN: Post-Filter CRC Check Enable bit
 *              1 = All packets with an invalid CRC will be discarded
 *              0 = The CRC validity will be ignored
 * bit 4        PMEN: Pattern Match Filter Enable bit
 *              When ANDOR = 1:
 *              1 = Packets must meet the Pattern Match criteria or they will be discarded
 *              0 = Filter disabled
 *              When ANDOR = 0:
 *              1 = Packets which meet the Pattern Match criteria will be accepted
 *              0 = Filter disabled
 * bit 3        MPEN: Magic Packet™ Filter Enable bit
 *              When ANDOR = 1:
 *              1 = Packets must be Magic Packets for the local MAC address or they will be discarded
 *              0 = Filter disabled
 *              When ANDOR = 0:
 *              1 = Magic Packets for the local MAC address will be accepted
 *              0 = Filter disabled
 * bit 2        HTEN: Hash Table Filter Enable bit
 *              When ANDOR = 1:
 *              1 = Packets must meet the Hash Table criteria or they will be discarded
 *              0 = Filter disabled
 *              When ANDOR = 0:
 *              1 = Packets which meet the Hash Table criteria will be accepted
 *              0 = Filter disabled
 * bit 1        MCEN: Multicast Filter Enable bit
 *              When ANDOR = 1:
 *              1 = Packets must have the Least Significant bit set in the destination address or they will be discarded
 *              0 = Filter disabled
 *              When ANDOR = 0:
 *              1 = Packets which have the Least Significant bit set in the destination address will be accepted
 *              0 = Filter disabled
 * bit 0        BCEN: Broadcast Filter Enable bit
 *              When ANDOR = 1:
 *              1 = Packets must have a destination address of FF-FF-FF-FF-FF-FF or they will be discarded
 *              0 = Filter disabled
 *              When ANDOR = 0:
 *              1 = Packets which have a destination address of FF-FF-FF-FF-FF-FF will be accepted
 *              0 = Filter disabled
 */
/* UCEN ANDOR CRCEN PMEN MPEN HTEN MCEN BCEN 1010 0001 48 */
#define ERXFCON     0x18
#define ERXFCON_UCEN   0x80
#define ERXFCON_ANDOR  0x40
#define ERXFCON_CRCEN  0x20
#define ERXFCON_PMEN   0x10
#define ERXFCON_MPEN   0x08
#define ERXFCON_HTEN   0x04
#define ERXFCON_MCEN   0x02
#define ERXFCON_BCEN   0x01
/* Ethernet Packet Count 0000 0000 43 */
#define EPKTCNT     0x19
/* #define Reserved    0x1A */
/* }}} */

/* Bank 2 {{{ */
/* bit 7-5           Unimplemented: Read as ‘0’
 * bit 4             Reserved: Maintain as ‘0’
 * bit 3             TXPAUS: Pause Control Frame Transmission Enable bit
 *                   1 = Allow the MAC to transmit pause control frames (needed for flow control in full duplex)
 *                   0 = Disallow pause frame transmissions
 * bit 2             RXPAUS: Pause Control Frame Reception Enable bit
 *                   1 = Inhibit transmissions when pause control frames are received (normal operation)
 *                   0 = Ignore pause control frames which are received
 * bit 1             PASSALL: Pass All Received Frames Enable bit
 *                   1 = Control frames received by the MAC will be written into the receive buffer if not filtered out
 *                   0 = Control frames will be discarded after being processed by the MAC (normal operation)
 * bit 0             MARXEN: MAC Receive Enable bit
 *                   1 = Enable packets to be received by the MAC
 *                   0 = Disable packet reception
 * — — — r TXPAUS RXPAUS PASSALL MARXEN ---0 0000
 */
#define MACON1      0x00
#define MACON1_TXPAUS   0x08
#define MACON1_RXPAUS   0x04
#define MACON1_PASSALL  0x02
#define MACON1_MARXEN   0x01
/* #define Reserved    0x01 */
/* bit 7-5         PADCFG2:PADCFG0: Automatic Pad and CRC Configuration bits
 *                 111 = All short frames will be zero padded to 64 bytes and a valid CRC will then be appended
 *                 110 = No automatic padding of short frames
 *                 101 = MAC will automatically detect VLAN Protocol frames which have a 8100h type field and auto-
 *                       matically pad to 64 bytes. If the frame is not a VLAN frame, it will be padded to 60 bytes. After
 *                       padding, a valid CRC will be appended.
 *                 100 = No automatic padding of short frames
 *                 011 = All short frames will be zero padded to 64 bytes and a valid CRC will then be appended
 *                 010 = No automatic padding of short frames
 *                 001 = All short frames will be zero padded to 60 bytes and a valid CRC will then be appended
 *                 000 = No automatic padding of short frames
 * bit 4           TXCRCEN: Transmit CRC Enable bit
 *                 1 = MAC will append a valid CRC to all frames transmitted regardless of PADCFG bits. TXCRCEN
 *                     must be set if the PADCFG bits specify that a valid CRC will be appended.
 *                 0 = MAC will not append a CRC. The last 4 bytes will be checked and if it is an invalid CRC, it will be
 *                     reported in the transmit status vector.
 * bit 3           PHDREN: Proprietary Header Enable bit
 *                 1 = Frames presented to the MAC contain a 4-byte proprietary header which will not be used when
 *                     calculating the CRC
 *                 0 = No proprietary header is present. The CRC will cover all data (normal operation).
 * bit 2           HFRMEN: Huge Frame Enable bit
 *                 1 = Frames of any size will be allowed to be transmitted and received
 *                 0 = Frames bigger than MAMXFL will be aborted when transmitted or received
 * bit 1           FRMLNEN: Frame Length Checking Enable bit
 *                 1 = The type/length field of transmitted and received frames will be checked. If it represents a length, the
 *                     frame size will be compared and mismatches will be reported in the transmit/receive status vector.
 *                 0 = Frame lengths will not be compared with the type/length field
 * bit 0           FULDPX: MAC Full-Duplex Enable bit
 *                 1 = MAC will operate in Full-Duplex mode. PDPXMD bit must also be set.
 *                 0 = MAC will operate in Half-Duplex mode. PDPXMD bit must also be clear.
 * PADCFG2 PADCFG1 PADCFG0 TXCRCEN PHDREN HFRMEN FRMLNEN FULDPX 0000 0000
 */
#define MACON3      0x02
#define MACON3_PADCFG2   0x80
#define MACON3_PADCFG1   0x40
#define MACON3_PADCFG0   0x20
#define MACON3_TXCRCEN   0x10
#define MACON3_PHDREN    0x08
#define MACON3_HFRMEN    0x04
#define MACON3_FRMLNEN   0x02
#define MACON3_FULDPX    0x01

/* bit 7         Unimplemented: Read as ‘0’
 * bit 6         DEFER: Defer Transmission Enable bit (applies to half duplex only)
 *               1 = When the medium is occupied, the MAC will wait indefinitely for it to become free when attempting
 *                   to transmit (use this setting for IEEE 802.3™ compliance)
 *               0 = When the medium is occupied, the MAC will abort the transmission after the excessive deferral
 *                   limit is reached
 * bit 5         BPEN: No Backoff During Backpressure Enable bit (applies to half duplex only)
 *               1 = After incidentally causing a collision during backpressure, the MAC will immediately begin
 *                   retransmitting
 *               0 = After incidentally causing a collision during backpressure, the MAC will delay using the Binary
 *                   Exponential Backoff algorithm before attempting to retransmit (normal operation)
 * bit 4         NOBKOFF: No Backoff Enable bit (applies to half duplex only)
 *               1 = After any collision, the MAC will immediately begin retransmitting
 *               0 = After any collision, the MAC will delay using the Binary Exponential Backoff algorithm before
 *                   attempting to retransmit (normal operation)
 * bit 3-2       Unimplemented: Read as ‘0’
 * bit 1-0       Reserved: Maintain as ‘0’
 * — DEFER BPEN NOBKOFF — — r r -000 --00
 */
#define MACON4      0x03
#define MACON4_DEFER 0x40
/* — Back-to-Back Inter-Packet Gap (BBIPG<6:0>) -000 0000 36 */
#define MABBIPG     0x04
/* - 0x05 */
/* — Non-Back-to-Back Inter-Packet Gap Low Byte (MAIPGL<6:0>) -000 0000 34 */
#define MAIPGL      0x06
/* — Non-Back-to-Back Inter-Packet Gap High Byte (MAIPGH<6:0>) -000 0000 34 */
#define MAIPGH      0x07
/* — — — — Retransmission Maximum (RETMAX<3:0>) ---- 1111 34 */
#define MACLCON1    0x08
/* — — Collision Window (COLWIN<5:0>) --11 0111 34 */
#define MACLCON2    0x09
/* Maximum Frame Length Low Byte (MAMXFL<7:0>) 0000 0000 */
#define MAMXFLL     0x0A
/* Maximum Frame Length High Byte (MAMXFL<15:8>) 0000 0110 */
#define MAMXFLH     0x0B
/* #define Reserved    0x0C */
/* #define Reserved    0x0D */
/* #define Reserved    0x0E */
/* - 0x0F */
/* #define Reserved    0x10 */
/* #define Reserved    0x11 */
/* — — — — — — MIISCAN MIIRD ---- --00 21 */
#define MICMD       0x12
/* - 0x13 */
/* — — — MII Register Address (MIREGADR<4:0>) ---0 0000 19 */
#define MIREGADR    0x14
/* #define Reserved    0x15 */
/* MII Write Data Low Byte (MIWR<7:0>) 0000 0000 19 */
#define MIWRL       0x16
/* MII Write Data High Byte (MIWR<15:8>) 0000 0000 19 */
#define MIWRH       0x17
/* MII Read Data Low Byte (MIRD<7:0>) 0000 0000 19 */
#define MIRDL       0x18
/* MII Read Data High Byte(MIRD<15:8>) 0000 0000 19 */
#define MIRDH       0x19
/* #define Reserved    0x1A */
/* }}} */

/* Bank 3 {{{ */
/* MAC Address Byte 5 (MAADR<15:8>) 0000 0000 34 */
#define MAADR5      0x00
/* MAC Address Byte 6 (MAADR<7:0>) 0000 0000 34 */
#define MAADR6      0x01
/* MAC Address Byte 3 (MAADR<31:24>), OUI Byte 3 0000 0000 34 */
#define MAADR3      0x02
/* MAC Address Byte 4 (MAADR<23:16>) 0000 0000 34 */
#define MAADR4      0x03
/* MAC Address Byte 1 (MAADR<47:40>), OUI Byte 1 0000 0000 34 */
#define MAADR1      0x04
/* MAC Address Byte 2 (MAADR<39:32>), OUI Byte 2 0000 0000 34 */
#define MAADR2      0x05
/* Built-in Self-Test Fill Seed (EBSTSD<7:0>) 0000 0000 76 */
#define EBSTSD      0x06
/* PSV2 PSV1 PSV0 PSEL TMSEL1 TMSEL0 TME BISTST 0000 0000 75 */
#define EBSTCON     0x07
/* Built-in Self-Test Checksum Low Byte (EBSTCS<7:0>) 0000 0000 76 */
#define EBSTCSL     0x08
/* Built-in Self-Test Checksum High Byte (EBSTCS<15:8>) 0000 0000 76 */
#define EBSTCSH     0x09
/* — — — — r NVALID SCAN BUSY ---- 0000 21 */
#define MISTAT      0x0A
/* - 0x0B */
/* - 0x0C */
/* - 0x0D */
/* - 0x0E */
/* - 0x0F */
/* - 0x10 */
/* - 0x11 */
/* (2) — — — Ethernet Revision ID (EREVID<4:0>) ---q qqqq 22 */
#define EREVID      0x12
/* - 0x13 */
/* - 0x14 */
/* (3) — — — — — COCON2 COCON1 COCON0 ---- -100 6 */
#define ECOCON      0x15
/* #define Reserved    0x16 */
/* — — — — — FULDPXS FCEN1 FCEN0 ---- -000 56 */
#define EFLOCON     0x17
/* Pause Timer Value Low Byte (EPAUS<7:0>) 0000 0000 57 */
#define EPAUSL      0x18
#define EPAUSH      0x19
/* #define Reserved    0x1A */
/* }}} */

/*******************************************************************************
 * To read a control register first we send the command "000" together with the
 * address of the register, i.e. "000AAAAA" through SPI, ignoring the byte that
 * is being transmitted during the command + address transmission, then, we send
 * a dummy message to activate the SCK and read a byte.
 ******************************************************************************/
ETH_READ_CONTROL_REGISTER:
   SPI_SELECT_ETH
   rcall SPI_MASTER_TRANSMIT
   rcall SPI_MASTER_TRANSMIT
   SPI_END_ETH
   ret

/*******************************************************************************
 * Send command and address together, then send the new value of the space that
 * the address is pointing to
 ******************************************************************************/
ETH_WRITE_CONTROL_REGISTER:
   mov SPI_DATA, ARG_REG1
   /* command is 010AAAAA, then corresponding prefix */
   sbr SPI_DATA, 0x40
   SPI_SELECT_ETH
   rcall SPI_MASTER_TRANSMIT
   mov SPI_DATA, ARG_REG2
   rcall SPI_MASTER_TRANSMIT
   SPI_END_ETH
   ret

/*******************************************************************************
 * Set the given bits into the register
 * Inputs:
 * - ARG_REG1: Register address
 * - ARG_REG2: Mask with bits that are going to be set
 ******************************************************************************/
ETH_BIT_FIELD_SET:
   mov SPI_DATA, ARG_REG1
   /* command is 100AAAAA, then corresponding prefix */
   sbr SPI_DATA, 0x80
   SPI_SELECT_ETH
   rcall SPI_MASTER_TRANSMIT
   mov SPI_DATA, ARG_REG2
   rcall SPI_MASTER_TRANSMIT
   SPI_END_ETH
   ret

/*******************************************************************************
 * Clear the given bits into the register
 * Inputs:
 * - ARG_REG1: Register address
 * - ARG_REG2: Mask with bits that are going to be clear
 ******************************************************************************/
ETH_BIT_FIELD_CLEAR:
   mov   SPI_DATA, ARG_REG1
   /* command is 101AAAAA, then corresponding prefix */
   sbr   SPI_DATA, 0xA0
   SPI_SELECT_ETH
   rcall SPI_MASTER_TRANSMIT
   mov   SPI_DATA, ARG_REG2
   rcall SPI_MASTER_TRANSMIT
   SPI_END_ETH
   ret

/*******************************************************************************
 * Enable packet reception
 ******************************************************************************/
ETH_ENABLE_RECEIVE:
   ldi   ARG_REG1, ECON1
   ldi   ARG_REG2, ECON1_RXEN
   rcall ETH_BIT_FIELD_SET
   ret

/*******************************************************************************
 * Enable interrupts, TODO: add more info
 ******************************************************************************/
ETH_ENABLE_RECEIVE_INTERRUPT:
   ldi   ARG_REG1, EIE
   ldi   ARG_REG2, EIE_INTIE | EIE_PKTIE
   rcall ETH_BIT_FIELD_SET
   ret

/*******************************************************************************
 * Software reset
 ******************************************************************************/
ETH_SOFTWARE_RESET:
   ldi SPI_DATA, 0xFF
   SPI_SELECT_ETH
   rcall SPI_MASTER_TRANSMIT
   SPI_END_ETH
   ret

/*******************************************************************************
 * Buffer initialization
 ******************************************************************************/
#define BUF_TX_ST_L 0x00
#define BUF_TX_ST_H 0x00
#define BUF_TX_ND_L 0xF0
#define BUF_TX_ND_H 0x0F

/* After the transmit buffer, the system writes 7 bytes of status vector */
#define BUF_RX_ST_L (BUF_TX_ND_L + 0x8)
#define BUF_RX_ST_H BUF_TX_ND_H
#define BUF_RX_ND_L 0xFE
#define BUF_RX_ND_H 0x1F
ETH_BUFFER_INIT:
   /* SET BANK 0 */
   ldi   ARG_REG1, ECON1
   ldi   ARG_REG2, ECON1_BSEL0 | ECON1_BSEL1
   rcall ETH_BIT_FIELD_CLEAR

   /* Memory in range [ERXST, ERXND] dedicated to receive HW */
   /* ERXST 13 bits, need to program: (recommended even number) */
   /* ERXND 13 bits, need to program: */

   /* Setting transmission to [0:0x1AFF] and Receive to 0x1F00 */

   /* Transmit start */
   ldi ARG_REG1, ETXSTL
   ldi ARG_REG2, BUF_TX_ST_L
   rcall ETH_WRITE_CONTROL_REGISTER
   ldi ARG_REG1, ETXSTH
   ldi ARG_REG2, BUF_TX_ST_H
   rcall ETH_WRITE_CONTROL_REGISTER

   /* Transmit end */
   ldi ARG_REG1, ETXNDL
   ldi ARG_REG2, BUF_TX_ND_L
   rcall ETH_WRITE_CONTROL_REGISTER
   ldi ARG_REG1, ETXNDH
   ldi ARG_REG2, BUF_TX_ND_H
   rcall ETH_WRITE_CONTROL_REGISTER

   /* JUST NEED 7 BYTES FOR STATUS VECTOR BETWEEN TRANSMIT AND RECEIVE */
   /* Receive start */
   ldi ARG_REG1, ERXSTL
   ldi ARG_REG2, BUF_RX_ST_L
   rcall ETH_WRITE_CONTROL_REGISTER
   ldi ARG_REG1, ERXSTH
   ldi ARG_REG2, BUF_RX_ST_H
   rcall ETH_WRITE_CONTROL_REGISTER

   /* Programming ERXRDPTx to the same value than ERXSTx */
   ldi ARG_REG1, ERXRDPTL
   ldi ARG_REG2, BUF_RX_ST_L
   rcall ETH_WRITE_CONTROL_REGISTER
   ldi ARG_REG1, ERXRDPTH
   ldi ARG_REG2, BUF_RX_ST_H
   rcall ETH_WRITE_CONTROL_REGISTER

   /* Programming ERDPT (read point for RBM) to the start of receive area */
   ldi ARG_REG1, ERDPTL
   ldi ARG_REG2, BUF_RX_ST_L
   rcall ETH_WRITE_CONTROL_REGISTER
   ldi ARG_REG1, ERDPTH
   ldi ARG_REG2, BUF_RX_ST_H
   rcall ETH_WRITE_CONTROL_REGISTER

   /* Receive end */
   ldi ARG_REG1, ERXNDL
   ldi ARG_REG2, BUF_RX_ND_L
   rcall ETH_WRITE_CONTROL_REGISTER
   ldi ARG_REG1, ERXNDH
   ldi ARG_REG2, BUF_RX_ND_H
   rcall ETH_WRITE_CONTROL_REGISTER

   /* SET BANK 1 */
   /* filter */
   ldi   ARG_REG1, ECON1
   ldi   ARG_REG2, ECON1_BSEL0
   rcall ETH_BIT_FIELD_SET

   /* Promiscuous mode */
   ldi ARG_REG1, ERXFCON
   ldi ARG_REG2, ERXFCON_UCEN | ERXFCON_CRCEN | ERXFCON_BCEN
   rcall ETH_WRITE_CONTROL_REGISTER

   /* Power-on Reset, the ESTAT.CLKRDY bit should be polled to make certain that
    * enough time
    */
   ret

/*******************************************************************************
 * Mac initialization
 ******************************************************************************/
#ifdef USE_FULL_DUPLEX
#  define MACON1_FULL_DUPLEX   (MACON1_RXPAUS | MACON1_TXPAUS)
#  define MABBIPG_FULL_DUPLEX  0x15
#  define MACON3_FULL_DUPLEX   (MACON3_FULDPX)
#else
#  define MACON1_FULL_DUPLEX   0
#  define MABBIPG_FULL_DUPLEX  0x12
#  define MACON3_FULL_DUPLEX   0
#endif
ETH_MAC_INIT: /* ONLY ONCE */
   /* SET BANK 2 */
   ldi   ARG_REG1, ECON1
   ldi   ARG_REG2, ECON1_BSEL0
   rcall ETH_BIT_FIELD_CLEAR
   ldi   ARG_REG1, ECON1
   ldi   ARG_REG2, ECON1_BSEL1
   rcall ETH_BIT_FIELD_SET

   /* MACON1 */
   ldi   ARG_REG1, MACON1
   ldi   ARG_REG2, MACON1_MARXEN | MACON1_FULL_DUPLEX
   rcall ETH_BIT_FIELD_SET

   /* MACON3 */
   ldi   ARG_REG1, MACON3
   ldi   ARG_REG2, MACON3_PADCFG0 | MACON3_TXCRCEN | MACON3_FULL_DUPLEX | MACON3_FRMLNEN
   rcall ETH_BIT_FIELD_SET

   /* MACON4  */
   ldi   ARG_REG1, MACON4
   ldi   ARG_REG2, MACON4_DEFER
   rcall ETH_BIT_FIELD_SET

   /* Max frame length */
   /* Normal network nodes are designed to handle packets that are 1518 bytes or
    * less. 1518 -> 0x5EE
    */
   ldi ARG_REG1, MAMXFLL
   ldi ARG_REG2, 0xEE
   rcall ETH_WRITE_CONTROL_REGISTER
   ldi ARG_REG1, MAMXFLH
   ldi ARG_REG2, 0x05
   rcall ETH_WRITE_CONTROL_REGISTER

   /* MABBIPG. */
   /* Most applications will program this register with 15h when Full-Duplex
    * mode is used and 12h when Half-Duplex mode is used.
    */
   ldi ARG_REG1, MABBIPG
   ldi ARG_REG2, MABBIPG_FULL_DUPLEX
   rcall ETH_WRITE_CONTROL_REGISTER

   /* MAIPGL. */
   /* Configure the Non-Back-to-Back Inter-Packet Gap register low byte, MAIPGL.
    * Most applications will program this register with 12h.
    */
   ldi ARG_REG1, MAIPGL
   ldi ARG_REG2, 0x12
   rcall ETH_WRITE_CONTROL_REGISTER

   /* MAIPGH for full duplex to 0x0C */
   ldi ARG_REG1, MAIPGH
   ldi ARG_REG2, 0x0C
   rcall ETH_WRITE_CONTROL_REGISTER

   /* MACLCON1 & MACLCON2 default should be ok */

   /* SEST BANK 3 */
   ldi   ARG_REG1, ECON1
   ldi   ARG_REG2, ECON1_BSEL1 | ECON1_BSEL0
   rcall ETH_BIT_FIELD_SET
   /* Program the local MAC address into the MAADR1:MAADR6 registers. */
   /* MAC registers are:
    * ADDR  REG
    * 0x0   MAADR5
    * 0x1   MAADR6
    * 0x2   MAADR3
    * 0x3   MAADR4
    * 0x4   MAADR1
    * 0x5   MAADR2
    *
    * So, if we start from address 0x0 to 0x5, we have to write:
    * EEPROM_MAC_ADDR + (i-- * 2) [ + 1]
    * Where i [2:0]
    */
   /* BEWARE ARG_REG1 -> R24
    *        ARG_REG2 -> R25
    */
   push  YH
   push  YL
   ldi   YH, hi8(EEPROM_MAC_ADDR)
   ldi   YL, lo8(EEPROM_MAC_ADDR)
   adiw  YL, 4 /* Start from the fifth element */
   ldi   ARG_REG1, MAADR5  /* ADDR zero */
ETH_MAC_INIT_SET_MAC_LOOP:
   /* Set Addr to read from EEPROM, read and write into SRAM */
   out   _SFR_IO_ADDR(EEARH), YH
   out   _SFR_IO_ADDR(EEARL), YL
   sbi   _SFR_IO_ADDR(EECR), EERE
   in    ARG_REG2, _SFR_IO_ADDR(EEDR)
   rcall ETH_WRITE_CONTROL_REGISTER  /* Write first */

   inc   ARG_REG1 /* Next address to write into */
   adiw  YL, 1    /* odd element to write */
   out   _SFR_IO_ADDR(EEARH), YH
   out   _SFR_IO_ADDR(EEARL), YL
   sbi   _SFR_IO_ADDR(EECR), EERE
   in    ARG_REG2, _SFR_IO_ADDR(EEDR)
   rcall ETH_WRITE_CONTROL_REGISTER  /* Write second */
   sbiw  YL, 3 /* go back to two previous even addr */
   inc   ARG_REG1
   cpi   ARG_REG1, MAADR2 + 1 /* MAADR2 is the last address we write */
   brne  ETH_MAC_INIT_SET_MAC_LOOP
   pop   YL
   pop   YH

#if 0
   ldi   ARG_REG1, MAADR1
   ldi   ARG_REG2, 0xFA
   rcall ETH_WRITE_CONTROL_REGISTER
   ldi   ARG_REG1, MAADR2
   ldi   ARG_REG2, 0xB3
   rcall ETH_WRITE_CONTROL_REGISTER
   ldi   ARG_REG1, MAADR3
   ldi   ARG_REG2, 0x12
   rcall ETH_WRITE_CONTROL_REGISTER
   ldi   ARG_REG1, MAADR4
   ldi   ARG_REG2, 0x10
   rcall ETH_WRITE_CONTROL_REGISTER
   ldi   ARG_REG1, MAADR5
   ldi   ARG_REG2, 0x00
   rcall ETH_WRITE_CONTROL_REGISTER
   ldi   ARG_REG1, MAADR6
   ldi   ARG_REG2, 0x00
   rcall ETH_WRITE_CONTROL_REGISTER
#endif
   ret

/*******************************************************************************
 * Miscellaneous initialization
 ******************************************************************************/
ETH_MISC_INIT:
   /* AUTOINC should be set by default */
#if 0
   ldi   ARG_REG1, ECON2
   ldi   ARG_REG2, ECON2_AUTOINC
   rcall ETH_BIT_FIELD_SET
#endif
   ret

#if 0
/*******************************************************************************
 ******************************************************************************/
ETH_PHY_INIT: /* ONLY ONCE */
   /* For proper duplex operation, the PHCON1.PDPXMD bit must also match the
    * value of the MACON3.FULDPX bit.
    */
    PHCON2.HDLDIS
#endif

/*******************************************************************************
 ******************************************************************************/
ETH_READ_BUFFER_START:
   ldi SPI_DATA, 0x3A
   SPI_SELECT_ETH
   rcall SPI_MASTER_TRANSMIT
   ret

#define ETH_READ_BUFFER_END SPI_END_ETH

/*******************************************************************************
 ******************************************************************************/
ETH_READ_RECEIVE_HEADER:
   ldi SPI_DATA, 0x3A
   SPI_SELECT_ETH
   push  ZL
   push  ZH
   rcall SPI_MASTER_TRANSMIT
   /* Save Status vector into SRAM */
   /* Get and check next packet pointer */
   rcall SPI_MASTER_TRANSMIT
   mov   ZL, RETURN_VALUE
   rcall SPI_MASTER_TRANSMIT
   mov   ZH, RETURN_VALUE
   /* Check that pointer is within receive buffer, seems that control packages
    * don't set the next packet pointer, therefore reading this value as zero */
   cpi   ZH, BUF_RX_ST_H
   brpl  ETH_READ_RECEIVE_HEADER_GET_RPKT_COUNT
   breq  ETH_READ_RECEIVE_HEADER_CHECK_N_PKT_L
   /* ZH is lower than expected */
   rjmp  ETH_READ_RECEIVE_HEADER_ERROR
ETH_READ_RECEIVE_HEADER_CHECK_N_PKT_L:
   cpi   ZL, BUF_RX_ST_L
   brge  ETH_READ_RECEIVE_HEADER_GET_RPKT_COUNT
   /* ZH:ZL is lower than expected */
   rjmp  ETH_READ_RECEIVE_HEADER_ERROR
ETH_READ_RECEIVE_HEADER_GET_RPKT_COUNT:
   sts   RPKT_N_PKT_L, ZL
   sts   RPKT_N_PKT_H, ZH

   rcall SPI_MASTER_TRANSMIT
   sts   RPKT_BYTE_COUNT_L, RETURN_VALUE
   rcall SPI_MASTER_TRANSMIT
   sts   RPKT_BYTE_COUNT_H, RETURN_VALUE

   rcall SPI_MASTER_TRANSMIT
   sts   RPKT_STATUS2, RETURN_VALUE
   rcall SPI_MASTER_TRANSMIT
   sts   RPKT_STATUS3, RETURN_VALUE
   SPI_END_ETH
ETH_READ_RECEIVE_HEADER_END:
   pop   ZH
   pop   ZL
   ret

/* BEWARE, calls to ETH_READ_RECEIVE_HEADER_ERROR are done before any
 * modification of the SRAM, so, it is same to call ETH_PKT_PROCESSED */
ETH_READ_RECEIVE_HEADER_ERROR:
#if 1
   /* DEBUGGING */
   ldi   TMP1, DEBUG_OPT_RECEIVE_BUFFER
   sts   DEBUG_OPT, TMP1
   rcall ETH_SEND_DEBUG
#endif
   ldi   RETURN_VALUE, 1
   SPI_END_ETH
   mov   ARG_REG1, ZH
   rcall MAIN_WRITE_TO_LCD_AS_HEX
   mov   ARG_REG1, ZL
   rcall MAIN_WRITE_TO_LCD_AS_HEX
   rcall ETH_PKT_PROCESSED
   ERR_ETH_SET_ERROR
   rjmp  ETH_READ_RECEIVE_HEADER_END

/*******************************************************************************
 ******************************************************************************/
ETH_READ_MAC_ADDRS_N_LEN_TYPE:
   ldi SPI_DATA, 0x3A
   SPI_SELECT_ETH
   rcall SPI_MASTER_TRANSMIT

   /* Using register Z for SRAM write incremental */
   push  R30
   push  R31

   /* Mac address SRC/DST and Type/len is all continuous in memory */
   ldi   TMP1, 14
   ldi   R31, hi8(ETH_HEADER)
   ldi   R30, lo8(ETH_HEADER)
ETH_READ_MAC_ADDRS_N_LEN_TYPE_KEEP_READING:
   rcall SPI_MASTER_TRANSMIT
   st    Z+, RETURN_VALUE
   dec   TMP1
   brne  ETH_READ_MAC_ADDRS_N_LEN_TYPE_KEEP_READING

   pop   R31
   pop   R30
   SPI_END_ETH
   ret

/*******************************************************************************
 ******************************************************************************/
ETH_PKT_PROCESSED:
   /* Set BANK 0 */
   ldi   ARG_REG1, ECON1
   ldi   ARG_REG2, ECON1_BSEL0 | ECON1_BSEL1
   rcall ETH_BIT_FIELD_CLEAR

   /* Move the RX Read Point to the next packet */
   ldi   ARG_REG1, ERXRDPTL
   lds   ARG_REG2, RPKT_N_PKT_L
   rcall ETH_WRITE_CONTROL_REGISTER

   ldi   ARG_REG1, ERXRDPTH
   lds   ARG_REG2, RPKT_N_PKT_H
   rcall ETH_WRITE_CONTROL_REGISTER

   /* Decrement received packet count */
   ldi   ARG_REG1, ECON2
   ldi   ARG_REG2, ECON2_PKTDEC
   rcall ETH_BIT_FIELD_SET

   /* Move the Read Pointer to the next packet */
   ldi   ARG_REG1, ERDPTL
   lds   ARG_REG2, RPKT_N_PKT_L
   rcall ETH_WRITE_CONTROL_REGISTER

   ldi   ARG_REG1, ERDPTH
   lds   ARG_REG2, RPKT_N_PKT_H
   rcall ETH_WRITE_CONTROL_REGISTER

   ret

/*******************************************************************************
 ******************************************************************************/
/* Per packet control byte {{{
bit 7-4 Unused

bit 3 PHUGEEN: Per Packet Huge Frame Enable bit
When POVERRIDE = 1:
    1 = The packet will be transmitted in whole
    0 = The MAC will transmit up to the number of bytes specified by MAMXFL. If the packet is larger
        than MAMXFL, it will be aborted after MAMXFL is reached.
When POVERRIDE = 0:
    This bit is ignored.

bit 2 PPADEN: Per Packet Padding Enable bit
When POVERRIDE = 1:
    1 = The packet will be zero padded to 60 bytes if it is less than 60 bytes
    0 = The packet will be transmitted without adding any padding bytes
When POVERRIDE = 0:
    This bit is ignored.

bit 1 PCRCEN: Per Packet CRC Enable bit
When POVERRIDE = 1:
    1 = A valid CRC will be calculated and attached to the frame
    0 = No CRC will be appended. The last 4 bytes of the frame will be checked for validity as a
        CRC.
When POVERRIDE = 0:
    This bit is ignored.

bit 0 POVERRIDE: Per Packet Override bit
    1 = The values of PCRCEN, PPADEN and PHUGEEN will override the configuration defined by MACON3
    0 = The values in MACON3 will be used to determine how the packet will be transmitted
}}} */
#define PPCB_PHUGEEN   0x08
#define PPCB_PPADEN    0x04
#define PPCB_PCRCEN    0x02
#define PPCB_POVERRIDE 0x01
ETH_WRITE_BUFFER_PACKET_HEADER:
   /* Set BANK 0 */
   push ZL
   push ZH
   push R16 /* Counter */
   push R17 /* Data holder */
   ldi   ARG_REG1, ECON1
   ldi   ARG_REG2, ECON1_BSEL0 | ECON1_BSEL1
   rcall ETH_BIT_FIELD_CLEAR

   /* Set Write Pointer EWRPT to start of transmit buffer */
   ldi   ARG_REG1, EWRPTL
   ldi   ARG_REG2, BUF_TX_ST_L
   rcall ETH_WRITE_CONTROL_REGISTER

   ldi   ARG_REG1, EWRPTH
   ldi   ARG_REG2, BUF_TX_ST_H
   rcall ETH_WRITE_CONTROL_REGISTER

   /* Send write command */
   ldi SPI_DATA, 0x7A
   SPI_SELECT_ETH
   rcall SPI_MASTER_TRANSMIT

   /* Write the packet header { */
   ldi SPI_DATA, PPCB_POVERRIDE | PPCB_PCRCEN | PPCB_PPADEN
   rcall SPI_MASTER_TRANSMIT

   /* Write Dst Mac address */
   ldi ZH, 0x0
   ldi ZL, MAC_ADDR_OTHER
   ldi R16, 6
ETH_WRITE_BUFFER_MAC_DST:
   ld  SPI_DATA, Z+
   rcall SPI_MASTER_TRANSMIT
   dec R16
   brne ETH_WRITE_BUFFER_MAC_DST

   /* Write Src Mac address */
   ldi R16, MAC_SIZE_IN_BYTES
   ldi ZL, lo8(EEPROM_MAC_ADDR)
   ldi ZH, hi8(EEPROM_MAC_ADDR)
ETH_WRITE_BUFFER_PACKET_HEADER_WRITE_SRC_MAC:
   out  _SFR_IO_ADDR(EEARH), ZH
   out  _SFR_IO_ADDR(EEARL), ZL
   sbi  _SFR_IO_ADDR(EECR), EERE
   in   SPI_DATA, _SFR_IO_ADDR(EEDR)
   rcall SPI_MASTER_TRANSMIT
   adiw ZL, 1
   dec R16
   brne ETH_WRITE_BUFFER_PACKET_HEADER_WRITE_SRC_MAC

   /* Write Type/Len */
   lds  SPI_DATA, TYPE_LEN_H
   rcall SPI_MASTER_TRANSMIT
   lds  SPI_DATA, TYPE_LEN_L
   rcall SPI_MASTER_TRANSMIT

   /* } */

   SPI_END_ETH

   pop R17
   pop R16
   pop ZH
   pop ZL
   ret

/*******************************************************************************
 * Write Payload {{{
 * Z is a pointer to memory to where start writing from
 * ARG_REG1 is number of byte to write
 ******************************************************************************/
ETH_WRITE_BUFFER_PACKET_PAYLOAD:
   /* Send write command */
   ldi SPI_DATA, 0x7A
   SPI_SELECT_ETH
   rcall SPI_MASTER_TRANSMIT

ETH_WRITE_BUFFER_PACKET_PAYLOAD_KEEP_WRITING:
   ld  SPI_DATA, Z+
   rcall SPI_MASTER_TRANSMIT
   dec ARG_REG1
   brne ETH_WRITE_BUFFER_PACKET_PAYLOAD_KEEP_WRITING

ETH_WRITE_BUFFER_PACKET_PAYLOAD_FINISH:
   SPI_END_ETH
   /* Set BANK 0 */
   ldi   ARG_REG1, ECON1
   ldi   ARG_REG2, ECON1_BSEL0 | ECON1_BSEL1
   rcall ETH_BIT_FIELD_CLEAR

   /* read EWRPT */
   push  ZH
   push  ZL
   ldi   SPI_DATA, EWRPTL
   rcall ETH_READ_CONTROL_REGISTER
   mov   ZL, RETURN_VALUE
   ldi   SPI_DATA, EWRPTH
   rcall ETH_READ_CONTROL_REGISTER
   mov   ZH, RETURN_VALUE

   sbiw  ZL, 1

   ldi   ARG_REG1, ETXNDL
   mov   ARG_REG2, ZL
   rcall ETH_WRITE_CONTROL_REGISTER
   ldi   ARG_REG1, ETXNDH
   mov   ARG_REG2, ZH
   rcall ETH_WRITE_CONTROL_REGISTER

   pop   ZL
   pop   ZH
   /* Clear EIR.TXIF, set EIE.TXIE and set EIE.INTIE
    *   to enable an interrupt when done (if desired).
    *   Start the transmission process by setting
    */

   ldi   ARG_REG1, EIR
   ldi   ARG_REG2, EIR_TXIF
   rcall ETH_BIT_FIELD_CLEAR

   ldi   ARG_REG1, EIE
   ldi   ARG_REG2, EIE_TXIE | EIE_INTIE
   rcall ETH_BIT_FIELD_SET

   /* Set bits to send packet */
   ldi   ARG_REG1, ECON1
   ldi   ARG_REG2, ECON1_TXRTS
   rcall ETH_BIT_FIELD_SET

   ldi   ZL, 200
DEBUG_WAIT:
   dec   ZL
   brne DEBUG_WAIT

ETH_WRITE_BUFFER_PACKET_PAYLOAD_FINISH_WAIT:
   ldi   SPI_DATA, ECON1
   rcall ETH_READ_CONTROL_REGISTER
   sbrc  RETURN_VALUE, 3
   rjmp  ETH_WRITE_BUFFER_PACKET_PAYLOAD_FINISH_WAIT

#if 0
   ldi   SPI_DATA, ESTAT
   rcall ETH_READ_CONTROL_REGISTER
   mov   ARG_REG1, RETURN_VALUE
   rcall MAIN_WRITE_TO_LCD_AS_HEX
#endif

   ldi   ARG_REG1, EIR
   ldi   ARG_REG2, EIR_TXIF
   rcall ETH_BIT_FIELD_CLEAR

   ret
/* }}} */

/*******************************************************************************
 * Check receive status vector {{{
 ******************************************************************************/
/* RPKT_STATUS3 {{{
   31      Zero                               0
   30      Receive VLAN Type Detected         Current frame was recognized as a VLAN tagged frame.
   29      Receive Unknown Opcode             Current frame was recognized as a control frame but it contained an
                                              unknown opcode.
   28      Receive Pause Control Frame        Current frame was recognized as a control frame containing a valid pause
                                              frame opcode and a valid destination address.
   27      Receive Control Frame              Current frame was recognized as a control frame for having a valid
                                              type/length designating it as a control frame.
   26      Dribble Nibble                     Indicates that after the end of this packet, an additional 1 to 7 bits were
                                              received. The extra bits were thrown away.
   25      Receive Broadcast Packet           Indicates packet received had a valid Broadcast address.
   24      Receive Multicast Packet           Indicates packet received had a valid Multicast address.
   }}} */
#define RPKT_STATUS3_ZERO                           7
#define RPKT_STATUS3_RECEIVE_VLAN_TYPE_DETECTED     6
#define RPKT_STATUS3_RECEIVE_UNKNOWN_OPCODE         5
#define RPKT_STATUS3_RECEIVE_PAUSE_CONTROL_FRAME    4
#define RPKT_STATUS3_RECEIVE_CONTROL_FRAME          3
#define RPKT_STATUS3_DRIBBLE_NIBBLE                 2
#define RPKT_STATUS3_RECEIVE_BROADCAST_PACKET       1
#define RPKT_STATUS3_RECEIVE_MULTICAST_PACKET       0

/* RPKT_STATUS2 {{{
   23      Received Ok                        Indicates that at the packet had a valid CRC and no symbol errors.
   22      Length Out of Range                Indicates that frame type/length field was larger than 1500 bytes (type field).
   21      Length Check Error                 Indicates that frame length field value in the packet does not match the
                                              actual data byte length and specifies a valid length.
   20      CRC Error                          Indicates that frame CRC field value does not match the CRC calculated
                                              by the MAC.
   19      Reserved
   18      Carrier Event Previously Seen      Indicates that at some time since the last receive, a carrier event was
                                              detected. The carrier event is not associated with this packet. A carrier
                                              event is activity on the receive channel that does not result in a packet
                                              receive attempt being made.
   17      Reserved
   16      Long Event/Drop Event              Indicates a packet over 50,000 bit times occurred or that a packet was dropped since the last receive.
   }}} */
#define RPKT_STATUS2_RECEIVED_OK                    7
#define RPKT_STATUS2_LENGTH_OUT_OF_RANGE            6
#define RPKT_STATUS2_LENGTH_CHECK_ERROR             5
#define RPKT_STATUS2_CRC_ERROR                      4
//#define RPKT_STATUS2_RESERVED                       3
#define RPKT_STATUS2_CARRIER_EVENT_PREVIOUSLY_SEEN  2
//#define RPKT_STATUS2_RESERVED                       1
#define RPKT_STATUS2_LONG_EVENT_DROP_EVENT          0

/* {{{
 15-0      Received Byte Count                Indicates length of the received frame. This includes the destination
                                              address, source address, type/length, data, padding and CRC fields. This
                                              field is stored in little-endian format.
   }}} */

ETH_CHECK_RECEIVE_STATUS_VECTOR:
   lds  TMP1, RPKT_STATUS3

   /* Drop away anything that is not only broadcast or multicast */
   andi TMP1, ~((1 << RPKT_STATUS3_RECEIVE_BROADCAST_PACKET) | (1 << RPKT_STATUS3_RECEIVE_MULTICAST_PACKET))
   tst  TMP1
   brne ETH_CHECK_RECEIVE_STATUS_VECTOR_FAILURE
#if 0
   sbrc TMP1, RPKT_STATUS3_ZERO /* Check that this bit must be zero */
   rjmp ETH_CHECK_RECEIVE_STATUS_VECTOR_FAILURE

   sbrc TMP1, RPKT_STATUS3_RECEIVE_UNKNOWN_OPCODE
   rjmp ETH_CHECK_RECEIVE_STATUS_VECTOR_FAILURE
#endif

   lds  TMP1, RPKT_STATUS2

   sbrs TMP1, RPKT_STATUS2_RECEIVED_OK
   rjmp ETH_CHECK_RECEIVE_STATUS_VECTOR_FAILURE

   sbrc TMP1, RPKT_STATUS2_LENGTH_CHECK_ERROR
   rjmp ETH_CHECK_RECEIVE_STATUS_VECTOR_FAILURE

   sbrc TMP1, RPKT_STATUS2_CRC_ERROR
   rjmp ETH_CHECK_RECEIVE_STATUS_VECTOR_FAILURE

   ldi  RETURN_VALUE, 0
   ret
   /* In case of failure, turn on error led, save the status vector into eeprom
    * to be read, go to sleep */
ETH_CHECK_RECEIVE_STATUS_VECTOR_FAILURE:
#if 1  /* bypass rest */
   ERR_ETH_SET_ERROR
   lds   ARG_REG1, RPKT_N_PKT_H
   rcall MAIN_WRITE_TO_LCD_AS_HEX
   lds   ARG_REG1, RPKT_N_PKT_L
   rcall MAIN_WRITE_TO_LCD_AS_HEX
   lds   ARG_REG1, RPKT_STATUS3
   rcall MAIN_WRITE_TO_LCD_AS_HEX
   lds   ARG_REG1, RPKT_STATUS2
   rcall MAIN_WRITE_TO_LCD_AS_HEX
   lds   ARG_REG1, RPKT_BYTE_COUNT_H
   rcall MAIN_WRITE_TO_LCD_AS_HEX
   lds   ARG_REG1, RPKT_BYTE_COUNT_L
   rcall MAIN_WRITE_TO_LCD_AS_HEX
   ldi   RETURN_VALUE, 1
   //sleep
   ret
#else
   ldi TMP1, 6
   ldi YL, lo8(RPKT_N_PKT_L)
   ldi YH, hi8(RPKT_N_PKT_L)
   ldi ZL, lo8(EEPROM_RECEIVE_STATUS_VECTOR_ERROR)
   ldi ZH, hi8(EEPROM_RECEIVE_STATUS_VECTOR_ERROR)
ETH_CHECK_RECEIVE_STATUS_VECTOR_FAILURE_LOOP:
   sbic _SFR_IO_ADDR(EECR), EEWE
   rjmp ETH_WRITE_BUFFER_PACKET_HEADER_WRITE_SRC_MAC
   out  _SFR_IO_ADDR(EEARH), ZH
   out  _SFR_IO_ADDR(EEARL), ZL
   adiw ZL, 1
   ld   ETH_TMP_REG1, Y+
   out  _SFR_IO_ADDR(EEDR), ETH_TMP_REG1
   sbi  _SFR_IO_ADDR(EECR), EEMWE
   sbi  _SFR_IO_ADDR(EECR), EEWE
   dec  TMP1
   brne ETH_CHECK_RECEIVE_STATUS_VECTOR_FAILURE_LOOP
   ERR_ETH_SET_ERROR
   sleep
#endif
/* }}} */

/*******************************************************************************
 * Write debug message into ethernet
 ******************************************************************************/
ETH_SEND_DEBUG:
   push  ZL
   push  ZH
   push  R16 /* Counter */
   push  R17 /* Data holder */
   /* Set BANK 0 */
   ldi   ARG_REG1, ECON1
   ldi   ARG_REG2, ECON1_BSEL0 | ECON1_BSEL1
   rcall ETH_BIT_FIELD_CLEAR

   /* Set Write Pointer to the end of the transmission buffer less the bytes we
    * are going to write */
#if 1
   ldi   ARG_REG1, EWRPTL
   ldi   ARG_REG2, lo8(((BUF_TX_ND_H << 8) | BUF_TX_ND_L) - DEBUG_FRAME_SIZE)
   rcall ETH_WRITE_CONTROL_REGISTER
   ldi   ARG_REG1, ETXSTL
   ldi   ARG_REG2, lo8(((BUF_TX_ND_H << 8) | BUF_TX_ND_L) - DEBUG_FRAME_SIZE)
   rcall ETH_WRITE_CONTROL_REGISTER

   ldi   ARG_REG1, EWRPTH
   ldi   ARG_REG2, hi8(((BUF_TX_ND_H << 8) | BUF_TX_ND_L) - DEBUG_FRAME_SIZE)
   rcall ETH_WRITE_CONTROL_REGISTER
   ldi   ARG_REG1, ETXSTH
   ldi   ARG_REG2, hi8(((BUF_TX_ND_H << 8) | BUF_TX_ND_L) - DEBUG_FRAME_SIZE)
   rcall ETH_WRITE_CONTROL_REGISTER
#else
   /* Set Write Pointer EWRPT to start of transmit buffer */
   ldi   ARG_REG1, EWRPTL
   ldi   ARG_REG2, BUF_TX_ST_L
   rcall ETH_WRITE_CONTROL_REGISTER

   ldi   ARG_REG1, EWRPTH
   ldi   ARG_REG2, BUF_TX_ST_H
   rcall ETH_WRITE_CONTROL_REGISTER
#endif

   /* Send write command */
   ldi   SPI_DATA, 0x7A
   SPI_SELECT_ETH
   rcall SPI_MASTER_TRANSMIT

   /* Write the packet header { */
   ldi   SPI_DATA, PPCB_POVERRIDE | PPCB_PCRCEN | PPCB_PPADEN
   rcall SPI_MASTER_TRANSMIT

   /* Write Dst Mac address */
   ldi   R16, MAC_SIZE_IN_BYTES
   ldi   ZH, hi8(EEPROM_MAC_DEBUG)
   ldi   ZL, lo8(EEPROM_MAC_DEBUG)
ETH_SEND_DEBUG_WRITE_DST_MAC:
   out   _SFR_IO_ADDR(EEARH), ZH
   out   _SFR_IO_ADDR(EEARL), ZL
   sbi   _SFR_IO_ADDR(EECR), EERE
   in    SPI_DATA, _SFR_IO_ADDR(EEDR)
   rcall SPI_MASTER_TRANSMIT
   adiw  ZL, 1
   dec   R16
   brne  ETH_SEND_DEBUG_WRITE_DST_MAC

   /* Write Src Mac address */
   ldi   R16, MAC_SIZE_IN_BYTES
   ldi   ZL, lo8(EEPROM_MAC_ADDR)
   ldi   ZH, hi8(EEPROM_MAC_ADDR)
ETH_SEND_DEBUG_WRITE_SRC_MAC:
   out   _SFR_IO_ADDR(EEARH), ZH
   out   _SFR_IO_ADDR(EEARL), ZL
   sbi   _SFR_IO_ADDR(EECR), EERE
   in    SPI_DATA, _SFR_IO_ADDR(EEDR)
   rcall SPI_MASTER_TRANSMIT
   adiw  ZL, 1
   dec   R16
   brne  ETH_SEND_DEBUG_WRITE_SRC_MAC

   /* Write Type/Len */
#define ETHER_TYPE_DEBUG 0x1987
   ldi   SPI_DATA, hi8(ETHER_TYPE_DEBUG)
   rcall SPI_MASTER_TRANSMIT
   ldi   SPI_DATA, lo8(ETHER_TYPE_DEBUG)
   rcall SPI_MASTER_TRANSMIT

   /* } */

   lds   R17, DEBUG_OPT
   cpi   R17, DEBUG_OPT_WRITE_SRAM
   brne  DEBUG_OPT_2

DEBUG_OPT_1:
   lds   ZL, DEBUG_ADDR_L
   lds   ZH, DEBUG_ADDR_H
   lds   R16, DEBUG_LEN
DEBUG_OPT_1_LOOP:
   ld    SPI_DATA, Z+
   rcall SPI_MASTER_TRANSMIT
   dec   R16
   brne  DEBUG_OPT_1_LOOP
   rjmp  DEBUG_OPT_END

DEBUG_OPT_2:
   cpi   R17, DEBUG_OPT_RECEIVE_BUFFER
   brne  DEBUG_OPT_END
   /* Save read pointer */
   SPI_END_ETH
   ldi   SPI_DATA, ERDPTL
   rcall ETH_READ_CONTROL_REGISTER
   push  RETURN_VALUE
   ldi   SPI_DATA, ERDPTH
   rcall ETH_READ_CONTROL_REGISTER
   push  RETURN_VALUE

   /* Set read pointer to beginning of READ BUFFER */
   ldi   ARG_REG1, ERDPTL
   ldi   ARG_REG2, BUF_RX_ST_L
   rcall ETH_WRITE_CONTROL_REGISTER
   ldi   ARG_REG1, ERDPTH
   ldi   ARG_REG2, BUF_RX_ST_H
   rcall ETH_WRITE_CONTROL_REGISTER

   /* Read from READ BUFFER and write to WRITE BUFFER */
   /* TODO: DEBUG_PAYLOAD_SIZE <- R16 */
#if 1
   ldi   R16, DEBUG_PAYLOAD_SIZE
DEBUG_OPT_2_WRITE_PAYLOAD:
   /* Send read command */
   ldi   SPI_DATA, 0x3A
   SPI_SELECT_ETH
   rcall SPI_MASTER_TRANSMIT
   rcall SPI_MASTER_TRANSMIT
   push  RETURN_VALUE
   SPI_END_ETH
   /* Send write command */
   ldi   SPI_DATA, 0x7A
   SPI_SELECT_ETH
   rcall SPI_MASTER_TRANSMIT
   pop   SPI_DATA
   rcall SPI_MASTER_TRANSMIT
   SPI_END_ETH
   dec   R16
   brne  DEBUG_OPT_2_WRITE_PAYLOAD
#endif

   /* Restore read pointer */
   ldi   ARG_REG1, ERDPTH
   pop   ARG_REG2
   rcall ETH_WRITE_CONTROL_REGISTER
   ldi   ARG_REG1, ERDPTL
   pop   ARG_REG2
   rcall ETH_WRITE_CONTROL_REGISTER

DEBUG_OPT_END:
   SPI_END_ETH
   rcall ETH_WRITE_BUFFER_PACKET_PAYLOAD_FINISH

   pop   R17
   pop   R16
   pop   ZH
   pop   ZL

   /* Set BANK 0 */
   ldi   ARG_REG1, ECON1
   ldi   ARG_REG2, ECON1_BSEL0 | ECON1_BSEL1
   rcall ETH_BIT_FIELD_CLEAR
   /* RESET TRANSMIT START */
   ldi ARG_REG1, ETXSTL
   ldi ARG_REG2, BUF_TX_ST_L
   rcall ETH_WRITE_CONTROL_REGISTER
   ldi ARG_REG1, ETXSTH
   ldi ARG_REG2, BUF_TX_ST_H
   rcall ETH_WRITE_CONTROL_REGISTER
   ret

#endif
