/* vim: set filetype=S foldmethod=marker: */
.NOLIST
#include <avr/io.h>
#include "defs.h"
#include "defs.h"
#include "spi.h"
#include "enc28j60.h"
.LIST

.global ETH_READ_CONTROL_REGISTER
.global ETH_WRITE_CONTROL_REGISTER
.global ETH_BIT_FIELD_SET
.global ETH_BIT_FIELD_CLEAR
.global ETH_WAIT_UNTIL_READY
.global ETH_ENABLE_RECEIVE
.global ETH_SET_BANK
.global ETH_ENABLE_RECEIVE_INTERRUPT
.global ETH_SOFTWARE_RESET
.global ETH_BUFFER_INIT
.global ETH_MAC_INIT
.global ETH_PHY_INIT
.global ETH_READ_BUFFER_START
.global ETH_READ_RECEIVE_HEADER
.global ETH_CHECK_RECEIVE_STATUS_VECTOR
.global ETH_READ_MAC_ADDRS_N_LEN_TYPE
.global ETH_PKT_PROCESSED
.global ETH_WRITE_BUFFER_PACKET_HEADER
.global ETH_SET_LISTEN_ON_SPI
.global ETH_WRITE_Z_TO_TRANSMIT_BUFFER
.global ETH_WRITE_BUFFER_PACKET_PAYLOAD_FINISH
.global ETH_MOVE_READ_POINTER
.global ETH_GET_EWRPT_BANK0_TO_Z

/*******************************************************************************
 * Read Control Register {{{
 * To read a control register first we send the command "000" together with the
 * address of the register, i.e. "000AAAAA" through SPI, ignoring the byte that
 * is being transmitted during the command + address transmission, then, we send
 * a dummy message to activate the SCK and read a byte.
 *
 * ARG_REG1 is the register to be read
 ******************************************************************************/
ETH_READ_CONTROL_REGISTER:
    SPI_SELECT_ETH
    rcall SPI_MASTER_TRANSMIT
    rcall SPI_MASTER_TRANSMIT
    SPI_END_ETH
    ret
/* }}} */
/*******************************************************************************
 * Write control register  {{{
 * Send command and address together, then send the new value of the space that
 * the address is pointing to
 *
 * ARG_REG1 is the register to be written
 * ARG_REG2 is the value of the register
 ******************************************************************************/
ETH_WRITE_CONTROL_REGISTER:
    /* command is 010AAAAA, then corresponding prefix */
    sbr   ARG_REG1, ETH_SPI_CMD_WCR
    SPI_SELECT_ETH
    rcall SPI_MASTER_TRANSMIT
    mov   ARG_REG1, ARG_REG2
    rcall SPI_MASTER_TRANSMIT
    SPI_END_ETH
    ret
/* }}} */
/*******************************************************************************
 * Set the given bits into the register {{{
 * Inputs:
 * - ARG_REG1: Register address
 * - ARG_REG2: Mask with bits that are going to be set
 ******************************************************************************/
ETH_BIT_FIELD_SET:
    /* command is 100AAAAA, then corresponding prefix */
    sbr   ARG_REG1, ETH_SPI_CMD_BFS
    SPI_SELECT_ETH
    rcall SPI_MASTER_TRANSMIT
    mov   ARG_REG1, ARG_REG2
    rcall SPI_MASTER_TRANSMIT
    SPI_END_ETH
    ret
/* }}} */
/*******************************************************************************
 * Clear the given bits into the register {{{
 * Inputs:
 * - ARG_REG1: Register address
 * - ARG_REG2: Mask with bits that are going to be clear
 ******************************************************************************/
ETH_BIT_FIELD_CLEAR:
    /* command is 101AAAAA, then corresponding prefix */
    sbr   ARG_REG1, ETH_SPI_CMD_BFC
    SPI_SELECT_ETH
    rcall SPI_MASTER_TRANSMIT
    mov   ARG_REG1, ARG_REG2
    rcall SPI_MASTER_TRANSMIT
    SPI_END_ETH
    ret
/* }}} */
/*******************************************************************************
 * Wait until device is ready {{{
 ******************************************************************************/
ETH_WAIT_UNTIL_READY:
    ldi   ARG_REG1, ENC_COMMON_ESTAT
    rcall ETH_READ_CONTROL_REGISTER
    sbrs  RETURN_VALUE, ENC_COMMON_ESTAT_CLKRDY
    rjmp  ETH_WAIT_UNTIL_READY
    ret
/* }}} */
/*******************************************************************************
 * Enable packet reception {{{
 ******************************************************************************/
ETH_ENABLE_RECEIVE:
    rcall ETH_WAIT_UNTIL_READY
    ldi   ARG_REG1, ENC_COMMON_ECON1
    ldi   ARG_REG2, ENC_COMMON_ECON1_RXEN
    rcall ETH_BIT_FIELD_SET
    ret
/* }}} */
/*******************************************************************************
 * Set Bank {{{
 * It seems to be to much extra SPI communication, so, better just set the bank
 * as needed
 ******************************************************************************/
#if 0
ETH_SET_BANK:
    /* Would've been more efficient to use ARG_REG2 from the beginning, but,
     * looks ugly to use ARG_REG2 when we only have 1 argument */
    mov   ARG_REG2, ARG_REG1
    ldi   ARG_REG1, ENC_COMMON_ECON1
    push  ARG_REG2
    rcall ETH_BIT_FIELD_SET
    ldi   ARG_REG1, ENC_COMMON_ECON1
    pop   ARG_REG2
    com   ARG_REG2
    andi  ARG_REG2, ENC_COMMON_BANK_MASK
    rcall ETH_BIT_FIELD_CLEAR
    ret
#endif
/* }}} */
/*******************************************************************************
 * Enable interrupts {{{
 * The INT Interrupt Enable bit (INTIE) is a global enable bit which allows the
 * following interrupts to drive the INT pin:
 * - Receive Error Interrupt (RXERIF)
 * - Transmit Error Interrupt (TXERIF)
 * - Transmit Interrupt (TXIF)
 * - Link Change Interrupt (LINKIF)
 * - DMA Interrupt (DMAIF)
 * - Receive Packet Pending Interrupt (PKTIF)
 ******************************************************************************/
ETH_ENABLE_RECEIVE_INTERRUPT:
    ldi   ARG_REG1, ENC_COMMON_EIE
    ldi   ARG_REG2, (1 << ENC_COMMON_EIE_INTIE)  | \
                    (1 << ENC_COMMON_EIE_PKTIE)  | \
                    (1 << ENC_COMMON_EIE_DMAIE)  | \
                    (1 << ENC_COMMON_EIE_LINKIE) | \
                    (1 << ENC_COMMON_EIE_TXIE)   | \
                    (1 << ENC_COMMON_EIE_TXERIE) | \
                    (1 << ENC_COMMON_EIE_RXERIE)
    rcall ETH_BIT_FIELD_SET
    ret
/* }}} */
/*******************************************************************************
 * Software reset {{{
 ******************************************************************************/
ETH_SOFTWARE_RESET:
    ldi   ARG_REG1, ETH_SPI_CMD_SRC
    SPI_SELECT_ETH
    rcall SPI_MASTER_TRANSMIT
    SPI_END_ETH
    ret
/* }}} */
/*******************************************************************************
 * Buffer initialization {{{
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

#define BUF_RX_SIZE (((BUF_RX_ND_H << 8) + BUF_RX_ND_L) - \
                     ((BUF_RX_ST_H << 8) + BUF_RX_ST_L) + 1)

ETH_BUFFER_INIT:
    /* SET BANK 0 */
    ldi   ARG_REG1, ENC_COMMON_ECON1
    ldi   ARG_REG2, ENC_COMMON_ECON1_BSEL0 | ENC_COMMON_ECON1_BSEL1
    rcall ETH_BIT_FIELD_CLEAR

    /* Memory in range [ERXST, ERXND] dedicated to receive HW */
    /* ERXST 13 bits, need to program: (recommended even number) */
    /* ERXND 13 bits, need to program: */

    /* Setting transmission to [0:0x1AFF] and Receive to 0x1F00 */

    /* Transmit start */
    ldi   ARG_REG1, ENC_BANK0_ETXSTL
    ldi   ARG_REG2, BUF_TX_ST_L
    rcall ETH_WRITE_CONTROL_REGISTER
    ldi   ARG_REG1, ENC_BANK0_ETXSTH
    ldi   ARG_REG2, BUF_TX_ST_H
    rcall ETH_WRITE_CONTROL_REGISTER

    /* Transmit end */
    ldi   ARG_REG1, ENC_BANK0_ETXNDL
    ldi   ARG_REG2, BUF_TX_ND_L
    rcall ETH_WRITE_CONTROL_REGISTER
    ldi   ARG_REG1, ENC_BANK0_ETXNDH
    ldi   ARG_REG2, BUF_TX_ND_H
    rcall ETH_WRITE_CONTROL_REGISTER

    /* JUST NEED 7 BYTES FOR STATUS VECTOR BETWEEN TRANSMIT AND RECEIVE */
    /* Receive start */
    ldi   ARG_REG1, ENC_BANK0_ERXSTL
    ldi   ARG_REG2, BUF_RX_ST_L
    rcall ETH_WRITE_CONTROL_REGISTER
    ldi   ARG_REG1, ENC_BANK0_ERXSTH
    ldi   ARG_REG2, BUF_RX_ST_H
    rcall ETH_WRITE_CONTROL_REGISTER

    /* Programming ERXRDPTx to the same value than ERXSTx
     * The ERXRDPT registers define a location within the FIFO where the receive
     * hardware is forbidden to write to. In normal operation, the receive
     * hardware will write data up to, but not including, the memory pointed to
     * by ERXRDPT.
     */
    ldi   ARG_REG1, ENC_BANK0_ERXRDPTL
    ldi   ARG_REG2, BUF_RX_ST_L
    rcall ETH_WRITE_CONTROL_REGISTER
    ldi   ARG_REG1, ENC_BANK0_ERXRDPTH
    ldi   ARG_REG2, BUF_RX_ST_H
    rcall ETH_WRITE_CONTROL_REGISTER

    /* Programming ERDPT (read point for RBM) to the start of receive area */
    ldi   ARG_REG1, ENC_BANK0_ERDPTL
    ldi   ARG_REG2, BUF_RX_ST_L
    rcall ETH_WRITE_CONTROL_REGISTER
    ldi   ARG_REG1, ENC_BANK0_ERDPTH
    ldi   ARG_REG2, BUF_RX_ST_H
    rcall ETH_WRITE_CONTROL_REGISTER

    /* Receive end */
    ldi   ARG_REG1, ENC_BANK0_ERXNDL
    ldi   ARG_REG2, BUF_RX_ND_L
    rcall ETH_WRITE_CONTROL_REGISTER
    ldi   ARG_REG1, ENC_BANK0_ERXNDH
    ldi   ARG_REG2, BUF_RX_ND_H
    rcall ETH_WRITE_CONTROL_REGISTER

    /* SET BANK 1 */
    /* filter */
    ldi   ARG_REG1, ENC_COMMON_ECON1
    ldi   ARG_REG2, ENC_COMMON_ECON1_BSEL0
    rcall ETH_BIT_FIELD_SET

    /* Promiscuous mode */
    ldi   ARG_REG1, ENC_BANK1_ERXFCON
    ldi   ARG_REG2, ENC_BANK1_ERXFCON_UCEN | ENC_BANK1_ERXFCON_CRCEN | ENC_BANK1_ERXFCON_BCEN
    rcall ETH_WRITE_CONTROL_REGISTER

    /* Power-on Reset, the ENC_COMMON_ESTAT.CLKRDY bit should be polled to make certain that
     * enough time
     */
    rcall ETH_WAIT_UNTIL_READY
    ret
/* }}} */
/*******************************************************************************
 * Mac initialization {{{
 ******************************************************************************/
ETH_MAC_INIT: /* ONLY ONCE */
    /* SET BANK 2 */
    ldi   ARG_REG1, ENC_COMMON_ECON1
    ldi   ARG_REG2, ENC_COMMON_ECON1_BSEL0
    rcall ETH_BIT_FIELD_CLEAR
    ldi   ARG_REG1, ENC_COMMON_ECON1
    ldi   ARG_REG2, ENC_COMMON_ECON1_BSEL1
    rcall ETH_BIT_FIELD_SET

    /* ENC_BANK2_MACON1 */
    ldi   ARG_REG1, ENC_BANK2_MACON1
    ldi   ARG_REG2, ENC_BANK2_MACON1_MARXEN | ENC_BANK2_MACON1_FULL_DUPLEX
    rcall ETH_BIT_FIELD_SET

    /* ENC_BANK2_MACON3 */
    ldi   ARG_REG1, ENC_BANK2_MACON3
    ldi   ARG_REG2, ENC_BANK2_MACON3_PADCFG0 | ENC_BANK2_MACON3_TXCRCEN | ENC_BANK2_MACON3_FULL_DUPLEX | ENC_BANK2_MACON3_FRMLNEN
    rcall ETH_BIT_FIELD_SET

    /* ENC_BANK2_MACON4  */
    ldi   ARG_REG1, ENC_BANK2_MACON4
    ldi   ARG_REG2, ENC_BANK2_MACON4_DEFER
    rcall ETH_BIT_FIELD_SET

    /* Max frame length */
    /* Normal network nodes are designed to handle packets that are 1518 bytes or
     * less. 1518 -> 0x5EE
     */
    ldi   ARG_REG1, ENC_BANK2_MAMXFLL
    ldi   ARG_REG2, 0xEE
    rcall ETH_WRITE_CONTROL_REGISTER
    ldi   ARG_REG1, ENC_BANK2_MAMXFLH
    ldi   ARG_REG2, 0x05
    rcall ETH_WRITE_CONTROL_REGISTER

    /* ENC_BANK2_MABBIPG. */
    /* Most applications will program this register with 15h when Full-Duplex
     * mode is used and 12h when Half-Duplex mode is used.
     */
    ldi   ARG_REG1, ENC_BANK2_MABBIPG
    ldi   ARG_REG2, ENC_BANK2_MABBIPG_FULL_DUPLEX
    rcall ETH_WRITE_CONTROL_REGISTER

    /* ENC_BANK2_MAIPGL. */
    /* Configure the Non-Back-to-Back Inter-Packet Gap register low byte, ENC_BANK2_MAIPGL.
     * Most applications will program this register with 12h.
     */
    ldi   ARG_REG1, ENC_BANK2_MAIPGL
    ldi   ARG_REG2, 0x12
    rcall ETH_WRITE_CONTROL_REGISTER

    /* ENC_BANK2_MAIPGH for full duplex to 0x0C */
    ldi   ARG_REG1, ENC_BANK2_MAIPGH
    ldi   ARG_REG2, 0x0C
    rcall ETH_WRITE_CONTROL_REGISTER

    /* ENC_BANK2_MACLCON1 & ENC_BANK2_MACLCON2 default should be ok */

    /* SEST BANK 3 */
    ldi   ARG_REG1, ENC_COMMON_ECON1
    ldi   ARG_REG2, ENC_COMMON_ECON1_BSEL1 | ENC_COMMON_ECON1_BSEL0
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
    ldi   YH, hi8(EEPROM_MAC_ADDR)
    ldi   YL, lo8(EEPROM_MAC_ADDR)
    ldi   TMP_REG2, ENC_BANK3_MAADR1
ETH_MAC_INIT_SET_MAC_LOOP:
    rcall EEPROM_READ_N_INC
    mov   ARG_REG1, TMP_REG2
    mov   ARG_REG2, RETURN_VALUE
    rcall ETH_WRITE_CONTROL_REGISTER
    /* Check loop break */
    cpi   TMP_REG2, ENC_BANK3_MAADR6
    breq  ETH_MAC_INIT_SET_MAC_LOOP_END
    /* Set following MAC ADDR */
    inc   TMP_REG2
    sbrs  TMP_REG2, 0 /* if odd, jump back right away */
    subi  TMP_REG2, 4
    rjmp  ETH_MAC_INIT_SET_MAC_LOOP
ETH_MAC_INIT_SET_MAC_LOOP_END:

    ret
/* }}} */
/*******************************************************************************
 * PHY initialization {{{
 ******************************************************************************/
#if 0
ETH_PHY_INIT: /* ONLY ONCE */
    /* For proper duplex operation, the PHCON1.PDPXMD bit must also match the
     * value of the ENC_BANK2_MACON3.FULDPX bit.
     */
     PHCON2.HDLDIS
     ret
#endif
/* }}} */
/*******************************************************************************
 * Start buffer read {{{
 ******************************************************************************/
ETH_READ_BUFFER_START:
    ldi   ARG_REG1, ETH_SPI_CMD_RBM
    SPI_SELECT_ETH
    rcall SPI_MASTER_TRANSMIT
    ret
/* }}} */
/*******************************************************************************
 * Receive enc28j60 header {{{
 ******************************************************************************/
ETH_READ_RECEIVE_HEADER:
    push  ZL
    push  ZH

    SPI_SELECT_ETH
    ldi   ARG_REG1, ETH_SPI_CMD_RBM
    rcall SPI_MASTER_TRANSMIT

    /* Read the whole receive status vector */
    ldi   COUNTER_REG, RPKT_STATUS_VECTOR_LEN
    ldi   ZH, hi8(RPKT_N_PKT_L)
    ldi   ZL, lo8(RPKT_N_PKT_L)
ETH_READ_RECEIVE_HEADER_LOOP:
    rcall SPI_MASTER_TRANSMIT
    st    Z+, RETURN_VALUE
    dec   COUNTER_REG
    brne  ETH_READ_RECEIVE_HEADER_LOOP
    
    SPI_END_ETH
    pop   ZH
    pop   ZL
    ret
/* }}} */
/*******************************************************************************
 * Check receive status vector {{{
 * Returns Zero if packet is good to be processed, else, != 0
 ******************************************************************************/
ETH_CHECK_RECEIVE_STATUS_VECTOR:
    /* Check Received packet status 3 {{{ */
    lds  RETURN_VALUE, RPKT_STATUS3
    /* Discard VLAN, Unknown Opcode, Pause Control Frame, Control Frame */
    andi RETURN_VALUE, ~((1 << RPKT_STATUS3_RECEIVE_BROADCAST_PACKET) | \
                         (1 << RPKT_STATUS3_RECEIVE_MULTICAST_PACKET) | \
                         (1 << RPKT_STATUS3_DRIBBLE_NIBBLE))
    /* }}} */
    /* Check Received packet status 2 {{{ */
    lds  TMP_REG1, RPKT_STATUS2
    /* If OK bit is not set, then, set MSB bit on RETURN_VALUE */
    sbrs TMP_REG1, RPKT_STATUS2_RECEIVED_OK
    sbr  RETURN_VALUE, 0x80
    /* }}} */
    ret
/* }}} */
/*******************************************************************************
 * Read Ethernet header (Mac addresses and Type/Len {{{
 * Update the Dst Mac Address ptr and the type/len ptr when reading the header
 *
 * TYPE/LENGTH
 * The type/length field is a 2-byte field which defines which protocol the
 * following packet data belongs to.  Alternately, if the field is filled with
 * the contents of 05DCh (1500) or any smaller number, the field is considered a
 * length field and it specifies the amount of non-padding data which follows in
 * the data field.
 ******************************************************************************/
ETH_READ_MAC_ADDRS_N_LEN_TYPE:
    ldi   ARG_REG1, ETH_SPI_CMD_RBM
    SPI_SELECT_ETH
    rcall SPI_MASTER_TRANSMIT

    /* Using register Z for SRAM write incremental */
    push  ZL
    push  ZH

    /* Mac address SRC/DST and Type/len is all continuous in memory */
    ldi   TMP_REG1, (MAC_SIZE_IN_BYTES + MAC_SIZE_IN_BYTES + 2)
    ldi   ZH, hi8(ETH_HEADER)
    ldi   ZL, lo8(ETH_HEADER)
ETH_READ_MAC_ADDRS_N_LEN_TYPE_KEEP_READING:
    rcall SPI_MASTER_TRANSMIT
    st    Z+, RETURN_VALUE
    dec   TMP_REG1
    brne  ETH_READ_MAC_ADDRS_N_LEN_TYPE_KEEP_READING

    /* Update Mac Addr Dst & Type/Len ptr */
    /* TODO: Could be done in other way */
    ldi   TMP_REG1, hi8(MAC_ADDR_OTHER)
    sts   ENC_MAC_DST_PTR + 0, TMP_REG1
    ldi   TMP_REG1, lo8(MAC_ADDR_OTHER)
    sts   ENC_MAC_DST_PTR + 1, TMP_REG1

    ldi   TMP_REG1, hi8(TYPE_LEN_H)
    sts   ENC_TYPE_LEN_PTR + 0, TMP_REG1
    ldi   TMP_REG1, lo8(TYPE_LEN_H)
    sts   ENC_TYPE_LEN_PTR + 1, TMP_REG1

    pop   ZH
    pop   ZL
    SPI_END_ETH
    ret
/* }}} */
/*******************************************************************************
 * Free the space of the packet that was processed {{{
 ******************************************************************************/
ETH_PKT_PROCESSED:
    /* Set BANK 0 */
    ldi   ARG_REG1, ENC_COMMON_ECON1
    ldi   ARG_REG2, ENC_COMMON_ECON1_BSEL0 | ENC_COMMON_ECON1_BSEL1
    rcall ETH_BIT_FIELD_CLEAR

    /* Move the RX Read Point to the next packet */
    ldi   ARG_REG1, ENC_BANK0_ERXRDPTL
    lds   ARG_REG2, RPKT_N_PKT_L
    rcall ETH_WRITE_CONTROL_REGISTER

    ldi   ARG_REG1, ENC_BANK0_ERXRDPTH
    lds   ARG_REG2, RPKT_N_PKT_H
    rcall ETH_WRITE_CONTROL_REGISTER

    /* Decrement received packet count */
    ldi   ARG_REG1, ENC_COMMON_ECON2
    ldi   ARG_REG2, ENC_COMMON_ECON2_PKTDEC
    rcall ETH_BIT_FIELD_SET

    /* Move the Read Pointer to the next packet */
    ldi   ARG_REG1, ENC_BANK0_ERDPTL
    lds   ARG_REG2, RPKT_N_PKT_L
    rcall ETH_WRITE_CONTROL_REGISTER

    ldi   ARG_REG1, ENC_BANK0_ERDPTH
    lds   ARG_REG2, RPKT_N_PKT_H
    rcall ETH_WRITE_CONTROL_REGISTER

    ret
/* }}} */
/*******************************************************************************
 * Write message header, Per packet control byte + Mac addresses + Type/Len {{{
 * ENC_MAC_DST_PTR pointer to Dst MAC address
 *   As we have 1k of SRAM, only the 11 LSB are used for addresses, then we have
 *   5 MBS to encode other options.
 *     If MSB of the pointer is set, then, the address is not a pointer and the
 *     MAC Dst is broadcast
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
    /* Set BANK 0 */
    ldi   ARG_REG1, ENC_COMMON_ECON1
    ldi   ARG_REG2, ENC_COMMON_ECON1_BSEL0 | ENC_COMMON_ECON1_BSEL1
    rcall ETH_BIT_FIELD_CLEAR

    /* Set Write Pointer EWRPT to start of transmit buffer */
    ldi   ARG_REG1, ENC_BANK0_EWRPTL
    ldi   ARG_REG2, BUF_TX_ST_L
    rcall ETH_WRITE_CONTROL_REGISTER

    ldi   ARG_REG1, ENC_BANK0_EWRPTH
    ldi   ARG_REG2, BUF_TX_ST_H
    rcall ETH_WRITE_CONTROL_REGISTER

    /* Send write command */
    ldi   ARG_REG1, ETH_SPI_CMD_WBM
    SPI_SELECT_ETH
    rcall SPI_MASTER_TRANSMIT

    /* Write the packet header { */
    ldi   ARG_REG1, PPCB_POVERRIDE | PPCB_PCRCEN | PPCB_PPADEN
    rcall SPI_MASTER_TRANSMIT

    /* Write Dst Mac address */
    ldi   YH, hi8(ENC_MAC_DST_PTR)
    ldi   YL, lo8(ENC_MAC_DST_PTR)
    ld    TMP_PTR_H, Y+    /* High address ptr */
    /* Check if MSB is set to broadcast */
    sbrc  TMP_PTR_H, ENC_MAC_DST_PTR_BROADCAST_BIT
    rjmp  ETH_WRITE_BUFFER_MAC_DST_BROADCAST

    ld    TMP_PTR_L, Y     /* Low  address ptr */
    mov   YH, TMP_PTR_H
    mov   YL, TMP_PTR_L
    ldi   COUNTER, MAC_SIZE_IN_BYTES
ETH_WRITE_BUFFER_MAC_DST:
    ld    ARG_REG1, Y+
    rcall SPI_MASTER_TRANSMIT
    dec   COUNTER
    brne  ETH_WRITE_BUFFER_MAC_DST
    rjmp  ETH_WRITE_BUFFER_MAC_SRC

ETH_WRITE_BUFFER_MAC_DST_BROADCAST:
    ldi   COUNTER, MAC_SIZE_IN_BYTES
ETH_WRITE_BUFFER_MAC_DST_BROADCAST_LOOP:
    ldi   ARG_REG1, 0xFF
    rcall SPI_MASTER_TRANSMIT
    dec   COUNTER
    brne  ETH_WRITE_BUFFER_MAC_DST_BROADCAST_LOOP

    /* Write Src Mac address */
ETH_WRITE_BUFFER_MAC_SRC:
    ldi   COUNTER, MAC_SIZE_IN_BYTES
    ldi   YL, lo8(EEPROM_MAC_ADDR)
    ldi   YH, hi8(EEPROM_MAC_ADDR)
ETH_WRITE_BUFFER_PACKET_HEADER_WRITE_SRC_MAC:
    rcall EEPROM_READ_N_INC
    mov   ARG_REG1, RETURN_VALUE
    rcall SPI_MASTER_TRANSMIT
    dec   COUNTER
    brne  ETH_WRITE_BUFFER_PACKET_HEADER_WRITE_SRC_MAC

    /* Write Type/Len */
    ldi   YH, hi8(ENC_TYPE_LEN_PTR)
    ldi   YL, lo8(ENC_TYPE_LEN_PTR)
    ld    TMP_PTR_H, Y+    /* High address ptr */
    /* Check if MSB is IPv4 */
    sbrc  TMP_PTR_H, ENC_TYPE_LEN_PTR_IPv4
    rjmp  ETH_WRITE_BUFFER_TYPE_LEN_IPv4

    ld    TMP_PTR_L, Y     /* Low  address ptr */
    mov   YH, TMP_PTR_H
    mov   YL, TMP_PTR_L
    ld    ARG_REG1, Y+
    rcall SPI_MASTER_TRANSMIT
    ld    ARG_REG1, Y+
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
/* }}} */
/*******************************************************************************
 * Send write command and leave SPI waiting {{{
 ******************************************************************************/
ETH_SET_LISTEN_ON_SPI:
    /* Send write command */
    ldi   ARG_REG1, ETH_SPI_CMD_WBM
    SPI_SELECT_ETH
    rcall SPI_MASTER_TRANSMIT
    ret

#define ETH_END_LISTEN_ON_SPI SPI_END_ETH
/* }}} */
/*******************************************************************************
 * Write Payload {{{
 * Z is a pointer to memory to where start writing from
 * ARG_REG1 is number of byte to write
 ******************************************************************************/
ETH_WRITE_Z_TO_TRANSMIT_BUFFER:
    /* Send write command */
    push  TMP_REG2
    mov   TMP_REG2, ARG_REG1
    ldi   ARG_REG1, ETH_SPI_CMD_WBM
    SPI_SELECT_ETH
    rcall SPI_MASTER_TRANSMIT

ETH_WRITE_BUFFER_PACKET_PAYLOAD_KEEP_WRITING:
    ld    ARG_REG1, Z+
    rcall SPI_MASTER_TRANSMIT
    dec   TMP_REG2
    brne  ETH_WRITE_BUFFER_PACKET_PAYLOAD_KEEP_WRITING
    pop   TMP_REG2
    SPI_END_ETH
    ret
/* }}} */
/*******************************************************************************
 * Finish Write Payload {{{
 ******************************************************************************/
ETH_WRITE_BUFFER_PACKET_PAYLOAD_FINISH:
    /* read EWRPT and set BANK0 */
    push  ZH
    push  ZL
    rcall ETH_GET_EWRPT_BANK0_TO_Z

    sbiw  ZL, 1

    ldi   ARG_REG1, ENC_BANK0_ETXNDL
    mov   ARG_REG2, ZL
    rcall ETH_WRITE_CONTROL_REGISTER
    ldi   ARG_REG1, ENC_BANK0_ETXNDH
    mov   ARG_REG2, ZH
    rcall ETH_WRITE_CONTROL_REGISTER

    pop   ZL
    pop   ZH
    /* Clear ENC_COMMON_EIR.TXIF, set ENC_COMMON_EIE.TXIE and set ENC_COMMON_EIE.INTIE
     *   to enable an interrupt when done (if desired).
     *   Start the transmission process by setting
     */
    ldi   ARG_REG1, ENC_COMMON_EIR
    ldi   ARG_REG2, (1 << ENC_COMMON_EIR_TXIF)
    rcall ETH_BIT_FIELD_CLEAR

    ldi   ARG_REG1, ENC_COMMON_EIE
    ldi   ARG_REG2, (1 << ENC_COMMON_EIE_TXIE) | (1 << ENC_COMMON_EIE_INTIE)
    rcall ETH_BIT_FIELD_SET

    /* Set bits to send packet */
    ldi   ARG_REG1, ENC_COMMON_ECON1
    ldi   ARG_REG2, ENC_COMMON_ECON1_TXRTS
    rcall ETH_BIT_FIELD_SET

ETH_WRITE_BUFFER_PACKET_PAYLOAD_FINISH_WAIT:
    ldi   ARG_REG1, ENC_COMMON_ECON1
    rcall ETH_READ_CONTROL_REGISTER
    sbrc  RETURN_VALUE, ENC_COMMON_ECON1_RXEN_BIT
    rjmp  ETH_WRITE_BUFFER_PACKET_PAYLOAD_FINISH_WAIT

    ldi   ARG_REG1, ENC_COMMON_EIR
    ldi   ARG_REG2, (1 << ENC_COMMON_EIR_TXIF)
    rcall ETH_BIT_FIELD_CLEAR

    ret
/* }}} */
/*******************************************************************************
 * Get EWRPT into Z {{{
 * BEWARE, THIS ROUTINE IS GOING TO MODIFY THE CURRENT BANK, setting BANK0
 * Return [EWRPTH:EWRPTL] into [ZH:ZL]
 ******************************************************************************/
ETH_GET_EWRPT_BANK0_TO_Z:
    push  ARG_REG1
    push  ARG_REG2
    push  RETURN_VALUE

    /* Set BANK 0 */
    ldi   ARG_REG1, ENC_COMMON_ECON1
    ldi   ARG_REG2, ENC_COMMON_ECON1_BSEL0 | ENC_COMMON_ECON1_BSEL1
    rcall ETH_BIT_FIELD_CLEAR

    /* read EWRPT */
    ldi   ARG_REG1, ENC_BANK0_EWRPTL
    rcall ETH_READ_CONTROL_REGISTER
    mov   ZL, RETURN_VALUE

    ldi   ARG_REG1, ENC_BANK0_EWRPTH
    rcall ETH_READ_CONTROL_REGISTER
    mov   ZH, RETURN_VALUE

    pop   RETURN_VALUE
    pop   ARG_REG2
    pop   ARG_REG1
    ret
/* }}} */
/*******************************************************************************
 * Move the RDPT {{{
 *
 * Increment/Decrement value in [ARG_REG1:ARG_REG2] 
 *
 * ERDPT is 13 bits long
 *
 * RANDOM ACCESS ADDRESS CALCULATION
 *   if Packet Start Address + Offset > ERXND, then
 *      ERDPT = Packet Start Address + Offset - (ERXND - ERXST + 1)
 *   else
 *      ERDPT = Packet Start Address + Offset
 ******************************************************************************/
#define RDPT_H R23
#define RDPT_L R24
ETH_MOVE_READ_POINTER:
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
    mov   RDPT_H, RETURN_VALUE

    ldi   ARG_REG1, ENC_BANK0_ERDPTL
    rcall ETH_READ_CONTROL_REGISTER
    mov   RDPT_L, RETURN_VALUE

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

    ret
/* }}} */
/*******************************************************************************
 * Write debug message into Ethernet {{{
 ******************************************************************************/
#if 0
ETH_SEND_DEBUG:
    push  ZL
    push  ZH
    push  TMP_REG1 /* Counter */
    push  TMP_REG2 /* Data holder */
    /* Set BANK 0 */
    ldi   ARG_REG1, ENC_COMMON_ECON1
    ldi   ARG_REG2, ENC_COMMON_ECON1_BSEL0 | ENC_COMMON_ECON1_BSEL1
    rcall ETH_BIT_FIELD_CLEAR

    /* Set Write Pointer to the end of the transmission buffer less the bytes we
     * are going to write */
#if 1
    ldi   ARG_REG1, ENC_BANK0_EWRPTL
    ldi   ARG_REG2, lo8(((BUF_TX_ND_H << 8) | BUF_TX_ND_L) - DEBUG_FRAME_SIZE)
    rcall ETH_WRITE_CONTROL_REGISTER
    ldi   ARG_REG1, ENC_BANK0_ETXSTL
    ldi   ARG_REG2, lo8(((BUF_TX_ND_H << 8) | BUF_TX_ND_L) - DEBUG_FRAME_SIZE)
    rcall ETH_WRITE_CONTROL_REGISTER

    ldi   ARG_REG1, ENC_BANK0_EWRPTH
    ldi   ARG_REG2, hi8(((BUF_TX_ND_H << 8) | BUF_TX_ND_L) - DEBUG_FRAME_SIZE)
    rcall ETH_WRITE_CONTROL_REGISTER
    ldi   ARG_REG1, ENC_BANK0_ETXSTH
    ldi   ARG_REG2, hi8(((BUF_TX_ND_H << 8) | BUF_TX_ND_L) - DEBUG_FRAME_SIZE)
    rcall ETH_WRITE_CONTROL_REGISTER
#else
    /* Set Write Pointer EWRPT to start of transmit buffer */
    ldi   ARG_REG1, ENC_BANK0_EWRPTL
    ldi   ARG_REG2, BUF_TX_ST_L
    rcall ETH_WRITE_CONTROL_REGISTER

    ldi   ARG_REG1, ENC_BANK0_EWRPTH
    ldi   ARG_REG2, BUF_TX_ST_H
    rcall ETH_WRITE_CONTROL_REGISTER
#endif

    /* Send write command */
    ldi   ARG_REG1, ETH_SPI_CMD_WBM
    SPI_SELECT_ETH
    rcall SPI_MASTER_TRANSMIT

    /* Write the packet header { */
    ldi   ARG_REG1, PPCB_POVERRIDE | PPCB_PCRCEN | PPCB_PPADEN
    rcall SPI_MASTER_TRANSMIT

    /* Write Dst Mac address */
    ldi   TMP_REG1, MAC_SIZE_IN_BYTES
    ldi   ZH, hi8(EEPROM_MAC_DEBUG)
    ldi   ZL, lo8(EEPROM_MAC_DEBUG)
ETH_SEND_DEBUG_WRITE_DST_MAC:
    out   _SFR_IO_ADDR(EEARH), ZH
    out   _SFR_IO_ADDR(EEARL), ZL
    sbi   _SFR_IO_ADDR(EECR), EERE
    in    ARG_REG1, _SFR_IO_ADDR(EEDR)
    rcall SPI_MASTER_TRANSMIT
    adiw  ZL, 1
    dec   TMP_REG1
    brne  ETH_SEND_DEBUG_WRITE_DST_MAC

    /* Write Src Mac address */
    ldi   TMP_REG1, MAC_SIZE_IN_BYTES
    ldi   ZL, lo8(EEPROM_MAC_ADDR)
    ldi   ZH, hi8(EEPROM_MAC_ADDR)
ETH_SEND_DEBUG_WRITE_SRC_MAC:
    out   _SFR_IO_ADDR(EEARH), ZH
    out   _SFR_IO_ADDR(EEARL), ZL
    sbi   _SFR_IO_ADDR(EECR), EERE
    in    ARG_REG1, _SFR_IO_ADDR(EEDR)
    rcall SPI_MASTER_TRANSMIT
    adiw  ZL, 1
    dec   TMP_REG1
    brne  ETH_SEND_DEBUG_WRITE_SRC_MAC

    /* Write Type/Len */
#define ETHER_TYPE_DEBUG 0x1987
    ldi   ARG_REG1, hi8(ETHER_TYPE_DEBUG)
    rcall SPI_MASTER_TRANSMIT
    ldi   ARG_REG1, lo8(ETHER_TYPE_DEBUG)
    rcall SPI_MASTER_TRANSMIT

    /* } */

    lds   TMP_REG2, DEBUG_OPT
    cpi   TMP_REG2, DEBUG_OPT_WRITE_SRAM
    brne  DEBUG_OPT_2

DEBUG_OPT_1:
    lds   ZL, DEBUG_ADDR_L
    lds   ZH, DEBUG_ADDR_H
    lds   TMP_REG1, DEBUG_LEN
DEBUG_OPT_1_LOOP:
    ld    ARG_REG1, Z+
    rcall SPI_MASTER_TRANSMIT
    dec   TMP_REG1
    brne  DEBUG_OPT_1_LOOP
    rjmp  DEBUG_OPT_END

DEBUG_OPT_2:
    cpi   TMP_REG2, DEBUG_OPT_RECEIVE_BUFFER
    brne  DEBUG_OPT_END
    /* Save read pointer */
    SPI_END_ETH
    ldi   ARG_REG1, ENC_BANK0_ERDPTL
    rcall ETH_READ_CONTROL_REGISTER
    push  RETURN_VALUE
    ldi   ARG_REG1, ENC_BANK0_ERDPTH
    rcall ETH_READ_CONTROL_REGISTER
    push  RETURN_VALUE

    /* Set read pointer to beginning of READ BUFFER */
    ldi   ARG_REG1, ENC_BANK0_ERDPTL
    ldi   ARG_REG2, BUF_RX_ST_L
    rcall ETH_WRITE_CONTROL_REGISTER
    ldi   ARG_REG1, ENC_BANK0_ERDPTH
    ldi   ARG_REG2, BUF_RX_ST_H
    rcall ETH_WRITE_CONTROL_REGISTER

    /* Read from READ BUFFER and write to WRITE BUFFER */
    /* TODO: DEBUG_PAYLOAD_SIZE <- TMP_REG1 */
#if 1
    ldi   TMP_REG1, DEBUG_PAYLOAD_SIZE
DEBUG_OPT_2_WRITE_PAYLOAD:
    /* Send read command */
    ldi   ARG_REG1, ETH_SPI_CMD_RBM
    SPI_SELECT_ETH
    rcall SPI_MASTER_TRANSMIT
    rcall SPI_MASTER_TRANSMIT
    push  RETURN_VALUE
    SPI_END_ETH
    /* Send write command */
    ldi   ARG_REG1, ETH_SPI_CMD_WBM
    SPI_SELECT_ETH
    rcall SPI_MASTER_TRANSMIT
    pop   ARG_REG1
    rcall SPI_MASTER_TRANSMIT
    SPI_END_ETH
    dec   TMP_REG1
    brne  DEBUG_OPT_2_WRITE_PAYLOAD
#endif

    /* Restore read pointer */
    ldi   ARG_REG1, ENC_BANK0_ERDPTH
    pop   ARG_REG2
    rcall ETH_WRITE_CONTROL_REGISTER
    ldi   ARG_REG1, ENC_BANK0_ERDPTL
    pop   ARG_REG2
    rcall ETH_WRITE_CONTROL_REGISTER

DEBUG_OPT_END:
    SPI_END_ETH
    rcall ETH_WRITE_BUFFER_PACKET_PAYLOAD_FINISH

    pop   TMP_REG2
    pop   TMP_REG1
    pop   ZH
    pop   ZL

    /* Set BANK 0 */
    ldi   ARG_REG1, ENC_COMMON_ECON1
    ldi   ARG_REG2, ENC_COMMON_ECON1_BSEL0 | ENC_COMMON_ECON1_BSEL1
    rcall ETH_BIT_FIELD_CLEAR
    /* RESET TRANSMIT START */
    ldi ARG_REG1, ENC_BANK0_ETXSTL
    ldi ARG_REG2, BUF_TX_ST_L
    rcall ETH_WRITE_CONTROL_REGISTER
    ldi ARG_REG1, ENC_BANK0_ETXSTH
    ldi ARG_REG2, BUF_TX_ST_H
    rcall ETH_WRITE_CONTROL_REGISTER
    ret
#endif
/* }}} */
