/* vim: set filetype=S foldmethod=marker: */
/* INCLUDES {{{1 */
.NOLIST
#include <avr/io.h>
#include "defs.h"
#include "spi.h"
#include "enc28j60.h"
#include "eeprom_data.h"
#include "macros.S"
.LIST

/* MACORS {{{1 ---------------------------------------------------------------*/

/* GLOBAL {{{1 ---------------------------------------------------------------*/
.global ETH_INIT
.global ETH_READ_CONTROL_REGISTER
.global ETH_READ_BUFFER_START
.global ETH_READ_RECEIVE_N_ETHERNET_HEADER
.global ETH_PKT_PROCESSED
.global ETH_WRITE_BUFFER_PACKET_HEADER
.global ETH_SET_LISTEN_ON_SPI
.global ETH_WRITE_Z_TO_TRANSMIT_BUFFER
.global ETH_WRITE_BUFFER_PACKET_PAYLOAD_FINISH
#if USE_MOVE_RDPT
.global ETH_MOVE_RDPT
#endif

.global SRAM_ENC_DATA
.global SRAM_ENC_ETH_SRC_ADDR
.global SRAM_ENC_ETH_TYPE_LEN
.global SRAM_ENC_MAC_DST_PTR
.global SRAM_ENC_TYPE_LEN_OFFSET

/* DATA  {{{1 ----------------------------------------------------------------*/
.section .data
/* Status vector, added by ENC28J60 HW before Ethernet header */
SRAM_ENC_DATA:
SRAM_ENC_RPKT_HEADER:
SRAM_ENC_RPKT_N_PKT_L:    .skip 1
SRAM_ENC_RPKT_N_PKT_H:    .skip 1
SRAM_ENC_RPKT_BC_L:       .skip 1
SRAM_ENC_RPKT_BC_H:       .skip 1
SRAM_ENC_RPKT_STATUS1:    .skip 1
SRAM_ENC_RPKT_STATUS2:    .skip 1
/* SRAM_ENC_ETH_HEADER must be right after SRAM_ENC_RPKT_STATUS2, check PCC0002 */
/* Ethernet header, this fields are updated every time we start processing a
 * packet */
SRAM_ENC_ETH_HEADER:
SRAM_ENC_ETH_DST_ADDR:    .skip 6
SRAM_ENC_ETH_SRC_ADDR:    .skip 6
SRAM_ENC_ETH_TYPE_LEN:
SRAM_ENC_ETH_TYPE_LEN_H:  .skip 1
SRAM_ENC_ETH_TYPE_LEN_L:  .skip 1
/* Pointer to Dst MAC address */
/* SRAM_TYPE_LEN_L Must be right before SRAM_ENC_MAC_DST_PTR, check PCC0003 */
SRAM_ENC_MAC_DST_PTR:     .skip 2
/* Pointer to TYPE/LEN value */
SRAM_ENC_TYPE_LEN_OFFSET: .skip 1

/* TEXT {{{1 -----------------------------------------------------------------*/
.section .text

/* Initialize everything {{{2 ------------------------------------------------*/
ETH_INIT:
    /* Software reset */
    ldi   a1, ETH_SPI_CMD_SRC
    SPI_SELECT_ETH
    rcall SPI_MASTER_TRANSMIT
    SPI_END_ETH

    /* After a Power-on Reset, or the ENC28J60 is removed from Power-Down mode,
     * the CLKRDY bit must be polled before transmitting packets, enabling
     * packet reception or accessing any MAC, MII or PHY registers. */
0:  ldi   a1, ENC_COMMON_ESTAT
    rcall ETH_READ_CONTROL_REGISTER
    sbrs  a4, ENC_COMMON_ESTAT_CLKRDY
    rjmp  0b

    /* Send Buffer and MAC initialization */
    ldi   xl, lo8(EEPROM_ENC_BUFFER_INIT)
    ldi   xh, hi8(EEPROM_ENC_BUFFER_INIT)
    ldi   a2, (EEPROM_ENC_MAC_INIT_END - EEPROM_ENC_BUFFER_INIT) / 2
    rcall ETH_CMDS_FROM_EEPROM

    /* Enable packet reception */
    ldi   a1, ENC_COMMON_ECON1
    ldi   a2, ENC_COMMON_ECON1_RXEN
    rcall ETH_BIT_FIELD_SET

    /* Enable recieve interrupt */
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
 * a1 is the register to be read */
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
 * a1 is the register to be written
 * a2 is the value of the register */
ETH_WRITE_CONTROL_REGISTER:
    /* command is 010AAAAA, then corresponding prefix */
    sbr   a1, ETH_SPI_CMD_WCR
    rjmp  0f

/* Set the given bits into the register {{{2 -----------------------------------
 * Inputs:
 * - a1: Register address
 * - a2: Mask with bits that are going to be set */
ETH_BIT_FIELD_SET:
    /* command is 100AAAAA, then corresponding prefix */
    sbr   a1, ETH_SPI_CMD_BFS
    rjmp  0f

/* Clear the given bits into the register {{{2 ---------------------------------
 * Inputs:
 * - a1: Register address
 * - a2: Mask with bits that are going to be clear */
ETH_BIT_FIELD_CLEAR:
    /* command is 101AAAAA, then corresponding prefix */
    sbr   a1, ETH_SPI_CMD_BFC

/* ETH_WRITE_CONTROL_REGISTER, ETH_BIT_FIELD_SET and ETH_BIT_FIELD_CLEAR {{{2 --
 * common part */
0:  SPI_SELECT_ETH
    rcall SPI_MASTER_TRANSMIT
    mov   a1, a2
    rcall SPI_MASTER_TRANSMIT
    SPI_END_ETH
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
    ldi   a1, ENC_COMMON_EIE
    ldi   a2, (1 << ENC_COMMON_EIE_INTIE)  | \
              (USE_PKTIF  << ENC_COMMON_EIE_PKTIE)  | \
              (USE_DMAIF  << ENC_COMMON_EIE_DMAIE)  | \
              (USE_LINKIF << ENC_COMMON_EIE_LINKIE) | \
              (USE_TXIF   << ENC_COMMON_EIE_TXIE)   | \
              (USE_TXERIF << ENC_COMMON_EIE_TXERIE) | \
              (USE_RXERIF << ENC_COMMON_EIE_RXERIE)
    rcall ETH_BIT_FIELD_SET
    ret
#endif

/* Write commands from EEPROM {{{2 ---------------------------------------------
 * Read EEPROM pointed by x
 * a2 number of commands to read
 * Commands are 2 bytes long
 */
ETH_CMDS_FROM_EEPROM:
    SPI_SELECT_ETH
    ldi   a1, 2
    rcall MEMCPY_EEPROM_SPI
    SPI_END_ETH
    dec   a2
    brne  ETH_CMDS_FROM_EEPROM
    ret

/* Start buffer read {{{2 ----------------------------------------------------*/
ETH_READ_BUFFER_START:
    ldi   a1, ETH_SPI_CMD_RBM
    SPI_SELECT_ETH
    rcall SPI_MASTER_TRANSMIT
    ret

/* Read ENC28J60 header and Ethernet header {{{2 -------------------------------
 * Read ENC28J60 receive header
 * Read Ethernet header (Src/Dst Mac addresses + Type/len)
 * Set SRAM_ENC_MAC_DST_PTR to default values
 * Return ENC28J60 [status1:status2] -> [a4:a3] */
ETH_READ_RECEIVE_N_ETHERNET_HEADER:
    /* Read the whole receive status vector + Src and Dst MAC Addresses +
     * Type/len (2 bytes).
     * Consecutive data checked with PCC0002 */
    rcall ETH_READ_BUFFER_START
    ldi   zh, hi8(SRAM_ENC_RPKT_HEADER)
    ldi   zl, lo8(SRAM_ENC_RPKT_HEADER)
    ldi   a1, (RPKT_STATUS_VECTOR_LEN + MAC_ADDR_LEN + MAC_ADDR_LEN + 2)
    rcall MEMCPY_SPI_SRAM
    SPI_END_ETH

    DEBUG(rcall PRINT_RECEIVE_VECTOR)

    /* Set default Mac Addr Dst */
    /* After memcpy, Z points to correct data because check PCC0003 */
    ldi   t1, hi8(SRAM_ENC_ETH_SRC_ADDR)
    st    z+, t1
    ldi   t1, lo8(SRAM_ENC_ETH_SRC_ADDR)
    st    z+, t1

    /* Move Z to SRAM_ENC_DATA */
    sbiw  zl, ENC_TYPE_LEN_OFFSET
    ldd   a4, z + ENC_RPKT_STATUS1
    ldd   a3, z + ENC_RPKT_STATUS2

    ret

/* Free the space of the packet that was processed {{{2 ----------------------*/
ETH_PKT_PROCESSED:
    /* Set BANK 0 */
    ldi   a1, ENC_COMMON_ECON1
    ldi   a2, ENC_COMMON_ECON1_BSEL0 | ENC_COMMON_ECON1_BSEL1
    rcall ETH_BIT_FIELD_CLEAR

    /* Move "RX Read Point" and "Read Pointer" to the next packet, reusing a2 to
     * write control register */
    ldi   a1, ENC_BANK0_ERXRDPTL
    lds   a2, SRAM_ENC_RPKT_N_PKT_L
    rcall ETH_WRITE_CONTROL_REGISTER

    ldi   a1, ENC_BANK0_ERDPTL
    rcall ETH_WRITE_CONTROL_REGISTER


    ldi   a1, ENC_BANK0_ERXRDPTH
    lds   a2, SRAM_ENC_RPKT_N_PKT_H
    rcall ETH_WRITE_CONTROL_REGISTER

    ldi   a1, ENC_BANK0_ERDPTH
    rcall ETH_WRITE_CONTROL_REGISTER

    /* Decrement received packet count */
    ldi   a1, ENC_COMMON_ECON2
    ldi   a2, ENC_COMMON_ECON2_PKTDEC
    rcall ETH_BIT_FIELD_SET

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

ETH_WRITE_BUFFER_PACKET_HEADER:
    push xl
    push xh

    ldi   xl, lo8(EEPROM_ENC_WRITE_BUFFER_PACKET_HEADER_PRESET)
    ldi   xh, hi8(EEPROM_ENC_WRITE_BUFFER_PACKET_HEADER_PRESET)
    ldi   a2, (EEPROM_ENC_WRITE_BUFFER_PACKET_HEADER_PRESET_END - EEPROM_ENC_WRITE_BUFFER_PACKET_HEADER_PRESET) / 2
    rcall ETH_CMDS_FROM_EEPROM

    /* Send write command */
    rcall ETH_SET_LISTEN_ON_SPI

    /* Write the packet header */
    ldi   a1, PPCB_POVERRIDE | PPCB_PCRCEN | PPCB_PPADEN
    rcall SPI_MASTER_TRANSMIT

    /* Write Dst Mac address */
    lds   xh, SRAM_ENC_MAC_DST_PTR + 0
    lds   xl, SRAM_ENC_MAC_DST_PTR + 1

    ldi   t3, MAC_ADDR_LEN
    ldi   a1, 0xFF
    /* Check if MSB is set to broadcast */
0:  sbrs  xh, ENC_MAC_DST_PTR_BROADCAST_BIT
    ld    a1, x+
    rcall SPI_MASTER_TRANSMIT
    dec   t3
    brne  0b

    /* Write Src Mac address */
    ldi   xl, lo8(EEPROM_MAC_ADDR)
    ldi   xh, hi8(EEPROM_MAC_ADDR)
    ldi   a1, MAC_ADDR_LEN
    rcall MEMCPY_EEPROM_SPI

    /* Write Type/Len */
    ldi   xl, lo8(EEPROM_TYPE_LEN)
    ldi   xh, hi8(EEPROM_TYPE_LEN)
    lds   t1, SRAM_ENC_TYPE_LEN_OFFSET
    add   xl, t1
    adc   xh, zero
    ldi   a1, 2
    rcall MEMCPY_EEPROM_SPI

    SPI_END_ETH

    pop xh
    pop xl
    ret

/* Send write command and leave SPI waiting {{{2 -----------------------------*/
ETH_SET_LISTEN_ON_SPI:
    /* Send write command */
    ldi   a1, ETH_SPI_CMD_WBM
    SPI_SELECT_ETH
    rcall SPI_MASTER_TRANSMIT
    ret

/* Write z to transmit buffer {{{2 ---------------------------------------------
 * z is a pointer to memory to where start writing from
 * a1 is number of byte to write */
 /* TODO: Use MEMCPY_SRAM_SPI */
ETH_WRITE_Z_TO_TRANSMIT_BUFFER:
    /* Send write command */
    mov   t1, a1
    SPI_SKIP_IF_SELECTED_ETH
    rcall ETH_SET_LISTEN_ON_SPI

0:  ld    a1, z+
    rcall SPI_MASTER_TRANSMIT
    dec   t1
    brne  0b
    SPI_END_ETH
    ret

/* Finish Write Payload {{{2 -------------------------------------------------*/
ETH_WRITE_BUFFER_PACKET_PAYLOAD_FINISH:
    /* Set BANK 0 */
    ldi   a1, ENC_COMMON_ECON1
    ldi   a2, ENC_COMMON_ECON1_BSEL0 | ENC_COMMON_ECON1_BSEL1
    rcall ETH_BIT_FIELD_CLEAR

    /* read EWRPT */
    ldi   a1, ENC_BANK0_EWRPTH
    rcall ETH_READ_CONTROL_REGISTER
    mov   a3, a4

    ldi   a1, ENC_BANK0_EWRPTL
    rcall ETH_READ_CONTROL_REGISTER

    /* Move pointer to last written byte */
    subi  a4, 1
    sbc   a3, zero

    ldi   a1, ENC_BANK0_ETXNDL
    mov   a2, a4
    rcall ETH_WRITE_CONTROL_REGISTER
    ldi   a1, ENC_BANK0_ETXNDH
    mov   a2, a3
    rcall ETH_WRITE_CONTROL_REGISTER

    /* Clear ENC_COMMON_EIR.TXIF, set ENC_COMMON_EIE.TXIE and set ENC_COMMON_EIE.INTIE
     *   to enable an interrupt when done (if desired).
     *   Start the transmission process by setting
     */
#if USE_TXIF
    ldi   a1, ENC_COMMON_EIR
    ldi   a2, (1 << ENC_COMMON_EIR_TXIF)
    rcall ETH_BIT_FIELD_CLEAR

    ldi   a1, ENC_COMMON_EIE
    ldi   a2, (1 << ENC_COMMON_EIE_TXIE) | (1 << ENC_COMMON_EIE_INTIE)
    rcall ETH_BIT_FIELD_SET
#endif

    /* Set bits to send packet */
    ldi   a1, ENC_COMMON_ECON1
    ldi   a2, ENC_COMMON_ECON1_TXRTS
    rcall ETH_BIT_FIELD_SET

    ret

/* Move the RDPT {{{2 ----------------------------------------------------------
 *
 * Increment/Decrement value in [a1:a2]
 *
 * ERDPT is 13 bits long
 *
 * RANDOM ACCESS ADDRESS CALCULATION
 *   if Packet Start Address + Offset > ERXND, then
 *      ERDPT = Packet Start Address + Offset - (ERXND - ERXST + 1)
 *   else
 *      ERDPT = Packet Start Address + Offset */
#if USE_MOVE_RDPT
ETH_MOVE_RDPT:
    push  s1
    push  s2
    /* Save ARG_REG[12] to be used later */
    push  a1
    push  a2
    /* Read the content of the Read Pointer into:
     * [ENC_BANK0_ERDPTH:ENC_BANK0_ERDPTL] -> [s1:s2] */
    /* Set BANK 0 */
    ldi   a1, ENC_COMMON_ECON1
    ldi   a2, ENC_COMMON_ECON1_BSEL0 | ENC_COMMON_ECON1_BSEL1
    rcall ETH_BIT_FIELD_CLEAR

    ldi   a1, ENC_BANK0_ERDPTH
    rcall ETH_READ_CONTROL_REGISTER
    mov   s1, a4

    ldi   a1, ENC_BANK0_ERDPTL
    rcall ETH_READ_CONTROL_REGISTER
    mov   s2, a4

    pop   a2
    pop   a1

    tst   a1
    brpl  ADD_READ_POINTER

SUB_READ_POINTER:
    cbr   a1, 7
    sub   s2, a2
    sbc   s1, a1
    rjmp  CHECK_UNDERFLOW

ADD_READ_POINTER:
    add   s2, a2
    adc   s1, a1
    /* ERDPT is 13bits long, therefore we should not have overflow */
    rjmp  CHECK_OVERFLOW

CHECK_UNDERFLOW:
    cpi   s1, BUF_RX_ST_H
    brlo  UNDERFLOW
    breq  CHECK_UNDERFLOW_L
    rjmp  UPDATE_ERDPT /* s1 greater than BUF_RX_ST_H */
CHECK_UNDERFLOW_L:
    cpi   s2, BUF_RX_ST_L
    brlo  UNDERFLOW
    rjmp  UPDATE_ERDPT /* s1 == BUF_RX_ST_H && s2 >= BUF_RX_ST_L */
UNDERFLOW:
    ldi  t1, lo8(BUF_RX_SIZE)
    add  s2, t1
    ldi  t1, hi8(BUF_RX_SIZE)
    adc  s1, t1
    rjmp UPDATE_ERDPT

CHECK_OVERFLOW:
    cpi  s1, BUF_RX_ND_H
    brlo UPDATE_ERDPT
    breq CHECK_OVERFLOW_L
    rjmp OVERFLOW /* s1 > BUF_RX_ND_H */
CHECK_OVERFLOW_L:
    cpi  s2, BUF_RX_ND_L
    brlo UPDATE_ERDPT
    breq UPDATE_ERDPT
    /* Drop DOWN TO overflow */
OVERFLOW:
    ldi  t1, lo8(BUF_RX_SIZE)
    sub  s2, t1
    ldi  t1, hi8(BUF_RX_SIZE)
    sbc  s1, t1

UPDATE_ERDPT:
    /* Move the Read Pointer to the next packet */
    ldi   a1, ENC_BANK0_ERDPTL
    mov   a2, s2
    rcall ETH_WRITE_CONTROL_REGISTER

    ldi   a1, ENC_BANK0_ERDPTH
    mov   a2, s1
    rcall ETH_WRITE_CONTROL_REGISTER

    pop   s2
    pop   s1
    ret
#endif

/* DEBUG {{{1 ----------------------------------------------------------------*/
#ifndef NDEBUG
PRINT_RECEIVE_VECTOR:
    DEBUG_PUSH
    PRINT_STR STR_ENC_RECEIVE_VECTOR
    ldi   zl, lo8(SRAM_ENC_DATA)
    ldi   zh, hi8(SRAM_ENC_DATA)
    ldd   a1, z + ENC_RPKT_N_PKT_H
    rcall UART_TRANSMIT_HEX
    ldd   a1, z + ENC_RPKT_N_PKT_L
    rcall UART_TRANSMIT_HEX
    ldi   a1, ' '
    rcall UART_TRANSMIT
    ldd   a1, z + ENC_RPKT_BC_H
    rcall UART_TRANSMIT_HEX
    ldd   a1, z + ENC_RPKT_BC_L
    rcall UART_TRANSMIT_HEX
    ldi   a1, ' '
    rcall UART_TRANSMIT
    ldd   a1, z + ENC_RPKT_STATUS1
    rcall UART_TRANSMIT_HEX
    ldi   a1, ' '
    rcall UART_TRANSMIT
    ldd   a1, z + ENC_RPKT_STATUS2
    rcall UART_TRANSMIT_HEX
    PRINT_NEWLINE
    DEBUG_POP
    ret
#endif

.end
