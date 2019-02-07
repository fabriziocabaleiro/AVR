/* vim: set filetype=S:set foldmethod=marker: */
#include "enc28j60.S"
#include "defs.h"
#ifndef __ARP_S__
#define __ARP_S__

#if 0 /* Documentation  {{{ */
         Internet Protocol (IPv4) over Ethernet ARP packet
   +-----------------------------------------------------------------+
   |          First byte            |          Second byte           |
   +-----------------------------------------------------------------+
0  |                   Hardware type (HTYPE)                         |
   +-----------------------------------------------------------------+
2  |                   Protocol type (PTYPE)                         |
   +--------------------------------+--------------------------------+
4  | Hardware address length (HLEN) | Protocol address length (PLEN) |
   +--------------------------------+--------------------------------+
6  |                       Operation (OPER)                          |
   +-----------------------------------------------------------------+
8  |         Sender hardware address (SHA) (first 2 bytes)           |
   +-----------------------------------------------------------------+
10 |                       (next 2 bytes)                            |
   +-----------------------------------------------------------------+
12 |                       (last 2 bytes)                            |
   +-----------------------------------------------------------------+
14 |         Sender protocol address (SPA) (first 2 bytes)           |
   +-----------------------------------------------------------------+
16 |                       (last 2 bytes)                            |
   +-----------------------------------------------------------------+
18 |         Target hardware address (THA) (first 2 bytes)           |
   +-----------------------------------------------------------------+
20 |                        (next 2 bytes)                           |
   +-----------------------------------------------------------------+
22 |                        (last 2 bytes)                           |
   +-----------------------------------------------------------------+
24 |          Target protocol address (TPA) (first 2 bytes)          |
   +-----------------------------------------------------------------+
26 |                       (last 2 bytes)                            |
   +-----------------------------------------------------------------+
#endif /* }}} */

#define ARP_HTYPE 0
#define ARP_PTYPE 2
#define ARP_HLEN  4
#define ARP_PLEN  5
/* Operation, 1 request, 2 reply */
#define ARP_OPER  6
/* Sender MAC addr */
#define ARP_SHA   8
/* Sender IP addr */
#define ARP_SPA   14
/* Receiver MAC addr */
#define ARP_THA   18
/* Receiver IP addr */
#define ARP_TPA   24

#define ARP_OPER_REQUEST  1
#define ARP_OPER_REPLY    2

#define READ_NEXT_BYTE rcall SPI_MASTER_TRANSMIT

#define COUNTER R16
#define DATA1   R17
#define DATA2   R18
/*******************************************************************************
 ******************************************************************************/
ARP_PROCESS:
    ldi RETURN_VALUE, 0
    /* check type ARP */
    lds   TMP1, TYPE_LEN_H
    cpi   TMP1, hi8(ETHER_TYPE_ARP)
    brne  ARP_UNEXPECTED_PACKET
    lds   TMP1, TYPE_LEN_L
    cpi   TMP1, lo8(ETHER_TYPE_ARP)
    brne  ARP_UNEXPECTED_PACKET

    /* Read the ARP payload and store it into memory */
    /* Addr Z */
    push  ZH
    push  ZL
    /* Mostly counter */
    push  COUNTER

    rcall ETH_READ_BUFFER_START

    /* Read ARP payload (28 bytes) into SRAM */
    ldi   COUNTER, ARP_PAYLOAD_LEN
    ldi   ZH, hi8(ARP_PAYLOAD)
    ldi   ZL, lo8(ARP_PAYLOAD)

ARP_PROCESS_READ_PAYLOAD:
    READ_NEXT_BYTE
    st    Z+, RETURN_VALUE
    dec   COUNTER
    brne  ARP_PROCESS_READ_PAYLOAD

    ETH_READ_BUFFER_END

    /* Check that ARP is for me */
    rcall ARP_PROCESS_CHECK_MY_IP
    cpi   RETURN_VALUE, 0
    brne  ARP_PROCESS_NOT_FOR_ME

    /* Prepare ARP packet to be sent as response */
    rcall ARP_PROCESS_PREPARE_RESPONSE

    /* Send ARP packet back */

ARP_PROCESS_CLOSE:
    pop   COUNTER
    pop   ZL
    pop   ZH

    ERR_ARP_CLR_ERROR
ARP_PROCESS_END:
    ret

ARP_UNEXPECTED_PACKET:
    ldi RETURN_VALUE, 1
    ERR_ARP_SET_ERROR
    rjmp ARP_PROCESS_END

ARP_PROCESS_NOT_FOR_ME:
    ldi RETURN_VALUE, 2
    rjmp ARP_PROCESS_CLOSE

/*******************************************************************************
 * Check that ARP packet is for me
 ******************************************************************************/
ARP_PROCESS_CHECK_MY_IP:
    /* Z is used to read the IP from the SRAM (received packet) */
    push ZH
    push ZL
    /* Y is used to read my IP from the EEPROM */
    push YH
    push YL
    push DATA1 /* My IP */
    push DATA2 /* ARP IP */

    ldi COUNTER, IPV4_SIZE_IN_BYTES

    /* Z */
    ldi ZH, hi8(ARP_PAYLOAD + ARP_TPA)
    ldi ZL, lo8(ARP_PAYLOAD + ARP_TPA)

    /* Y */
    ldi YH, hi8(EEPROM_IP_ADDR)
    ldi YL, lo8(EEPROM_IP_ADDR)

ARP_PROCESS_CHECK_MY_IP_LOOP:
    /* My ip from EEPROM */
    out  _SFR_IO_ADDR(EEARH), YH
    out  _SFR_IO_ADDR(EEARL), YL
    sbi  _SFR_IO_ADDR(EECR), EERE
    in   DATA1, _SFR_IO_ADDR(EEDR)
    adiw YL, 1
    /* Dst IP from ARP payload */
    ld   DATA2, Z+
    /* Comparing both IPs */
    cp   DATA2, DATA1
    brne ARP_PROCESS_NOT_MY_IP
    /* Loop counter */
    dec  COUNTER
    brne ARP_PROCESS_CHECK_MY_IP_LOOP

    /* Return zero if IPs are equal */
    ldi RETURN_VALUE, 0

ARP_PROCESS_CHECK_MY_IP_FINISH:
    pop DATA2
    pop DATA1
    pop YL
    pop YH
    pop ZL
    pop ZH
    ret

ARP_PROCESS_NOT_MY_IP:
    ldi RETURN_VALUE, 1
    rjmp ARP_PROCESS_CHECK_MY_IP_FINISH

/*******************************************************************************
 ******************************************************************************/
ARP_PROCESS_PREPARE_RESPONSE:
    /* Prepare response for ARP request */
    /* Replace operation from 1 to 2 (2 is reply) */
    push DATA1
    ldi  ZH, hi8(ARP_PAYLOAD + ARP_OPER + 1) /* First byte not used */
    ldi  ZL, lo8(ARP_PAYLOAD + ARP_OPER + 1)
    ldi  DATA1, ARP_OPER_REPLY
    st   Z+, DATA1  /* Z ends up in the first address of the sender's MAC */

    /* Write sender (mine) MAC and copy original MAC into destination (10 bytes
     * ahead) */
    ldi  COUNTER, MAC_SIZE_IN_BYTES
    ldi  YH, hi8(EEPROM_MAC_ADDR)
    ldi  YL, lo8(EEPROM_MAC_ADDR)
ARP_PROCESS_KEEP_WRITING_MY_MAC:
    /* Write previous target MAC into destination MAC */
    ld   DATA1, Z
    std  Z+(ARP_THA - ARP_SHA), DATA1
    /* Set Addr to read from EEPROM, read and write into SRAM */
    out  _SFR_IO_ADDR(EEARH), YH
    out  _SFR_IO_ADDR(EEARL), YL
    sbi  _SFR_IO_ADDR(EECR), EERE
    in   DATA1, _SFR_IO_ADDR(EEDR)
    adiw YL, 1
    st   Z+, DATA1
    dec  COUNTER
    brne ARP_PROCESS_KEEP_WRITING_MY_MAC

    /* Write my own IP and copy original IP into destination (10 bytes ahead) */
    ldi  COUNTER, IPV4_SIZE_IN_BYTES
    ldi  YH, hi8(EEPROM_IP_ADDR)
    ldi  YL, lo8(EEPROM_IP_ADDR)

ARP_PROCESS_WRITE_IP_BYTE:
    /* Copy IP from src to dst */
    ld   DATA1, Z
    std  Z+(ARP_TPA - ARP_SPA), DATA1
    /* Set addr to read from EEPROM, read into DATA1 and write it into SRAM */
    out  _SFR_IO_ADDR(EEARH), YH
    out  _SFR_IO_ADDR(EEARL), YL
    sbi  _SFR_IO_ADDR(EECR), EERE
    in   DATA1, _SFR_IO_ADDR(EEDR)
    adiw YL, 1
    st   Z+,  DATA1
    dec  COUNTER
    brne ARP_PROCESS_WRITE_IP_BYTE
    pop  DATA1
    ret

#endif
