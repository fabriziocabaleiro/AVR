/* vim: set filetype=S foldmethod=marker: */
/* INCLUDES {{{1 */
.NOLIST
#include <avr/io.h>
#include "defs.h"
#include "spi.h"
#include "enc28j60.h"
#include "eeprom_data.h"
.LIST

/* MACORS {{{1 ---------------------------------------------------------------*/
#define FLAG_KEEP_OPEN_AFTER_WRITE 0

/* GLOBAL {{{1 ---------------------------------------------------------------*/
.global ETH_INIT
.global ETH_READ_CONTROL_REGISTER
.global ETH_BIT_FIELD_SET
.global ETH_BIT_FIELD_CLEAR
.global ETH_READ_BUFFER_START
.global ETH_READ_RECEIVE_HEADER
.global ETH_CHECK_RECEIVE_STATUS_VECTOR
.global ETH_READ_MAC_ADDRS_N_LEN_TYPE
.global ETH_PKT_PROCESSED
.global ETH_WRITE_BUFFER_PACKET_HEADER
.global ETH_SET_LISTEN_ON_SPI
.global ETH_WRITE_Z_TO_TRANSMIT_BUFFER
.global ETH_WRITE_BUFFER_PACKET_PAYLOAD_FINISH
.global ETH_MOVE_RDPT
.global ETH_UNSET_FLAG_KEEP_OPEN_AFTER_WRITE
.global ETH_SET_FLAG_KEEP_OPEN_AFTER_WRITE

.global SRAM_ENC_SRC_ADDR
.global SRAM_TYPE_LEN_H
.global SRAM_TYPE_LEN_L
.global SRAM_RPKT_STATUS2
.global SRAM_RPKT_STATUS3
.global SRAM_ENC_MAC_DST_PTR
.global SRAM_ENC_TYPE_LEN_PTR

/* DATA  {{{1 ----------------------------------------------------------------*/
.section .data
/* Status vector, added by ENC28J60 HW before Ethernet header */
SRAM_RPKT_N_PKT_L:      .skip 1
SRAM_RPKT_N_PKT_H:      .skip 1
SRAM_RPKT_BYTE_COUNT_L: .skip 1
SRAM_RPKT_BYTE_COUNT_H: .skip 1
SRAM_RPKT_STATUS2:      .skip 1
SRAM_RPKT_STATUS3:      .skip 1
/* Ethernet header, this fields are updated every time we start processing a
 * packet */
SRAM_ENC_HEADER:
SRAM_ENC_DST_ADDR:      .skip 6
SRAM_ENC_SRC_ADDR:      .skip 6
SRAM_TYPE_LEN_H:        .skip 1
SRAM_TYPE_LEN_L:        .skip 1
/* Pointer to Dst MAC address */
SRAM_ENC_MAC_DST_PTR:   .skip 2
/* Pointer to TYPE/LEN value */
SRAM_ENC_TYPE_LEN_PTR:  .skip 2

/* Flags to modify behavior of routines */
SRAM_ENC_FLAGS:         .skip 1

/* TEXT {{{1 -----------------------------------------------------------------*/
.section .text

/* Initialize everything {{{2 ------------------------------------------------*/
ETH_INIT:
    sts   SRAM_ENC_FLAGS, ZERO_REG
    rcall ETH_SOFTWARE_RESET
    rcall ETH_BUFFER_INIT
    rcall ETH_MAC_INIT
    rcall ETH_ENABLE_RECEIVE
#if USE_INTIE
    rcall ETH_ENABLE_RECEIVE_INTERRUPT
#endif
    ret

/* Read Control Register {{{2 --------------------------------------------------
 * To read a control register first we send the command "000" together with the
 * address of the register, i.e. "000AAAAA" through SPI, ignoring the byte that
 * is being transmitted during the command + address transmission, then, we send
 * a dummy message to activate the SCK and read a byte.
 *
 * ARG_REG1 is the register to be read */
ETH_READ_CONTROL_REGISTER:
    SPI_SELECT_ETH
    rcall SPI_MASTER_TRANSMIT
    rcall SPI_MASTER_TRANSMIT
    SPI_END_ETH
    ret

/* Write control register  {{{2 ------------------------------------------------
 * Send command and address together, then send the new value of the space that
 * the address is pointing to
 *
 * ARG_REG1 is the register to be written
 * ARG_REG2 is the value of the register */
ETH_WRITE_CONTROL_REGISTER:
    /* command is 010AAAAA, then corresponding prefix */
    sbr   ARG_REG1, ETH_SPI_CMD_WCR
    rjmp  0f

/* Set the given bits into the register {{{2 -----------------------------------
 * Inputs:
 * - ARG_REG1: Register address
 * - ARG_REG2: Mask with bits that are going to be set */
ETH_BIT_FIELD_SET:
    /* command is 100AAAAA, then corresponding prefix */
    sbr   ARG_REG1, ETH_SPI_CMD_BFS
    rjmp  0f

/* Clear the given bits into the register {{{2 ---------------------------------
 * Inputs:
 * - ARG_REG1: Register address
 * - ARG_REG2: Mask with bits that are going to be clear */
ETH_BIT_FIELD_CLEAR:
    /* command is 101AAAAA, then corresponding prefix */
    sbr   ARG_REG1, ETH_SPI_CMD_BFC

/* ETH_WRITE_CONTROL_REGISTER, ETH_BIT_FIELD_SET and ETH_BIT_FIELD_CLEAR {{{2 --
 * common part */
0:  SPI_SELECT_ETH
    rcall SPI_MASTER_TRANSMIT
    mov   ARG_REG1, ARG_REG2
    rcall SPI_MASTER_TRANSMIT
    SPI_END_ETH
    ret

/* Wait until device is ready {{{2 -------------------------------------------*/
ETH_WAIT_UNTIL_READY:
    ldi   ARG_REG1, ENC_COMMON_ESTAT
    rcall ETH_READ_CONTROL_REGISTER
    sbrs  RTV_L_REG, ENC_COMMON_ESTAT_CLKRDY
    rjmp  ETH_WAIT_UNTIL_READY
    ret

/* Enable packet reception {{{2 ----------------------------------------------*/
ETH_ENABLE_RECEIVE:
    rcall ETH_WAIT_UNTIL_READY
    ldi   ARG_REG1, ENC_COMMON_ECON1
    ldi   ARG_REG2, ENC_COMMON_ECON1_RXEN
    rcall ETH_BIT_FIELD_SET
    ret

/* Enable interrupts {{{2 ------------------------------------------------------
 * The INT Interrupt Enable bit (INTIE) is a global enable bit which allows the
 * following interrupts to drive the INT pin:
 * - Receive Error Interrupt (RXERIF)
 * - Transmit Error Interrupt (TXERIF)
 * - Transmit Interrupt (TXIF)
 * - Link Change Interrupt (LINKIF)
 * - DMA Interrupt (DMAIF)
 * - Receive Packet Pending Interrupt (PKTIF)
 * We are going to ignore some interrupts that we cannot do much about
 * - RXERIF trigger when received packed is full... not much that we can do */
#if USE_INTIE
ETH_ENABLE_RECEIVE_INTERRUPT:
    ldi   ARG_REG1, ENC_COMMON_EIE
    ldi   ARG_REG2, (1 << ENC_COMMON_EIE_INTIE)  | \
                    (USE_PKTIF  << ENC_COMMON_EIE_PKTIE)  | \
                    (USE_DMAIF  << ENC_COMMON_EIE_DMAIE)  | \
                    (USE_LINKIF << ENC_COMMON_EIE_LINKIE) | \
                    (USE_TXIF   << ENC_COMMON_EIE_TXIE)   | \
                    (USE_TXERIF << ENC_COMMON_EIE_TXERIE) | \
                    (USE_RXERIF << ENC_COMMON_EIE_RXERIE)
    rcall ETH_BIT_FIELD_SET
    ret
#endif

/* Software reset {{{2 -------------------------------------------------------*/
ETH_SOFTWARE_RESET:
    ldi   ARG_REG1, ETH_SPI_CMD_SRC
    SPI_SELECT_ETH
    rcall SPI_MASTER_TRANSMIT
    SPI_END_ETH
    ret

/* Buffer initialization {{{2 ------------------------------------------------*/
ETH_BUFFER_INIT:
    ldi   YL, lo8(EEPROM_ENC_BUFFER_INIT)
    ldi   YH, hi8(EEPROM_ENC_BUFFER_INIT)
    ldi   ARG_REG2, (EEPROM_ENC_BUFFER_INIT_END - EEPROM_ENC_BUFFER_INIT) / 2
    rcall ETH_CMDS_FROM_EEPROM

    /* Power-on Reset, the ENC_COMMON_ESTAT.CLKRDY bit should be polled to make certain that
     * enough time
     */
    rcall ETH_WAIT_UNTIL_READY
    ret

/* Mac initialization {{{2 ---------------------------------------------------*/
ETH_MAC_INIT: /* ONLY ONCE */
    ldi   YL, lo8(EEPROM_ENC_MAC_INIT)
    ldi   YH, hi8(EEPROM_ENC_MAC_INIT)
    ldi   ARG_REG2, (EEPROM_ENC_MAC_INIT_END - EEPROM_ENC_MAC_INIT) / 2
    rcall ETH_CMDS_FROM_EEPROM

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
    ldi   YH, hi8(EEPROM_MAC_ADDR)
    ldi   YL, lo8(EEPROM_MAC_ADDR)
    ldi   TMP_REG2, ENC_BANK3_MAADR1
0:  rcall EEPROM_READ_N_INC
    mov   ARG_REG1, TMP_REG2
    mov   ARG_REG2, RTV_L_REG
    rcall ETH_WRITE_CONTROL_REGISTER
    /* Check loop break */
    cpi   TMP_REG2, ENC_BANK3_MAADR6
    breq  ETH_MAC_INIT_SET_MAC_LOOP_END
    /* Set following MAC ADDR */
    inc   TMP_REG2
    sbrs  TMP_REG2, 0 /* if odd, jump back right away */
    subi  TMP_REG2, 4
    rjmp  0b /* Keep within loop */
ETH_MAC_INIT_SET_MAC_LOOP_END:
    ret

/* Write commands from EEPROM {{{2 ---------------------------------------------
 * Read EEPROM pointed by Y
 * ARG_REG1 number of commands to read
 * Commands are 2 bytes long
 */
ETH_CMDS_FROM_EEPROM:
    SPI_SELECT_ETH
    rcall EEPROM_READ_N_INC
    mov   ARG_REG1, RTV_L_REG
    rcall SPI_MASTER_TRANSMIT
    rcall EEPROM_READ_N_INC
    mov   ARG_REG1, RTV_L_REG
    rcall SPI_MASTER_TRANSMIT
    SPI_END_ETH
    dec   ARG_REG2
    brne  ETH_CMDS_FROM_EEPROM
    ret

/* Start buffer read {{{2 ----------------------------------------------------*/
ETH_READ_BUFFER_START:
    ldi   ARG_REG1, ETH_SPI_CMD_RBM
    SPI_SELECT_ETH
    rcall SPI_MASTER_TRANSMIT
    ret

/* Receive enc28j60 header {{{2 ----------------------------------------------*/
ETH_READ_RECEIVE_HEADER:
    push  ZL
    push  ZH

    SPI_SELECT_ETH
    ldi   ARG_REG1, ETH_SPI_CMD_RBM
    rcall SPI_MASTER_TRANSMIT

    /* Read the whole receive status vector */
    /* TODO: NS_MEMCPY */
    ldi   ZH, hi8(SRAM_RPKT_N_PKT_L)
    ldi   ZL, lo8(SRAM_RPKT_N_PKT_L)
    ldi   ARG_REG1, RPKT_STATUS_VECTOR_LEN
    rcall SPI_MEMCPY

    SPI_END_ETH
    pop   ZH
    pop   ZL
    ret

/* Check receive status vector {{{2 --------------------------------------------
 * Returns Zero if packet is good to be processed, else, != 0 */
ETH_CHECK_RECEIVE_STATUS_VECTOR:
    /* Check Received packet status 3 */
    lds  RTV_L_REG, SRAM_RPKT_STATUS3
    /* Discard VLAN, Unknown Opcode, Pause Control Frame, Control Frame */
    andi RTV_L_REG, ~((1 << RPKT_STATUS3_RECEIVE_BROADCAST_PACKET) | \
                      (1 << RPKT_STATUS3_RECEIVE_MULTICAST_PACKET) | \
                      (1 << RPKT_STATUS3_DRIBBLE_NIBBLE))

    /* Check Received packet status 2 */
    lds  TMP_REG1, SRAM_RPKT_STATUS2
    /* If OK bit is not set, then, set MSB bit on RTV_L_REG */
    sbrs TMP_REG1, RPKT_STATUS2_RECEIVED_OK
    sbr  RTV_L_REG, 0x80
    ret

/* Read Ethernet header (Mac addresses and Type/Len {{{2 -----------------------
 * Update the Dst Mac Address ptr and the type/len ptr when reading the header
 *
 * TYPE/LENGTH
 * The type/length field is a 2-byte field which defines which protocol the
 * following packet data belongs to.  Alternately, if the field is filled with
 * the contents of 05DCh (1500) or any smaller number, the field is considered a
 * length field and it specifies the amount of non-padding data which follows in
 * the data field.  */
ETH_READ_MAC_ADDRS_N_LEN_TYPE:
    ldi   ARG_REG1, ETH_SPI_CMD_RBM
    SPI_SELECT_ETH
    rcall SPI_MASTER_TRANSMIT

    /* Using register Z for SRAM write incremental */
    push  ZL
    push  ZH

    /* Mac address SRC/DST and Type/len is all continuous in memory */
    ldi   ZH, hi8(SRAM_ENC_HEADER)
    ldi   ZL, lo8(SRAM_ENC_HEADER)
    ldi   ARG_REG1, (MAC_ADDR_LEN + MAC_ADDR_LEN + 2)
    rcall SPI_MEMCPY

    /* Update Mac Addr Dst & Type/Len ptr */
    /* TODO: Could be done in other way */
    ldi   TMP_REG1, hi8(SRAM_ENC_SRC_ADDR)
    sts   SRAM_ENC_MAC_DST_PTR + 0, TMP_REG1
    ldi   TMP_REG1, lo8(SRAM_ENC_SRC_ADDR)
    sts   SRAM_ENC_MAC_DST_PTR + 1, TMP_REG1

    ldi   TMP_REG1, hi8(SRAM_TYPE_LEN_H)
    sts   SRAM_ENC_TYPE_LEN_PTR + 0, TMP_REG1
    ldi   TMP_REG1, lo8(SRAM_TYPE_LEN_H)
    sts   SRAM_ENC_TYPE_LEN_PTR + 1, TMP_REG1

    pop   ZH
    pop   ZL
    SPI_END_ETH
    ret

/* Free the space of the packet that was processed {{{2 ----------------------*/
ETH_PKT_PROCESSED:
    /* Set BANK 0 */
    ldi   ARG_REG1, ENC_COMMON_ECON1
    ldi   ARG_REG2, ENC_COMMON_ECON1_BSEL0 | ENC_COMMON_ECON1_BSEL1
    rcall ETH_BIT_FIELD_CLEAR

    /* Move the RX Read Point to the next packet */
    ldi   ARG_REG1, ENC_BANK0_ERXRDPTL
    lds   ARG_REG2, SRAM_RPKT_N_PKT_L
    rcall ETH_WRITE_CONTROL_REGISTER

    ldi   ARG_REG1, ENC_BANK0_ERXRDPTH
    lds   ARG_REG2, SRAM_RPKT_N_PKT_H
    rcall ETH_WRITE_CONTROL_REGISTER

    /* Decrement received packet count */
    ldi   ARG_REG1, ENC_COMMON_ECON2
    ldi   ARG_REG2, ENC_COMMON_ECON2_PKTDEC
    rcall ETH_BIT_FIELD_SET

    /* Move the Read Pointer to the next packet */
    ldi   ARG_REG1, ENC_BANK0_ERDPTL
    lds   ARG_REG2, SRAM_RPKT_N_PKT_L
    rcall ETH_WRITE_CONTROL_REGISTER

    ldi   ARG_REG1, ENC_BANK0_ERDPTH
    lds   ARG_REG2, SRAM_RPKT_N_PKT_H
    rcall ETH_WRITE_CONTROL_REGISTER

    ret

/* Write message header, Per packet control byte + Mac addresses + Type/Len {{{2
 * SRAM_ENC_MAC_DST_PTR pointer to Dst MAC address
 *   As we have 1k of SRAM, only the 11 LSB are used for addresses, then we have
 *   5 MBS to encode other options.
 *     If MSB of the pointer is set, then, the address is not a pointer and the
 *     MAC Dst is broadcast */
/* Per packet control byte {{{3
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
     1 = The values of PCRCEN, PPADEN and PHUGEEN will override the configuration defined by ENC_BANK2_MACON3
     0 = The values in ENC_BANK2_MACON3 will be used to determine how the packet will be transmitted
}}} */
#define PPCB_PHUGEEN   0x08
#define PPCB_PPADEN    0x04
#define PPCB_PCRCEN    0x02
#define PPCB_POVERRIDE 0x01

#define COUNTER     TMP_REG1
#define TMP_PTR_H   TMP_REG1
#define TMP_PTR_L   TMP_REG2
ETH_WRITE_BUFFER_PACKET_HEADER:
    push YL
    push YH
    push COUNTER /* Same as TMP_PTR_H */
    push TMP_PTR_L

    ldi   YL, lo8(EEPROM_ENC_WRITE_BUFFER_PACKET_HEADER_PRESET)
    ldi   YH, hi8(EEPROM_ENC_WRITE_BUFFER_PACKET_HEADER_PRESET)
    ldi   ARG_REG2, (EEPROM_ENC_WRITE_BUFFER_PACKET_HEADER_PRESET_END - EEPROM_ENC_WRITE_BUFFER_PACKET_HEADER_PRESET) / 2
    rcall ETH_CMDS_FROM_EEPROM

    /* Send write command */
    ldi   ARG_REG1, ETH_SPI_CMD_WBM
    SPI_SELECT_ETH
    rcall SPI_MASTER_TRANSMIT

    /* Write the packet header { */
    ldi   ARG_REG1, PPCB_POVERRIDE | PPCB_PCRCEN | PPCB_PPADEN
    rcall SPI_MASTER_TRANSMIT

    /* Write Dst Mac address */
    ldi   YH, hi8(SRAM_ENC_MAC_DST_PTR)
    ldi   YL, lo8(SRAM_ENC_MAC_DST_PTR)
    ld    TMP_PTR_H, Y+    /* High address ptr */
    /* Check if MSB is set to broadcast */
    sbrc  TMP_PTR_H, ENC_MAC_DST_PTR_BROADCAST_BIT
    rjmp  ETH_WRITE_BUFFER_MAC_DST_BROADCAST

    ld    TMP_PTR_L, Y     /* Low  address ptr */
    /* TODO: use movw instead of mov */
    mov   YH, TMP_PTR_H
    mov   YL, TMP_PTR_L
    ldi   COUNTER, MAC_ADDR_LEN
    /* TODO: SPI_SRAM_TRANSMIT ? */
ETH_WRITE_BUFFER_MAC_DST:
    ld    ARG_REG1, Y+
    rcall SPI_MASTER_TRANSMIT
    dec   COUNTER
    brne  ETH_WRITE_BUFFER_MAC_DST
    rjmp  ETH_WRITE_BUFFER_MAC_SRC

ETH_WRITE_BUFFER_MAC_DST_BROADCAST:
    ldi   COUNTER, MAC_ADDR_LEN
ETH_WRITE_BUFFER_MAC_DST_BROADCAST_LOOP:
    ldi   ARG_REG1, 0xFF
    rcall SPI_MASTER_TRANSMIT
    dec   COUNTER
    brne  ETH_WRITE_BUFFER_MAC_DST_BROADCAST_LOOP

    /* Write Src Mac address */
ETH_WRITE_BUFFER_MAC_SRC:
    ldi   YL, lo8(EEPROM_MAC_ADDR)
    ldi   YH, hi8(EEPROM_MAC_ADDR)
    ldi   ARG_REG1, MAC_ADDR_LEN
    rcall SPI_EEPROM_TRANSMIT

    /* Write Type/Len */
    ldi   YH, hi8(SRAM_ENC_TYPE_LEN_PTR)
    ldi   YL, lo8(SRAM_ENC_TYPE_LEN_PTR)
    ld    TMP_PTR_H, Y+    /* High address ptr */
    /* Check if MSB is IPv4 */
    sbrc  TMP_PTR_H, ENC_TYPE_LEN_PTR_IPv4
    rjmp  ETH_WRITE_BUFFER_TYPE_LEN_IPv4
    /* Check if next MSB is ARP */
    sbrc  TMP_PTR_H, ENC_TYPE_LEN_PTR_ARP
    rjmp  ETH_WRITE_BUFFER_TYPE_LEN_ARP

    ld    TMP_PTR_L, Y     /* Low  address ptr */
    mov   YH, TMP_PTR_H
    mov   YL, TMP_PTR_L
    ld    ARG_REG1, Y+
    rcall SPI_MASTER_TRANSMIT
    ld    ARG_REG1, Y+
    rcall SPI_MASTER_TRANSMIT
    rjmp  ETH_WRITE_BUFFER_PACKET_HEADER_END

/* TODO: improve */
ETH_WRITE_BUFFER_TYPE_LEN_ARP:
    ldi   ARG_REG1, hi8(ETHER_TYPE_ARP)
    rcall SPI_MASTER_TRANSMIT
    ldi   ARG_REG1, lo8(ETHER_TYPE_ARP)
    rcall SPI_MASTER_TRANSMIT
    rjmp  ETH_WRITE_BUFFER_PACKET_HEADER_END

ETH_WRITE_BUFFER_TYPE_LEN_IPv4:
    ldi   ARG_REG1, hi8(ETHER_TYPE_IPV4)
    rcall SPI_MASTER_TRANSMIT
    ldi   ARG_REG1, lo8(ETHER_TYPE_IPV4)
    rcall SPI_MASTER_TRANSMIT
    /* } */

ETH_WRITE_BUFFER_PACKET_HEADER_END:
    SPI_END_ETH

    pop TMP_PTR_L
    pop COUNTER
    pop YH
    pop YL
    ret
#undef COUNTER
#undef TMP_PTR_L

/* Send write command and leave SPI waiting {{{2 -----------------------------*/
ETH_SET_LISTEN_ON_SPI:
    /* Send write command */
    ldi   ARG_REG1, ETH_SPI_CMD_WBM
    SPI_SELECT_ETH
    rcall SPI_MASTER_TRANSMIT
    ret

/* Write Z to transmit buffer {{{2 ---------------------------------------------
 * Z is a pointer to memory to where start writing from
 * ARG_REG1 is number of byte to write */
ETH_WRITE_Z_TO_TRANSMIT_BUFFER:
    /* Send write command */
    mov   TMP_REG1, ARG_REG1
    SPI_SKIP_IF_SELECTED_ETH
    rcall ETH_SET_LISTEN_ON_SPI

0:  ld    ARG_REG1, Z+
    rcall SPI_MASTER_TRANSMIT
    dec   TMP_REG1
    brne  0b
    lds   TMP_REG1, SRAM_ENC_FLAGS
    sbrs  TMP_REG1, FLAG_KEEP_OPEN_AFTER_WRITE
    SPI_END_ETH
    ret

/* ETH_UNSET_FLAG_KEEP_OPEN_AFTER_WRITE {{{2 ---------------------------------*/
ETH_UNSET_FLAG_KEEP_OPEN_AFTER_WRITE:
    lds   TMP_REG1, SRAM_ENC_FLAGS
    cbr   TMP_REG1, (1 << FLAG_KEEP_OPEN_AFTER_WRITE)
    sts   SRAM_ENC_FLAGS, TMP_REG1
    ret

/* ETH_SET_FLAG_KEEP_OPEN_AFTER_WRITE {{{2 -----------------------------------*/
ETH_SET_FLAG_KEEP_OPEN_AFTER_WRITE:
    lds   TMP_REG1, SRAM_ENC_FLAGS
    sbr   TMP_REG1, (1 << FLAG_KEEP_OPEN_AFTER_WRITE)
    sts   SRAM_ENC_FLAGS, TMP_REG1
    ret

/* Finish Write Payload {{{2 -------------------------------------------------*/
ETH_WRITE_BUFFER_PACKET_PAYLOAD_FINISH:
    /* Set BANK 0 */
    ldi   ARG_REG1, ENC_COMMON_ECON1
    ldi   ARG_REG2, ENC_COMMON_ECON1_BSEL0 | ENC_COMMON_ECON1_BSEL1
    rcall ETH_BIT_FIELD_CLEAR

    /* read EWRPT */
    ldi   ARG_REG1, ENC_BANK0_EWRPTH
    rcall ETH_READ_CONTROL_REGISTER
    mov   RTV_H_REG, RTV_L_REG

    ldi   ARG_REG1, ENC_BANK0_EWRPTL
    rcall ETH_READ_CONTROL_REGISTER

    /* Move pointer to last written byte */
    subi  RTV_L_REG, 1
    sbc   RTV_H_REG, ZERO_REG

    ldi   ARG_REG1, ENC_BANK0_ETXNDL
    mov   ARG_REG2, RTV_L_REG
    rcall ETH_WRITE_CONTROL_REGISTER
    ldi   ARG_REG1, ENC_BANK0_ETXNDH
    mov   ARG_REG2, RTV_H_REG
    rcall ETH_WRITE_CONTROL_REGISTER

    /* Clear ENC_COMMON_EIR.TXIF, set ENC_COMMON_EIE.TXIE and set ENC_COMMON_EIE.INTIE
     *   to enable an interrupt when done (if desired).
     *   Start the transmission process by setting
     */
#if USE_TXIF
    ldi   ARG_REG1, ENC_COMMON_EIR
    ldi   ARG_REG2, (1 << ENC_COMMON_EIR_TXIF)
    rcall ETH_BIT_FIELD_CLEAR

    ldi   ARG_REG1, ENC_COMMON_EIE
    ldi   ARG_REG2, (1 << ENC_COMMON_EIE_TXIE) | (1 << ENC_COMMON_EIE_INTIE)
    rcall ETH_BIT_FIELD_SET
#endif

    /* Set bits to send packet */
    ldi   ARG_REG1, ENC_COMMON_ECON1
    ldi   ARG_REG2, ENC_COMMON_ECON1_TXRTS
    rcall ETH_BIT_FIELD_SET

    ret

/* Move the RDPT {{{2 ----------------------------------------------------------
 *
 * Increment/Decrement value in [ARG_REG1:ARG_REG2]
 *
 * ERDPT is 13 bits long
 *
 * RANDOM ACCESS ADDRESS CALCULATION
 *   if Packet Start Address + Offset > ERXND, then
 *      ERDPT = Packet Start Address + Offset - (ERXND - ERXST + 1)
 *   else
 *      ERDPT = Packet Start Address + Offset */
#if USE_MOVE_RDPT
#define RDPT_H R23
#define RDPT_L R24
#define TMP_REG3 RTV_L_REG
ETH_MOVE_RDPT:
    push  RDPT_H
    push  RDPT_L
    /* Save ARG_REG[12] to be used later */
    push  ARG_REG1
    push  ARG_REG2
    /* Read the content of the Read Pointer into:
     * [ENC_BANK0_ERDPTH:ENC_BANK0_ERDPTL] -> [RDPT_H:RDPT_L] */
    /* Set BANK 0 */
    ldi   ARG_REG1, ENC_COMMON_ECON1
    ldi   ARG_REG2, ENC_COMMON_ECON1_BSEL0 | ENC_COMMON_ECON1_BSEL1
    rcall ETH_BIT_FIELD_CLEAR

    ldi   ARG_REG1, ENC_BANK0_ERDPTH
    rcall ETH_READ_CONTROL_REGISTER
    mov   RDPT_H, RTV_L_REG

    ldi   ARG_REG1, ENC_BANK0_ERDPTL
    rcall ETH_READ_CONTROL_REGISTER
    mov   RDPT_L, RTV_L_REG

    pop   ARG_REG2
    pop   ARG_REG1

    tst   ARG_REG1
    brpl  ADD_READ_POINTER

SUB_READ_POINTER:
    cbr   ARG_REG1, 7
    sub   RDPT_L, ARG_REG2
    sbc   RDPT_H, ARG_REG1
    rjmp  CHECK_UNDERFLOW

ADD_READ_POINTER:
    add   RDPT_L, ARG_REG2
    adc   RDPT_H, ARG_REG1
    /* ERDPT is 13bits long, therefore we should not have overflow */
    rjmp  CHECK_OVERFLOW

CHECK_UNDERFLOW:
    cpi   RDPT_H, BUF_RX_ST_H
    brlo  UNDERFLOW
    breq  CHECK_UNDERFLOW_L
    rjmp  UPDATE_ERDPT /* RDPT_H greater than BUF_RX_ST_H */
CHECK_UNDERFLOW_L:
    cpi   RDPT_L, BUF_RX_ST_L
    brlo  UNDERFLOW
    rjmp  UPDATE_ERDPT /* RDPT_H == BUF_RX_ST_H && RDPT_L >= BUF_RX_ST_L */
UNDERFLOW:
    ldi  TMP_REG3, lo8(BUF_RX_SIZE)
    add  RDPT_L, TMP_REG3
    ldi  TMP_REG3, hi8(BUF_RX_SIZE)
    adc  RDPT_H, TMP_REG3
    rjmp UPDATE_ERDPT

CHECK_OVERFLOW:
    cpi  RDPT_H, BUF_RX_ND_H
    brlo UPDATE_ERDPT
    breq CHECK_OVERFLOW_L
    rjmp OVERFLOW /* RDPT_H > BUF_RX_ND_H */
CHECK_OVERFLOW_L:
    cpi  RDPT_L, BUF_RX_ND_L
    brlo UPDATE_ERDPT
    breq UPDATE_ERDPT
    /* Drop DOWN TO overflow */
OVERFLOW:
    ldi  TMP_REG3, lo8(BUF_RX_SIZE)
    sub  RDPT_L, TMP_REG3
    ldi  TMP_REG3, hi8(BUF_RX_SIZE)
    sbc  RDPT_H, TMP_REG3

UPDATE_ERDPT:
    /* Move the Read Pointer to the next packet */
    ldi   ARG_REG1, ENC_BANK0_ERDPTL
    mov   ARG_REG2, RDPT_L
    rcall ETH_WRITE_CONTROL_REGISTER

    ldi   ARG_REG1, ENC_BANK0_ERDPTH
    mov   ARG_REG2, RDPT_H
    rcall ETH_WRITE_CONTROL_REGISTER

    pop   RDPT_L
    pop   RDPT_H
    ret
#undef RDPT_H
#undef RDPT_L
#undef TMP_REG3
#endif

.end
