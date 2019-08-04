/* vim: set filetype=S foldmethod=marker: */
.NOLIST
#include <avr/io.h>
#include "defs.h"
#include "enc28j60.h"
#include "arp.h"
#include "eeprom_data.h"
#include "ipv4.h"
.LIST

#define DATA1                TMP_REG2
#define ARP_PAYLOAD_LEN      28
/* How many entries can the ARP table hold */
#define ARP_TABLE_SIZE       4
/* How many time the entry has been requested */
#define ACCESS_CNT           1
#define ARP_TABLE_ENTRY_LEN  (IPV4_ADDR_LEN + MAC_ADDR_LEN + ACCESS_CNT)
#define ARP_TABLE_LEN        (ARP_TABLE_ENTRY_LEN * ARP_TABLE_SIZE)

/* Offsets in ARP table */
#define ARP_TABLE_IPV4        0
#define ARP_TABLE_MAC         (IPV4_ADDR_LEN)
#define ARP_TABLE_ACCESS_CNT  (ARP_TABLE_MAC + MAC_ADDR_LEN)

.global ARP_HANDLE_PKT
.global ARP_REQUEST
.global ARP_INIT
.global ARP_GET_MAC_ADDR_PTR

.section .data
SRAM_ARP_PAYLOAD: .skip ARP_PAYLOAD_LEN
SRAM_ARP_TABLE:   .skip ARP_TABLE_LEN

.section .text

/*******************************************************************************
 * ARP init {{{
 ******************************************************************************/
ARP_INIT:
    ldi  ZL, lo8(SRAM_ARP_TABLE)
    ldi  ZH, hi8(SRAM_ARP_TABLE)
    ldi  COUNTER_REG, ARP_TABLE_LEN
    clr  TMP_REG1
ZERO_OUT_ARP_TABLE_LOOP:
    st   Z+, TMP_REG1
    dec  COUNTER_REG
    brne ZERO_OUT_ARP_TABLE_LOOP
    ret
/* }}} */
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
    ldi   ZH, hi8(SRAM_ARP_PAYLOAD)
    ldi   ZL, lo8(SRAM_ARP_PAYLOAD)
ARP_PROCESS_READ_PAYLOAD:
    ETH_READ_NEXT_BYTE
    st    Z+, RETURN_VALUE
    dec   COUNTER_REG
    brne  ARP_PROCESS_READ_PAYLOAD

    ETH_READ_BUFFER_END
    /* }}} */
    /* Check that ARP is for me  {{{ */
    ldi   COUNTER_REG, IPV4_SIZE_IN_BYTES
    /* Z */
    ldi   ZH, hi8(SRAM_ARP_PAYLOAD + ARP_TPA)
    ldi   ZL, lo8(SRAM_ARP_PAYLOAD + ARP_TPA)
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
    /* Check if Request or Reply {{{ */
    ldi   ZH, hi8(SRAM_ARP_PAYLOAD + ARP_OPER + 1) /* First byte not used */
    ldi   ZL, lo8(SRAM_ARP_PAYLOAD + ARP_OPER + 1)
    ld    TMP_REG1, Z
    cpi   TMP_REG1, ARP_OPER_REPLY
    brne  ARP_IS_REQUEST
    rjmp  ARP_IS_REPLY
    /* }}} */
    /* Prepare ARP packet to be sent as response {{{ */
ARP_IS_REQUEST:
    ldi   DATA1, ARP_OPER_REPLY
    st    Z+, DATA1  /* Z ends up in the first address of the sender's MAC */

    /* Write sender (mine) MAC and copy original MAC into destination (10 bytes
     * ahead) */
    ldi   COUNTER_REG, MAC_ADDR_LEN
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
    rcall ARP_SEND_PACKET
    /* }}} */

ARP_PROCESS_EXIT_SUCCESS:
    ldi   RETURN_VALUE, 0
    pop   COUNTER_REG
    pop   YL
    pop   YH
    pop   ZL
    pop   ZH
    ret

ARP_IS_REPLY: /* {{{ */
    /* Find an empty space in the ARP table */
    ldi   YL, lo8(SRAM_ARP_TABLE)
    ldi   YH, hi8(SRAM_ARP_TABLE)
    ldi   COUNTER_REG, ARP_TABLE_SIZE
    /* To find an empty entry on the ARP table, we are going to check if the
     * first byte of the IP address is zero, if so, we assume that the entry is
     * empty, else, we jump to the next entry and check again */
FIND_EMPTY_ENTRY_LOOP: /* {{{ */
    ld    TMP_REG1, Y
    tst   TMP_REG1
    breq  EMPTY_ENTRY_FOUND
    dec   COUNTER_REG
    breq  OVERWRITE_LESS_ACCESSED
    adiw  YL, ARP_TABLE_ENTRY_LEN

EMPTY_ENTRY_FOUND: /* }}} */
    /* Copy IP addr {{{ */
    ldi   ZL, lo8(SRAM_ARP_PAYLOAD + ARP_SPA)
    ldi   ZH, hi8(SRAM_ARP_PAYLOAD + ARP_SPA)
    ldi   COUNTER_REG, IPV4_ADDR_LEN
COPY_IP_ADDR_LOOP:
    ld    TMP_REG1, Z+
    st    Y+, TMP_REG1
    dec   COUNTER_REG
    brne  COPY_IP_ADDR_LOOP
    /* }}} */
    /* Copy MAC addr {{{ */
    ldi   ZL, lo8(SRAM_ARP_PAYLOAD + ARP_SHA)
    ldi   ZH, hi8(SRAM_ARP_PAYLOAD + ARP_SHA)
    ldi   COUNTER_REG, MAC_ADDR_LEN
COPY_MAC_ADDR_LOOP:
    ld    TMP_REG1, Z+
    st    Y+, TMP_REG1
    dec   COUNTER_REG
    brne  COPY_MAC_ADDR_LOOP
    /* }}} */
    /* Set access counter to zero  {{{ */
    clr   TMP_REG1
    st    Y, TMP_REG1
    /* }}} */
    rjmp  ARP_PROCESS_EXIT_SUCCESS

OVERWRITE_LESS_ACCESSED:
/*TODO...*/
    rjmp  ARP_PROCESS_EXIT_SUCCESS
    /* }}} */
/* }}} */
/*******************************************************************************
 * ARP request {{{
 ******************************************************************************/
ARP_REQUEST:
    /* EEPROM_ARP_REQUEST does NOT include TPA {{{ */
    ldi   COUNTER_REG, EEPROM_ARP_REQUEST_END - EEPROM_ARP_REQUEST
    ldi   YL, lo8(EEPROM_ARP_REQUEST)
    ldi   YH, hi8(EEPROM_ARP_REQUEST)
    ldi   ZL, lo8(SRAM_ARP_PAYLOAD)
    ldi   ZH, hi8(SRAM_ARP_PAYLOAD)
ARP_FROM_EEPROM_LOOP:
    rcall EEPROM_READ_N_INC
    st    Z+, RETURN_VALUE
    dec   COUNTER_REG
    brne  ARP_FROM_EEPROM_LOOP
    /* }}} */
    /* TPA Copy Target IP Address {{{ */
    ldi   YL, lo8(SRAM_COMM_IP_ADDR_DST)
    ldi   YH, hi8(SRAM_COMM_IP_ADDR_DST)
    ldi   ARG_REG1, IPV4_ADDR_LEN
    rcall MEMCPY
    /* }}} */
    /* SPA Copy SRC IP Address  {{{ */
    /* TODO: implement EEPROM_MEMCPY */
    sbiw  ZL, (ARP_TPA - ARP_SPA)
    ldi   YL, lo8(EEPROM_IP_ADDR)
    ldi   YH, hi8(EEPROM_IP_ADDR)
    ldi   COUNTER_REG, IPV4_ADDR_LEN
COPY_SRC_IP_LOOP:
    rcall EEPROM_READ_N_INC
    st    Z+, RETURN_VALUE
    dec   COUNTER_REG
    brne  COPY_SRC_IP_LOOP
    /* }}} */
    /* Set Ethernet Dst address and Type/Len {{{ */
    ldi   TMP_REG2, (1 << ENC_MAC_DST_PTR_BROADCAST_BIT)
    sts   SRAM_ENC_MAC_DST_PTR, TMP_REG2
    ldi   TMP_REG2, (1 << ENC_TYPE_LEN_PTR_ARP)
    sts   SRAM_ENC_TYPE_LEN_PTR, TMP_REG2
    /* }}} */
    rcall ARP_SEND_PACKET
    ret
/* }}} */
/*******************************************************************************
 * ARP Send packet {{{
 * TODO: it could be moved back to ARP_HANDLE_PKT, together with the label, then
 * ARP_REQUEST could rcall it.
 ******************************************************************************/
ARP_SEND_PACKET:
    rcall ETH_WRITE_BUFFER_PACKET_HEADER
    ldi   ZH, hi8(SRAM_ARP_PAYLOAD)
    ldi   ZL, lo8(SRAM_ARP_PAYLOAD)
    ldi   ARG_REG1, ARP_PAYLOAD_LEN
    rcall ETH_WRITE_Z_TO_TRANSMIT_BUFFER
    rcall ETH_WRITE_BUFFER_PACKET_PAYLOAD_FINISH
    ret
/* }}} */
/*******************************************************************************
 * ARP Get MAC PTR {{{
 * Input:
 *   Y Points to an IP address
 * Output:
 *   Y Points to an MAC address
 * RETURN_VALUE => 0 if address found
 ******************************************************************************/
ARP_GET_MAC_ADDR_PTR:
    push  ZL
    push  ZH

    ldi   ZL, lo8(SRAM_ARP_TABLE + ARP_TABLE_IPV4)
    ldi   ZH, hi8(SRAM_ARP_TABLE + ARP_TABLE_IPV4)
    ldi   COUNTER_REG, ARP_TABLE_SIZE
    ldi   ARG_REG1, IPV4_ADDR_LEN /* length for memcmp */
ARP_TABLE_LOOP:
    rcall MEMCMP
    tst   RETURN_VALUE
    breq  ARP_ENTRY_FOUND
    dec   COUNTER_REG
    brne  ARP_TABLE_LOOP
    rjmp  ARP_GET_MAC_ADDR_EXIT
ARP_ENTRY_FOUND:
    movw  YL, ZL
    adiw  YL, (ARP_TABLE_MAC - ARP_TABLE_IPV4)

ARP_GET_MAC_ADDR_EXIT:
    pop   ZH
    pop   ZL
    ret
.end
