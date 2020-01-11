/* vim: set filetype=S foldmethod=marker: */
/* INCLUDES {{{1 */
.NOLIST
#include <avr/io.h>
#include "macros.S"
#include "defs.h"
#include "enc28j60.h"
#include "arp.h"
#include "eeprom_data.h"
#include "ipv4.h"
.LIST

/* MACORS {{{1 ---------------------------------------------------------------*/
#define ARP_PAYLOAD_LEN      28
/* How many entries can the ARP table hold */
#define ARP_TABLE_SIZE       4
#define ARP_TABLE_ENTRY_LEN  (IPV4_ADDR_LEN + MAC_ADDR_LEN)
#define ARP_TABLE_LEN        (ARP_TABLE_ENTRY_LEN * ARP_TABLE_SIZE)

#define ARP_TABLE_CURRENT_ENTRY_LEN 1

/* Offsets in ARP table */
#define ARP_TABLE_IPV4        0
#define ARP_TABLE_MAC         (IPV4_ADDR_LEN)

/* GLOBAL {{{1 ---------------------------------------------------------------*/
.global ARP_HANDLE_PKT
.global ARP_INIT
.global ARP_GET_MAC_ADDR_PTR

/* DATA  {{{1 ----------------------------------------------------------------*/
.section .data
SRAM_ARP_PAYLOAD:   .skip ARP_PAYLOAD_LEN
/* The last byte on the table is the offset of the current entry where ARP reply
 * are going to be store */
SRAM_ARP_TABLE:     .skip (ARP_TABLE_LEN + ARP_TABLE_CURRENT_ENTRY_LEN)

/* TEXT {{{1 -----------------------------------------------------------------*/
.section .text

/* ARP init {{{2 -------------------------------------------------------------*/
ARP_INIT:
    ldi   zl, lo8(SRAM_ARP_TABLE)
    ldi   zh, hi8(SRAM_ARP_TABLE)
    ldi   a1, (ARP_TABLE_LEN + ARP_TABLE_CURRENT_ENTRY_LEN)
    rcall BZERO
    ret

/* Handle ARP packet {{{2 ------------------------------------------------------
 * 1. Read ARP payload into SRAM
 * 2. Check ARP is for me
 * 3. Modify ARP payload for response
 * 4. Write ARP response into Ethernet module */
ARP_HANDLE_PKT:
    push  zh
    push  zl
    push  xh
    push  xl

    /* Read ARP payload (28 bytes) into SRAM {{{3 */
    rcall ETH_READ_BUFFER_START
    ldi   zh, hi8(SRAM_ARP_PAYLOAD)
    ldi   zl, lo8(SRAM_ARP_PAYLOAD)
    ldi   a1, ARP_PAYLOAD_LEN
    rcall S_MEMCPY

    ETH_READ_BUFFER_END
    /* Check that ARP is for me  {{{3 */
    sbiw  zl, (ARP_PAYLOAD_LEN - ARP_TPA) /* z was at the end of ARP payload */
    ldi   xh, hi8(EEPROM_IP_ADDR)
    ldi   xl, lo8(EEPROM_IP_ADDR)
    ldi   a1, IPV4_ADDR_LEN
    rcall E_MEMCMP
    brne  ARP_PROCESS_EXIT_SUCCESS /* Not for me, just return */
    /* Check if Request or Reply {{{3 */
    /* z was at TPA. First byte of OPER not used */
    sbiw  zl, (ARP_TPA - ARP_OPER - 1)
    ld    t1, z
    cpi   t1, ARP_OPER_REPLY
    breq  ARP_IS_REPLY
ARP_IS_REQUEST: /* {{{3 */
    /* Set OPER {{{4 */
    ldi   t2, ARP_OPER_REPLY
    st    z+, t2  /* z ends up in the first address of the sender's MAC (SHA) */

    /* Set SHA and THA at the same time {{{4 */
    ldi   t3, MAC_ADDR_LEN
    ldi   xh, hi8(EEPROM_MAC_ADDR)
    ldi   xl, lo8(EEPROM_MAC_ADDR)
    /* Write previous target MAC into destination MAC */
0:  ld    t2, z
    std   z+(ARP_THA - ARP_SHA), t2
    /* Read from EEPROM and write into SRAM */
    rcall EEPROM_READ_N_INC
    st    z+, a4
    dec   t3
    brne  0b

    /* Set SPA and TPA at the same time {{{4 */
    ldi   t3, IPV4_ADDR_LEN
    ldi   xh, hi8(EEPROM_IP_ADDR)
    ldi   xl, lo8(EEPROM_IP_ADDR)
    /* Copy IP from src to dst */
0:  ld    t2, z
    std   z+(ARP_TPA - ARP_SPA), t2
    /* Read from EEPROM and write it into SRAM */
    rcall EEPROM_READ_N_INC
    st    z+, a4
    dec   t3
    brne  0b
    /* Send ARP packet back {{{4 */
    rcall ARP_SEND_PACKET
    rjmp  ARP_PROCESS_EXIT_SUCCESS

ARP_IS_REPLY: /* {{{3 */
    /* Using Round Robin, insert the ARP reply into the ARP table */
    /* Set z, then load current offset using z, update current offset and stored
     * back using z, then update z to point to the entry to write to. We are
     * going to start writing in the second slot, but it has a smallest
     * footprint than other options */
    ldi   zl, lo8(SRAM_ARP_TABLE)
    ldi   zh, hi8(SRAM_ARP_TABLE)
    ldd   t1, z + (ARP_TABLE_LEN) /* Load current entry offset */
    subi  t1, -(ARP_TABLE_ENTRY_LEN) /* Add entry length to offset */
    cpi   t1, ARP_TABLE_LEN /* check if reached end of table */
    brne  0f
    clr   t1
0:  std   z + (ARP_TABLE_LEN), t1 /* Store value back */
    DEBUG(rcall PRINT_CURRENT_ENTRY)
    add   zl, t1
    adc   zh, zero

    /* Copy SPA {{{4 */
    ldi   xl, lo8(SRAM_ARP_PAYLOAD + ARP_SPA)
    ldi   xh, hi8(SRAM_ARP_PAYLOAD + ARP_SPA)
    ldi   a1, IPV4_ADDR_LEN
    rcall MEMCPY

    /* Copy SHA {{{4 */
    sbiw  xl, (ARP_THA - ARP_SHA) /* x was at THA */
    ldi   a1, MAC_ADDR_LEN
    rcall MEMCPY

    /* }}}3 */
ARP_PROCESS_EXIT_SUCCESS:
    pop   xl
    pop   xh
    pop   zl
    pop   zh
    ret

/* ARP request {{{2 ------------------------------------------------------------
 * x: Pointer to Targer Protocol Address (TPA) */
ARP_REQUEST:
    push  xl
    push  xh
    /* Copy default ARP request from EEPROM {{{3
     * default ARP doesn't include TPA */
    ldi   xl, lo8(EEPROM_ARP_REQUEST)
    ldi   xh, hi8(EEPROM_ARP_REQUEST)
    ldi   zl, lo8(SRAM_ARP_PAYLOAD)
    ldi   zh, hi8(SRAM_ARP_PAYLOAD)
    ldi   a1, EEPROM_ARP_REQUEST_END - EEPROM_ARP_REQUEST
    rcall E_MEMCPY

    /* TPA Copy Target IP Address {{{3 */
    pop   xh
    pop   xl
    ldi   a1, IPV4_ADDR_LEN
    rcall MEMCPY

    /* SPA Copy SRC IP Address  {{{3 */
    sbiw  zl, (ARP_TPA - ARP_SPA + IPV4_ADDR_LEN)
    ldi   xl, lo8(EEPROM_IP_ADDR)
    ldi   xh, hi8(EEPROM_IP_ADDR)
    rcall E_MEMCPY

    /* Set Ethernet Dst Address to Broadcast {{{3 */
    ldi   t1, (1 << ENC_MAC_DST_PTR_BROADCAST_BIT)
    sts   SRAM_ENC_MAC_DST_PTR, t1

    /* Send ARP packet back {{{3 */
    /* BEWARE, ARP_SEND_PACKET is called from ARP_HANDLE_PKT, therefore nothing
     * else can be done between ARP_SEND_PACKET and ret */
ARP_SEND_PACKET:
    /* Set Ethernet Type/Len to ARP */
    ldi   t1, (EEPROM_TYPE_LEN_ARP - EEPROM_TYPE_LEN)
    sts   SRAM_ENC_TYPE_LEN_OFFSET, t1

    rcall ETH_WRITE_BUFFER_PACKET_HEADER
    sbiw  zl, ARP_THA /* z was left at THA */
    ldi   a1, ARP_PAYLOAD_LEN
    rcall ETH_WRITE_Z_TO_TRANSMIT_BUFFER
    rcall ETH_WRITE_BUFFER_PACKET_PAYLOAD_FINISH
    ret

/* ARP Get MAC PTR {{{2 --------------------------------------------------------
 * Look for the IP address pointed by x
 *   If found, set [a4:a3] to address of corresponding MAC address
 *   and set SREG(Z). Else, [a4:a3] is unchanged and clear SREG(Z)
 */
ARP_GET_MAC_ADDR_PTR:
    push  zl
    push  zh

    ldi   zl, lo8(SRAM_ARP_TABLE + ARP_TABLE_IPV4)
    ldi   zh, hi8(SRAM_ARP_TABLE + ARP_TABLE_IPV4)
    ldi   t3, ARP_TABLE_SIZE
    ldi   a1, IPV4_ADDR_LEN
    /* Loop through ARP table looking for IP Address */
0:  rcall MEMCMP
    breq  ARP_ENTRY_FOUND
    adiw  zl, ARP_TABLE_ENTRY_LEN
    dec   t3
    brne  0b
    /* ARP entry not found */
    rcall ARP_REQUEST
    clz
    rjmp  ARP_GET_MAC_ADDR_EXIT
ARP_ENTRY_FOUND:
    adiw  zl, (ARP_TABLE_MAC - ARP_TABLE_IPV4)
    movw  a3, zl
    sez

ARP_GET_MAC_ADDR_EXIT:
    pop   zh
    pop   zl
    ret

#ifndef NDEBUG
PRINT_CURRENT_ENTRY:
    DEBUG(PRINT_STR_SAFE STR_ARP_WR_TBL_ENTRY)
    DEBUG(PRINT_REG_SAFE t1)
    DEBUG(PRINT_NEWLINE_SAFE)
    ret
#endif
.end
