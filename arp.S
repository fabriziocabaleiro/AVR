/* vim: set filetype=S foldmethod=marker: */
.NOLIST
#include <avr/io.h>
#include "defs.h"
#include "enc28j60.h"
#include "defs.h"
#include "arp.h"
.LIST

#define DATA1   TMP_REG2

.global ARP_HANDLE_PKT

/*******************************************************************************
 * Handle ARP packet {{{
 * 1. Read ARP payload into SRAM
 * 2. Check ARP is for me
 * 3. Modify ARP payload for response
 * 4. Write ARP response into Ethernet module
 ******************************************************************************/
ARP_HANDLE_PKT:
    push  ZH
    push  ZL
    push  YH
    push  YL
    push  COUNTER_REG

    /* Read ARP payload (28 bytes) into SRAM {{{ */
    rcall ETH_READ_BUFFER_START
    ldi   COUNTER_REG, ARP_PAYLOAD_LEN
    ldi   ZH, hi8(ARP_PAYLOAD)
    ldi   ZL, lo8(ARP_PAYLOAD)
ARP_PROCESS_READ_PAYLOAD:
    ETH_READ_NEXT_BYTE
    st    Z+, RETURN_VALUE
    dec   COUNTER_REG
    brne  ARP_PROCESS_READ_PAYLOAD

    ETH_READ_BUFFER_END
    /* }}} */
    /* TODO: find another way to get IP address of other device  {{{ */
#if 0 /* FIXME */
    push  ZL
    push  ZH
    push  YL
    push  YH
    ldi   ZL, lo8(ARP_PAYLOAD + ARP_SPA)
    ldi   ZH, hi8(ARP_PAYLOAD + ARP_SPA)
    ldi   YL, lo8(IP_ADDR_DST)
    ldi   YH, hi8(IP_ADDR_DST)
    ldi   TMP_REG2, IPV4_SIZE_IN_BYTES
TMP_LABEL_000:
    ld    RETURN_VALUE, Z+
    st    Y+, RETURN_VALUE
    dec   TMP_REG2
    brne  TMP_LABEL_000
    pop   YH
    pop   YL
    pop   ZH
    pop   ZL
#endif
    /* }}} */
    /* Check that ARP is for me  {{{ */
    ldi   COUNTER_REG, IPV4_SIZE_IN_BYTES
    /* Z */
    ldi   ZH, hi8(ARP_PAYLOAD + ARP_TPA)
    ldi   ZL, lo8(ARP_PAYLOAD + ARP_TPA)
    /* Y */
    ldi   YH, hi8(EEPROM_IP_ADDR)
    ldi   YL, lo8(EEPROM_IP_ADDR)
ARP_PROCESS_CHECK_MY_IP_LOOP:
    /* Dst IP from ARP payload */
    ld    DATA1, Z+
    /* My ip from EEPROM in RETURN_VALUE */
    rcall EEPROM_READ_N_INC
    /* Comparing both IPs */
    cp    DATA1, RETURN_VALUE
    brne  ARP_PROCESS_EXIT_SUCCESS /* Not for me, just return */
    /* Loop counter */
    dec   COUNTER_REG
    brne  ARP_PROCESS_CHECK_MY_IP_LOOP
    /* }}} */
    /* Prepare ARP packet to be sent as response {{{ */
    ldi   ZH, hi8(ARP_PAYLOAD + ARP_OPER + 1) /* First byte not used */
    ldi   ZL, lo8(ARP_PAYLOAD + ARP_OPER + 1)
    ldi   DATA1, ARP_OPER_REPLY
    st    Z+, DATA1  /* Z ends up in the first address of the sender's MAC */

    /* Write sender (mine) MAC and copy original MAC into destination (10 bytes
     * ahead) */
    ldi   COUNTER_REG, MAC_SIZE_IN_BYTES
    ldi   YH, hi8(EEPROM_MAC_ADDR)
    ldi   YL, lo8(EEPROM_MAC_ADDR)
ARP_PROCESS_KEEP_WRITING_MY_MAC:
    /* Write previous target MAC into destination MAC */
    ld    DATA1, Z
    std   Z+(ARP_THA - ARP_SHA), DATA1
    /* Set Addr to read from EEPROM, read and write into SRAM */
    rcall EEPROM_READ_N_INC
    st    Z+, RETURN_VALUE
    dec   COUNTER_REG
    brne  ARP_PROCESS_KEEP_WRITING_MY_MAC

    /* Write my own IP and copy original IP into destination (10 bytes ahead) */
    ldi   COUNTER_REG, IPV4_SIZE_IN_BYTES
    ldi   YH, hi8(EEPROM_IP_ADDR)
    ldi   YL, lo8(EEPROM_IP_ADDR)

ARP_PROCESS_WRITE_IP_BYTE:
    /* Copy IP from src to dst */
    ld    DATA1, Z
    std   Z+(ARP_TPA - ARP_SPA), DATA1
    /* Set addr to read from EEPROM, read into DATA1 and write it into SRAM */
    rcall EEPROM_READ_N_INC
    st    Z+,  RETURN_VALUE
    dec   COUNTER_REG
    brne  ARP_PROCESS_WRITE_IP_BYTE
    /* }}} */
    /* Send ARP packet back {{{ */
    rcall ETH_WRITE_BUFFER_PACKET_HEADER
    ldi   ZH, hi8(ARP_PAYLOAD)
    ldi   ZL, lo8(ARP_PAYLOAD)
    ldi   ARG_REG1, ARP_PAYLOAD_LEN
ERR_SET
    rcall ETH_WRITE_Z_TO_TRANSMIT_BUFFER
    rcall ETH_WRITE_BUFFER_PACKET_PAYLOAD_FINISH
    /* }}} */

ARP_PROCESS_EXIT_SUCCESS:
    ldi   RETURN_VALUE, 0
    pop   COUNTER_REG
    pop   YL
    pop   YH
    pop   ZL
    pop   ZH
    ret
/* }}} */
