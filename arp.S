/* vim: set filetype=S foldmethod=marker: */
/* INCLUDES {{{1 */
.NOLIST
#include <avr/io.h>
#include "defs.h"
#include "enc28j60.h"
#include "arp.h"
#include "eeprom_data.h"
#include "ipv4.h"
.LIST

/* MACORS {{{1 ---------------------------------------------------------------*/
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

/* GLOBAL {{{1 ---------------------------------------------------------------*/
.global ARP_HANDLE_PKT
.global ARP_INIT
.global ARP_GET_MAC_ADDR_PTR

/* DATA  {{{1 ----------------------------------------------------------------*/
.section .data
SRAM_ARP_PAYLOAD: .skip ARP_PAYLOAD_LEN
SRAM_ARP_TABLE:   .skip ARP_TABLE_LEN

/* TEXT {{{1 -----------------------------------------------------------------*/
.section .text

/* ARP init {{{2 -------------------------------------------------------------*/
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

/* Handle ARP packet {{{2 ------------------------------------------------------
 * 1. Read ARP payload into SRAM
 * 2. Check ARP is for me
 * 3. Modify ARP payload for response
 * 4. Write ARP response into Ethernet module */
ARP_HANDLE_PKT:
    push  ZH
    push  ZL
    push  YH
    push  YL
    push  COUNTER_REG

    /* Read ARP payload (28 bytes) into SRAM {{{3 */
    rcall ETH_READ_BUFFER_START
    ldi   COUNTER_REG, ARP_PAYLOAD_LEN
    ldi   ZH, hi8(SRAM_ARP_PAYLOAD)
    ldi   ZL, lo8(SRAM_ARP_PAYLOAD)
ARP_PROCESS_READ_PAYLOAD:
    ETH_READ_NEXT_BYTE
    st    Z+, RTV_L_REG
    dec   COUNTER_REG
    brne  ARP_PROCESS_READ_PAYLOAD

    ETH_READ_BUFFER_END
    /* Check that ARP is for me  {{{3 */
    sbiw  ZL, (ARP_PAYLOAD_LEN - ARP_TPA) /* Z was at the end of ARP payload */
    ldi   YH, hi8(EEPROM_IP_ADDR)
    ldi   YL, lo8(EEPROM_IP_ADDR)
    ldi   ARG_REG1, IPV4_ADDR_LEN
    rcall ES_MEMCMP
    brne  ARP_PROCESS_EXIT_SUCCESS /* Not for me, just return */
    /* Check if Request or Reply {{{3 */
    /* Z was at TPA. First byte of OPER not used */
    sbiw  ZL, (ARP_TPA - ARP_OPER - 1)
    ld    TMP_REG1, Z
    cpi   TMP_REG1, ARP_OPER_REPLY
    breq  ARP_IS_REPLY
ARP_IS_REQUEST: /* {{{3 */
    /* Set OPER {{{4 */
    ldi   DATA1, ARP_OPER_REPLY
    st    Z+, DATA1  /* Z ends up in the first address of the sender's MAC */

    /* Set SHA and THA at the same time {{{4 */
    ldi   COUNTER_REG, MAC_ADDR_LEN
    ldi   YH, hi8(EEPROM_MAC_ADDR)
    ldi   YL, lo8(EEPROM_MAC_ADDR)
ARP_PROCESS_KEEP_WRITING_MY_MAC:
    /* Write previous target MAC into destination MAC */
    ld    DATA1, Z
    std   Z+(ARP_THA - ARP_SHA), DATA1
    /* Set Addr to read from EEPROM, read and write into SRAM */
    rcall EEPROM_READ_N_INC
    st    Z+, RTV_L_REG
    dec   COUNTER_REG
    brne  ARP_PROCESS_KEEP_WRITING_MY_MAC

    /* Set SPA and TPA at the same time {{{4 */
    ldi   COUNTER_REG, IPV4_ADDR_LEN
    ldi   YH, hi8(EEPROM_IP_ADDR)
    ldi   YL, lo8(EEPROM_IP_ADDR)

ARP_PROCESS_WRITE_IP_BYTE:
    /* Copy IP from src to dst */
    ld    DATA1, Z
    std   Z+(ARP_TPA - ARP_SPA), DATA1
    /* Set addr to read from EEPROM, read into DATA1 and write it into SRAM */
    rcall EEPROM_READ_N_INC
    st    Z+,  RTV_L_REG
    dec   COUNTER_REG
    brne  ARP_PROCESS_WRITE_IP_BYTE
    /* Send ARP packet back {{{4 */
    rcall ARP_SEND_PACKET
    rjmp  ARP_PROCESS_EXIT_SUCCESS

ARP_IS_REPLY: /* {{{3 */
    /* Find an empty space in the ARP table {{{4 */
    ldi   ZL, lo8(SRAM_ARP_TABLE)
    ldi   ZH, hi8(SRAM_ARP_TABLE)
    ldi   COUNTER_REG, ARP_TABLE_SIZE
    /* To find an empty entry on the ARP table, we are going to check if the
     * first byte of the IP address is zero, if so, we assume that the entry is
     * empty, else, we jump to the next entry and check again */
FIND_EMPTY_ENTRY_LOOP:
    ld    TMP_REG1, Z
    tst   TMP_REG1
    breq  EMPTY_ENTRY_FOUND
    dec   COUNTER_REG
    breq  OVERWRITE_LESS_ACCESSED
    adiw  ZL, ARP_TABLE_ENTRY_LEN

EMPTY_ENTRY_FOUND:
    /* Copy SPA {{{4 */
    ldi   YL, lo8(SRAM_ARP_PAYLOAD + ARP_SPA)
    ldi   YH, hi8(SRAM_ARP_PAYLOAD + ARP_SPA)
    ldi   ARG_REG1, IPV4_ADDR_LEN
    rcall MEMCPY

    /* Copy SHA {{{4 */
    sbiw  YL, (ARP_THA - ARP_SHA) /* Y was at THA */
    ldi   ARG_REG1, MAC_ADDR_LEN
    rcall MEMCPY

    /* Set access counter to zero  {{{4 */
    clr   TMP_REG1
    st    Z, TMP_REG1
    /* }}}3 */
ARP_PROCESS_EXIT_SUCCESS:
    pop   COUNTER_REG
    pop   YL
    pop   YH
    pop   ZL
    pop   ZH
    ret

OVERWRITE_LESS_ACCESSED: /* {{{3 */
    /*TODO: find a less accessed entry */
    sbiw  ZL, ARP_TABLE_LEN
    rjmp  EMPTY_ENTRY_FOUND

/* ARP request {{{2 ------------------------------------------------------------
 * Y: Pointer to Targer Protocol Address (TPA) */
ARP_REQUEST:
    push  YL
    push  YH
    /* Copy default ARP request from EEPROM {{{3
     * default ARP doesn't include TPA */
    ldi   YL, lo8(EEPROM_ARP_REQUEST)
    ldi   YH, hi8(EEPROM_ARP_REQUEST)
    ldi   ZL, lo8(SRAM_ARP_PAYLOAD)
    ldi   ZH, hi8(SRAM_ARP_PAYLOAD)
    ldi   ARG_REG1, EEPROM_ARP_REQUEST_END - EEPROM_ARP_REQUEST
    rcall ES_MEMCPY

    /* TPA Copy Target IP Address {{{3 */
    pop   YH
    pop   YL
    ldi   ARG_REG1, IPV4_ADDR_LEN
    rcall MEMCPY

    /* SPA Copy SRC IP Address  {{{3 */
    sbiw  ZL, (ARP_TPA - ARP_SPA + IPV4_ADDR_LEN)
    ldi   YL, lo8(EEPROM_IP_ADDR)
    ldi   YH, hi8(EEPROM_IP_ADDR)
    rcall ES_MEMCPY

    /* Set Ethernet Dst address and Type/Len {{{3 */
    ldi   TMP_REG2, (1 << ENC_MAC_DST_PTR_BROADCAST_BIT)
    sts   SRAM_ENC_MAC_DST_PTR, TMP_REG2
    ldi   TMP_REG2, (1 << ENC_TYPE_LEN_PTR_ARP)
    sts   SRAM_ENC_TYPE_LEN_PTR, TMP_REG2

    /* Send ARP packet back {{{3 */
    /* BEWARE, ARP_SEND_PACKET is called from ARP_HANDLE_PKT, therefore nothing
     * else can be done between ARP_SEND_PACKET and ret */
ARP_SEND_PACKET:
    rcall ETH_WRITE_BUFFER_PACKET_HEADER
    sbiw  ZL, ARP_THA /* Z was left at THA */
    ldi   ARG_REG1, ARP_PAYLOAD_LEN
    rcall ETH_WRITE_Z_TO_TRANSMIT_BUFFER
    rcall ETH_WRITE_BUFFER_PACKET_PAYLOAD_FINISH
    ret

/* ARP Get MAC PTR {{{2 --------------------------------------------------------
 * Look for the IP address pointed by Y
 *   If found, set Y to address of corresponding MAC address and set SREG(Z)
 *   Else, Y value is undefined and clear SREG(Z)
 * SREG(Z) => 1 if address found, 0 otherwise */
ARP_GET_MAC_ADDR_PTR:
    push  ZL
    push  ZH

    ldi   ZL, lo8(SRAM_ARP_TABLE + ARP_TABLE_IPV4)
    ldi   ZH, hi8(SRAM_ARP_TABLE + ARP_TABLE_IPV4)
    ldi   COUNTER_REG, ARP_TABLE_SIZE
    ldi   ARG_REG1, IPV4_ADDR_LEN
ARP_TABLE_LOOP:
    rcall MEMCMP
    breq  ARP_ENTRY_FOUND
    dec   COUNTER_REG
    brne  ARP_TABLE_LOOP
    /* ARP entry not found */
    rcall ARP_REQUEST
    clz
    rjmp  ARP_GET_MAC_ADDR_EXIT
ARP_ENTRY_FOUND:
    movw  YL, ZL
    adiw  YL, (ARP_TABLE_MAC - ARP_TABLE_IPV4)
    sez

ARP_GET_MAC_ADDR_EXIT:
    pop   ZH
    pop   ZL
    ret
.end
