/* vim: set foldmethod=marker: */
#ifndef _ENC28J60_H_
#define _ENC28J60_H_

/* Common set of registers {{{ */
/* INTIE PKTIE DMAIE LINKIE TXIE r TXERIE RXERIE 0000 0000 */
#define ENC_COMMON_EIE         0x1B
#define ENC_COMMON_EIE_INTIE   0x80
#define ENC_COMMON_EIE_PKTIE   0x40
#define ENC_COMMON_EIE_DMAIE   0x20
#define ENC_COMMON_EIE_LINKIE  0x10
#define ENC_COMMON_EIE_TXIE    0x08
/* #define EIE_r       0x04 */
#define ENC_COMMON_EIE_TXERIE  0x02
#define ENC_COMMON_EIE_RXERIE  0x01

/* — PKTIF DMAIF LINKIF TXIF r TXERIF RXERIF -000 0000 */
#define ENC_COMMON_EIR         0x1C
//#define -        0x80
#define ENC_COMMON_EIR_PKTIF  0x40
#define ENC_COMMON_EIR_DMAIF  0x20
#define ENC_COMMON_EIR_LINKIF 0x10
#define ENC_COMMON_EIR_TXIF   0x08
#define ENC_COMMON_EIR_r      0x04
#define ENC_COMMON_EIR_TXERIF 0x02
#define ENC_COMMON_EIR_RXERIF 0x01

/* INT BUFER r LATECOL — RXBUSY TXABRT CLKRDY(1) 0000 -000 */
#define ENC_COMMON_ESTAT       0x1D
#define ENC_COMMON_ESTAT_INT      7
#define ENC_COMMON_ESTAT_BUFER    6
#define ENC_COMMON_ESTAT_r        5
#define ENC_COMMON_ESTAT_LATECOL  4
//#define ESTAT_—        3
#define ENC_COMMON_ESTAT_RXBUSY   2
#define ENC_COMMON_ESTAT_TXABRT   1
#define ENC_COMMON_ESTAT_CLKRDY   0
/* AUTOINC PKTDEC PWRSV r VRPS — — — 1000 0--- */
#define ENC_COMMON_ECON2       0x1E
#define ENC_COMMON_ECON2_AUTOINC    0x80
#define ENC_COMMON_ECON2_PKTDEC     0x40
#define ENC_COMMON_ECON2_PWRSV      0x20
#define ENC_COMMON_ECON2_r          0x10
#define ENC_COMMON_ECON2_VRPS       0x08
/* #define ECON2_—          0x04 */
/* #define ECON2_—          0x02 */
/* #define ECON2_—          0x01 */

/* TXRST RXRST DMAST CSUMEN TXRTS RXEN BSEL1 BSEL0 0000 0000 */
#define ENC_COMMON_ECON1       0x1F
/* ENC_COMMON_ECON1 Fields */
#define ENC_COMMON_ECON1_TXRST       0x80
#define ENC_COMMON_ECON1_RXRST       0x40
#define ENC_COMMON_ECON1_DMAST       0x20
#define ENC_COMMON_ECON1_CSUMEN      0x10
#define ENC_COMMON_ECON1_TXRTS       0x08
#define ENC_COMMON_ECON1_RXEN        0x04
#define ENC_COMMON_ECON1_RXEN_BIT       3
#define ENC_COMMON_ECON1_BSEL1       0x02
#define ENC_COMMON_ECON1_BSEL0       0x01
/* ECON1_BSEL[10] determine which bank we are using, defining handy macros */
#define ENC_COMMON_BANK0 (!ENC_COMMON_ECON1_BSEL1)|(!ENC_COMMON_ECON1_BSEL0)
#define ENC_COMMON_BANK1 (!ENC_COMMON_ECON1_BSEL1)|( ENC_COMMON_ECON1_BSEL0)
#define ENC_COMMON_BANK2 ( ENC_COMMON_ECON1_BSEL1)|(!ENC_COMMON_ECON1_BSEL0)
#define ENC_COMMON_BANK3 ( ENC_COMMON_ECON1_BSEL1)|( ENC_COMMON_ECON1_BSEL0)

#define ENC_COMMON_BANK_MASK ((ENC_COMMON_ECON1_BSEL1)|(ENC_COMMON_ECON1_BSEL0))
/* }}} */
/* Control register Bank 0 {{{ */
/* Read Pointer Low Byte ERDPT<7:0>) 1111 1010 */
#define ENC_BANK0_ERDPTL      0x00
/* — — — Read Pointer High Byte (ERDPT<12:8>) ---0 0101 */
#define ENC_BANK0_ERDPTH      0x01
/* Write Pointer Low Byte (EWRPT<7:0>) 0000 0000 */
#define ENC_BANK0_EWRPTL      0x02
/* — — — Write Pointer High Byte (EWRPT<12:8>) ---0 0000 */
#define ENC_BANK0_EWRPTH      0x03
/* TX Start Low Byte (ETXST<7:0>) 0000 0000 */
#define ENC_BANK0_ETXSTL      0x04
/* — — — TX Start High Byte (ETXST<12:8>) ---0 0000 */
#define ENC_BANK0_ETXSTH      0x05
/* TX End Low Byte (ETXND<7:0>) 0000 0000 */
#define ENC_BANK0_ETXNDL      0x06
/* — — — TX End High Byte (ETXND<12:8>) ---0 0000 */
#define ENC_BANK0_ETXNDH      0x07
/* RX Start Low Byte (ERXST<7:0>) 1111 1010 */
#define ENC_BANK0_ERXSTL      0x08
/* — — — RX Start High Byte (ERXST<12:8>) ---0 0101 */
#define ENC_BANK0_ERXSTH      0x09
/* RX End Low Byte (ERXND<7:0>) 1111 1111 */
#define ENC_BANK0_ERXNDL      0x0A
/* — — — RX End High Byte (ERXND<12:8>) ---1 1111 */
#define ENC_BANK0_ERXNDH      0x0B
/* RX RD Pointer Low Byte (ERXRDPT<7:0>) 1111 1010 */
#define ENC_BANK0_ERXRDPTL    0x0C
/* — — — RX RD Pointer High Byte (ERXRDPT<12:8>) ---0 0101 */
#define ENC_BANK0_ERXRDPTH    0x0D
/* RX WR Pointer Low Byte (ERXWRPT<7:0>) 0000 0000 */
#define ENC_BANK0_ERXWRPTL    0x0E
/* — — — RX WR Pointer High Byte (ERXWRPT<12:8>) ---0 0000 */
#define ENC_BANK0_ERXWRPTH    0x0F
/* DMA Start Low Byte (EDMAST<7:0>) 0000 0000 */
#define ENC_BANK0_EDMASTL     0x10
/* — — — DMA Start High Byte (EDMAST<12:8>) ---0 0000 */
#define ENC_BANK0_EDMASTH     0x11
/* DMA End Low Byte (EDMAND<7:0>) 0000 0000 */
#define ENC_BANK0_EDMANDL     0x12
/* — — — DMA End High Byte (EDMAND<12:8>) ---0 0000 */
#define ENC_BANK0_EDMANDH     0x13
/* DMA Destination Low Byte (EDMADST<7:0>) 0000 0000 */
#define ENC_BANK0_EDMADSTL    0x14
/* — — — DMA Destination High Byte (EDMADST<12:8>) ---0 0000 */
#define ENC_BANK0_EDMADSTH    0x15
/* DMA Checksum Low Byte (EDMACS<7:0>) 0000 0000 */
#define ENC_BANK0_EDMACSL     0x16
/* DMA Checksum High Byte (EDMACS<15:8>) 0000 0000 */
#define ENC_BANK0_EDMACSH     0x17
/* - 0x18 */
/* - 0x19 */
/* #define Reserved    0x1A */
/* }}} */
/* Control register Bank 1  {{{ */
/* Hash Table Byte 0 (EHT<7:0>) 0000 0000 */
#define ENC_BANK1_EHT0        0x00
/* Hash Table Byte 1 (EHT<15:8>) 0000 0000 */
#define ENC_BANK1_EHT1        0x01
/* Hash Table Byte 2 (EHT<23:16>) 0000 0000 */
#define ENC_BANK1_EHT2        0x02
/* Hash Table Byte 3 (EHT<31:24>) 0000 0000 */
#define ENC_BANK1_EHT3        0x03
/* Hash Table Byte 4 (EHT<39:32>) 0000 0000 */
#define ENC_BANK1_EHT4        0x04
/* Hash Table Byte 5 (EHT<47:40>) 0000 0000 */
#define ENC_BANK1_EHT5        0x05
/* Hash Table Byte 6 (EHT<55:48>) 0000 0000 */
#define ENC_BANK1_EHT6        0x06
/* Hash Table Byte 7 (EHT<63:56>) 0000 0000 */
#define ENC_BANK1_EHT7        0x07
/* Pattern Match Mask Byte 0 (EPMM<7:0>) 0000 0000 */
#define ENC_BANK1_EPMM0       0x08
/* Pattern Match Mask Byte 1 (EPMM<15:8>) 0000 0000 */
#define ENC_BANK1_EPMM1       0x09
/* Pattern Match Mask Byte 2 (EPMM<23:16>) 0000 0000 */
#define ENC_BANK1_EPMM2       0x0A
/* Pattern Match Mask Byte 3 (EPMM<31:24>) 0000 0000 */
#define ENC_BANK1_EPMM3       0x0B
/* Pattern Match Mask Byte 4 (EPMM<39:32>) 0000 0000 */
#define ENC_BANK1_EPMM4       0x0C
/* Pattern Match Mask Byte 5 (EPMM<47:40>) 0000 0000 */
#define ENC_BANK1_EPMM5       0x0D
/* Pattern Match Mask Byte 6 (EPMM<55:48>) 0000 0000 */
#define ENC_BANK1_EPMM6       0x0E
/* Pattern Match Mask Byte 7 (EPMM<63:56>) 0000 0000 */
#define ENC_BANK1_EPMM7       0x0F
/* Pattern Match Checksum Low Byte (EPMCS<7:0>) 0000 0000 */
#define ENC_BANK1_EPMCSL      0x10
/* Pattern Match Checksum High Byte (EPMCS<15:0>) 0000 0000 */
#define ENC_BANK1_EPMCSH      0x11
/* - 0x12 */
/* - 0x13 */
/* Pattern Match Offset Low Byte (EPMO<7:0>) 0000 0000 51 */
#define ENC_BANK1_EPMOL       0x14
/* — — — Pattern Match Offset High Byte (EPMO<12:8>) ---0 0000 51 */
#define ENC_BANK1_EPMOH       0x15
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
#define ENC_BANK1_ERXFCON        0x18
#define ENC_BANK1_ERXFCON_UCEN   0x80
#define ENC_BANK1_ERXFCON_ANDOR  0x40
#define ENC_BANK1_ERXFCON_CRCEN  0x20
#define ENC_BANK1_ERXFCON_PMEN   0x10
#define ENC_BANK1_ERXFCON_MPEN   0x08
#define ENC_BANK1_ERXFCON_HTEN   0x04
#define ENC_BANK1_ERXFCON_MCEN   0x02
#define ENC_BANK1_ERXFCON_BCEN   0x01
/* Ethernet Packet Count 0000 0000 43 */
#define ENC_BANK1_EPKTCNT        0x19
/* #define Reserved    0x1A */
/* }}} */
/* Control register Bank 2 {{{ */
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
#define ENC_BANK2_MACON1          0x00
#define ENC_BANK2_MACON1_TXPAUS   0x08
#define ENC_BANK2_MACON1_RXPAUS   0x04
#define ENC_BANK2_MACON1_PASSALL  0x02
#define ENC_BANK2_MACON1_MARXEN   0x01
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
#define ENC_BANK2_MACON3           0x02
#define ENC_BANK2_MACON3_PADCFG2   0x80
#define ENC_BANK2_MACON3_PADCFG1   0x40
#define ENC_BANK2_MACON3_PADCFG0   0x20
#define ENC_BANK2_MACON3_TXCRCEN   0x10
#define ENC_BANK2_MACON3_PHDREN    0x08
#define ENC_BANK2_MACON3_HFRMEN    0x04
#define ENC_BANK2_MACON3_FRMLNEN   0x02
#define ENC_BANK2_MACON3_FULDPX    0x01

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
#define ENC_BANK2_MACON4       0x03
#define ENC_BANK2_MACON4_DEFER 0x40
/* — Back-to-Back Inter-Packet Gap (BBIPG<6:0>) -000 0000 36 */
#define ENC_BANK2_MABBIPG      0x04
/* - 0x05 */
/* — Non-Back-to-Back Inter-Packet Gap Low Byte (MAIPGL<6:0>) -000 0000 34 */
#define ENC_BANK2_MAIPGL       0x06
/* — Non-Back-to-Back Inter-Packet Gap High Byte (MAIPGH<6:0>) -000 0000 34 */
#define ENC_BANK2_MAIPGH       0x07
/* — — — — Retransmission Maximum (RETMAX<3:0>) ---- 1111 34 */
#define ENC_BANK2_MACLCON1     0x08
/* — — Collision Window (COLWIN<5:0>) --11 0111 34 */
#define ENC_BANK2_MACLCON2     0x09
/* Maximum Frame Length Low Byte (MAMXFL<7:0>) 0000 0000 */
#define ENC_BANK2_MAMXFLL      0x0A
/* Maximum Frame Length High Byte (MAMXFL<15:8>) 0000 0110 */
#define ENC_BANK2_MAMXFLH      0x0B
/* #define Reserved    0x0C */
/* #define Reserved    0x0D */
/* #define Reserved    0x0E */
/* - 0x0F */
/* #define Reserved    0x10 */
/* #define Reserved    0x11 */
/* — — — — — — MIISCAN MIIRD ---- --00 21 */
#define ENC_BANK2_MICMD       0x12
/* - 0x13 */
/* — — — MII Register Address (MIREGADR<4:0>) ---0 0000 19 */
#define ENC_BANK2_MIREGADR    0x14
/* #define Reserved    0x15 */
/* MII Write Data Low Byte (MIWR<7:0>) 0000 0000 19 */
#define ENC_BANK2_MIWRL       0x16
/* MII Write Data High Byte (MIWR<15:8>) 0000 0000 19 */
#define ENC_BANK2_MIWRH       0x17
/* MII Read Data Low Byte (MIRD<7:0>) 0000 0000 19 */
#define ENC_BANK2_MIRDL       0x18
/* MII Read Data High Byte(MIRD<15:8>) 0000 0000 19 */
#define ENC_BANK2_MIRDH       0x19
/* #define Reserved    0x1A */
/* }}} */
/* Control register Bank 3 {{{ */
/* MAC Address Byte 5 (MAADR<15:8>) 0000 0000 34 */
#define ENC_BANK3_MAADR5      0x00
/* MAC Address Byte 6 (MAADR<7:0>) 0000 0000 34 */
#define ENC_BANK3_MAADR6      0x01
/* MAC Address Byte 3 (MAADR<31:24>), OUI Byte 3 0000 0000 34 */
#define ENC_BANK3_MAADR3      0x02
/* MAC Address Byte 4 (MAADR<23:16>) 0000 0000 34 */
#define ENC_BANK3_MAADR4      0x03
/* MAC Address Byte 1 (MAADR<47:40>), OUI Byte 1 0000 0000 34 */
#define ENC_BANK3_MAADR1      0x04
/* MAC Address Byte 2 (MAADR<39:32>), OUI Byte 2 0000 0000 34 */
#define ENC_BANK3_MAADR2      0x05
/* Built-in Self-Test Fill Seed (EBSTSD<7:0>) 0000 0000 76 */
#define ENC_BANK3_EBSTSD      0x06
/* PSV2 PSV1 PSV0 PSEL TMSEL1 TMSEL0 TME BISTST 0000 0000 75 */
#define ENC_BANK3_EBSTCON     0x07
/* Built-in Self-Test Checksum Low Byte (EBSTCS<7:0>) 0000 0000 76 */
#define ENC_BANK3_EBSTCSL     0x08
/* Built-in Self-Test Checksum High Byte (EBSTCS<15:8>) 0000 0000 76 */
#define ENC_BANK3_EBSTCSH     0x09
/* — — — — r NVALID SCAN BUSY ---- 0000 21 */
#define ENC_BANK3_MISTAT      0x0A
/* - 0x0B */
/* - 0x0C */
/* - 0x0D */
/* - 0x0E */
/* - 0x0F */
/* - 0x10 */
/* - 0x11 */
/* (2) — — — Ethernet Revision ID (EREVID<4:0>) ---q qqqq 22 */
#define ENC_BANK3_EREVID      0x12
/* - 0x13 */
/* - 0x14 */
/* (3) — — — — — COCON2 COCON1 COCON0 ---- -100 6 */
#define ENC_BANK3_ECOCON      0x15
/* #define Reserved    0x16 */
/* — — — — — FULDPXS FCEN1 FCEN0 ---- -000 56 */
#define ENC_BANK3_EFLOCON     0x17
/* Pause Timer Value Low Byte (EPAUS<7:0>) 0000 0000 57 */
#define ENC_BANK3_EPAUSL      0x18
#define ENC_BANK3_EPAUSH      0x19
/* #define Reserved    0x1A */
/* }}} */
/* SPI commands {{{ */
/*
Read Buffer Memory
(RBM)   0 0 1   1 1 0 1 0       N/A
Write Control Register
(WCR)   0 1 0   a a a a a       d d d d d d d d
Write Buffer Memory
(WBM)   0 1 1   1 1 0 1 0       d d d d d d d d
Bit Field Set
(BFS)   1 0 0   a a a a a       d d d d d d d d
Bit Field Clear
(BFC)   1 0 1   a a a a a       d d d d d d d d
System Reset Command (Soft Reset)
(SRC)   1 1 1   1 1 1 1 1       N/A_
*/
#define ETH_SPI_CMD_RCR 0x00
#define ETH_SPI_CMD_RBM 0x3A
#define ETH_SPI_CMD_WCR 0x40
#define ETH_SPI_CMD_WBM 0x7A
#define ETH_SPI_CMD_BFS 0x80
#define ETH_SPI_CMD_BFC 0xA0
#define ETH_SPI_CMD_SRC 0xFF
/* }}} */
/* RPKT_STATUS3 {{{
    31  Zero
        0
    30  Receive VLAN Type Detected
        Current frame was recognized as a VLAN tagged frame.
    29  Receive Unknown Opcode
        Current frame was recognized as a control frame but it contained an
        unknown opcode.
    28  Receive Pause Control Frame
        Current frame was recognized as a control frame containing a valid pause
        frame opcode and a valid destination address.
    27  Receive Control Frame
        Current frame was recognized as a control frame for having a valid
        type/length designating it as a control frame.
    26  Dribble Nibble
        Indicates that after the end of this packet, an additional 1 to 7 bits
        were received. The extra bits were thrown away.
    25  Receive Broadcast Packet
        Indicates packet received had a valid Broadcast address.
    24  Receive Multicast Packet
        Indicates packet received had a valid Multicast address. */

#define RPKT_STATUS3_ZERO                           7
#define RPKT_STATUS3_RECEIVE_VLAN_TYPE_DETECTED     6
#define RPKT_STATUS3_RECEIVE_UNKNOWN_OPCODE         5
#define RPKT_STATUS3_RECEIVE_PAUSE_CONTROL_FRAME    4
#define RPKT_STATUS3_RECEIVE_CONTROL_FRAME          3
#define RPKT_STATUS3_DRIBBLE_NIBBLE                 2
#define RPKT_STATUS3_RECEIVE_BROADCAST_PACKET       1
#define RPKT_STATUS3_RECEIVE_MULTICAST_PACKET       0
/* }}} */
/* RPKT_STATUS2 {{{
    23  Received Ok
        Indicates that at the packet had a valid CRC and no symbol errors.
    22  Length Out of Range
        Indicates that frame type/length field was larger than 1500 bytes (type
        field).
    21  Length Check Error
        Indicates that frame length field value in the packet does not match the
        actual data byte length and specifies a valid length.
    20  CRC Error
        Indicates that frame CRC field value does not match the CRC calculated
        by the MAC.
    19  Reserved
    18  Carrier Event Previously Seen
        Indicates that at some time since the last receive, a carrier event was
        detected. The carrier event is not associated with this packet. A
        carrier event is activity on the receive channel that does not result in
        a packet receive attempt being made.
    17  Reserved
    16  Long Event/Drop Event
        Indicates a packet over 50,000 bit times occurred or that a packet was
        dropped since the last receive. */

#define RPKT_STATUS2_RECEIVED_OK                    7
#define RPKT_STATUS2_LENGTH_OUT_OF_RANGE            6
#define RPKT_STATUS2_LENGTH_CHECK_ERROR             5
#define RPKT_STATUS2_CRC_ERROR                      4
//#define RPKT_STATUS2_RESERVED                       3
#define RPKT_STATUS2_CARRIER_EVENT_PREVIOUSLY_SEEN  2
//#define RPKT_STATUS2_RESERVED                       1
#define RPKT_STATUS2_LONG_EVENT_DROP_EVENT          0
/* }}} */
/* [RPKT_BYTE_COUNT_H:RPKT_BYTE_COUNT_L] {{{
    15-0  Received Byte Count
    Indicates length of the received frame. This includes the destination
    address, source address, type/length, data, padding and CRC fields. This
    field is stored in little-endian format.
}}} */
#ifdef USE_FULL_DUPLEX /* {{{ */
#  define ENC_BANK2_MACON1_FULL_DUPLEX   (ENC_BANK2_MACON1_RXPAUS | ENC_BANK2_MACON1_TXPAUS)
#  define ENC_BANK2_MABBIPG_FULL_DUPLEX  0x15
#  define ENC_BANK2_MACON3_FULL_DUPLEX   (ENC_BANK2_MACON3_FULDPX)
#else
#  define ENC_BANK2_MACON1_FULL_DUPLEX   0
#  define ENC_BANK2_MABBIPG_FULL_DUPLEX  0x12
#  define ENC_BANK2_MACON3_FULL_DUPLEX   0
#endif /* }}} */

#define ETH_READ_BUFFER_END SPI_END_ETH
#endif
