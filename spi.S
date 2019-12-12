/* vim: set filetype=S foldmethod=marker: */
/* INCLUDES {{{1 */
.NOLIST
#include <avr/io.h>
#include "defs.h"
#include "spi.h"
.LIST

/* MACORS {{{1 ---------------------------------------------------------------*/
//#define SPI_SLOW
#ifdef  SPI_SLOW
#   define SPI_SCK ((1 << SPR1)|(1 << SPR0))
#else
#   define SPI_SCK (1 << SPR0)
#endif

/* GLOBAL {{{1 ---------------------------------------------------------------*/
.global SPI_MASTER_INIT
.global SPI_MASTER_TRANSMIT
.global SPI_EEPROM_TRANSMIT
.global SPI_MEMCPY

/* TEXT {{{1 -----------------------------------------------------------------*/
.section .text

/* Init SPI {{{2 ---------------------------------------------------------------
 * Set SS, so all slaves are not listening
 * Set pins as output:
 * - MOSI
 * - SCK
 * - SS (This must be handle by user code)
 * Set bits on register:
 * - SPE  enable SPI
 * - MSTR set as master
 * - SPR1 set, clock rate fck/64 */
SPI_MASTER_INIT:
    SPI_END_ETH
    ldi TMP_REG2, ((1 << SPI_MOSI_BIT) | \
                   (1 << SPI_SCK_BIT)  | \
                   (1 << SPI_SS_ETH))
    out _SFR_IO_ADDR(SPI_MOSI_DDR), TMP_REG2
    ldi TMP_REG2, (1 << SPE)|(1 << MSTR)|SPI_SCK
    out _SFR_IO_ADDR(SPCR), TMP_REG2
    ret

/* Init SPI {{{2 ---------------------------------------------------------------
 * We need to:
 * - SS must be set previous to this routine
 * - Set data in register SPSR
 * - Wait for transmission to finish
 * - ? handle interrupt ?
 * - SS should be clear on the caller
 ******************************************************************************/
SPI_MASTER_TRANSMIT:
    /* Start transmission of data on (ARG_REG1) */
    out   _SFR_IO_ADDR(SPDR), ARG_REG1
    /* Wait for transmission complete */
0:  sbis  _SFR_IO_ADDR(SPSR), SPIF
    rjmp  0b
    /* Get received message */
    in    RTV_L_REG, _SFR_IO_ADDR(SPDR)
    ret

/* Write ARG_REG1 bytes from Y (EEPROM) to SPI {{{2 ----------------------------
   */
SPI_EEPROM_TRANSMIT:
    mov   COUNTER_REG, ARG_REG1
0:  rcall EEPROM_READ_N_INC
    mov   ARG_REG1, RTV_L_REG
    rcall SPI_MASTER_TRANSMIT
    dec   COUNTER_REG
    brne  0b
    ret

/* Copy from SPI to memory {{{2 ------------------------------------------------
 * Copy ARG_REG1 from SPI to memory pointed by Z
 */
SPI_MEMCPY:
    dec   ARG_REG1
    brmi  0f
    rcall SPI_MASTER_TRANSMIT
    st    Z+, RTV_L_REG
    rjmp  SPI_MEMCPY
0:  ret

.end
