/* vim: set filetype=S foldmethod=marker: */
.NOLIST
#include <avr/io.h>
#include "defs.h"
#include "spi.h"
.LIST

.global SPI_MASTER_INIT
.global SPI_MASTER_TRANSMIT

//#define SPI_SLOW /* {{{ */
#ifdef  SPI_SLOW
#   define SPI_SCK ((1 << SPR1)|(1 << SPR0))
#   define SPI_SLOW_DELAY rcall DELAY_TMP
#else
#   define SPI_SCK (1 << SPR0)
#   define SPI_SLOW_DELAY
#endif /* }}} */

/*******************************************************************************
 * Init SPI {{{
 * Set SS, so all slaves are not listening
 * Set pins as output:
 * - MOSI
 * - SCK
 * - SS (This must be handle by user code)
 * Set bits on register:
 * - SPE  enable SPI
 * - MSTR set as master
 * - SPR1 set, clock rate fck/64
 ******************************************************************************/
SPI_MASTER_INIT:
    SPI_END_LCD
    SPI_END_ETH
    ldi TMP_REG2, ((1 << SPI_MOSI_BIT) | \
                   (1 << SPI_SCK_BIT)  | \
                   (1 << SPI_SS_LCD)   | \
                   (1 << SPI_SS_ETH))
    out _SFR_IO_ADDR(SPI_MOSI_DDR), TMP_REG2
    ldi TMP_REG2, (1 << SPE)|(1 << MSTR)|SPI_SCK
    out _SFR_IO_ADDR(SPCR), TMP_REG2
    ret
/* }}} */

/*******************************************************************************
 * Init SPI {{{
 * We need to:
 * - SS must be set previous to this routine
 * - Being lazy, setting both slave off after every transmission
 * - Set data in register SPSR
 * - Wait for transmission to finish
 * - ? handle interrupt ?
 * - Clear SS
 ******************************************************************************/
SPI_MASTER_TRANSMIT:
    /* Start transmission of data on (ARG_REG1) */
    out _SFR_IO_ADDR(SPDR), ARG_REG1

    /* Wait for transmission complete */
SPI_WAIT_TRANSMIT:
    sbis _SFR_IO_ADDR(SPSR), SPIF
    rjmp SPI_WAIT_TRANSMIT

    /* TODO: remove this part */
    ; Clear SS for both slaves
    SPI_END_LCD

    SPI_SLOW_DELAY

    /* Get received message */
    in RETURN_VALUE, _SFR_IO_ADDR(SPDR)
    ret
/* }}} */
