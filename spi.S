; vim: set filetype=S iskeyword& :
.NOLIST
#include <avr/io.h>
#include "defs.h"
.LIST

#ifndef __SPI_S__
#define __SPI_S__

#define SPI_SS_DDR    DDRB
#define SPI_MOSI_BIT  PB3
#define SPI_MOSI_DDR  DDRB
#define SPI_MISO_BIT  PB4
#define SPI_MISO_DDR  DDRB
#define SPI_SCK_BIT   PB5
#define SPI_SCK_DDR   DDRB

//#define SPI_SLOW

SPI_MASTER_INIT:
   ;----------------------------------------------------------------------------
   ; Set SS, so all slaves are not listening
    ; Set pins as output:
    ; - MOSI
    ; - SCK
    ; - SS (This must be handle by user code)
    ; Set bits on register:
    ; // - SPIE enable interrupt
    ; - SPE  enable spi
    ; - MSTR set as master
    ; - SPR1 set, clock rate fck/64
    ;----------------------------------------------------------------------------
    SPI_END_LCD
    SPI_END_ETH
    ldi TMP1, ((1 << SPI_MOSI_BIT)| \
               (1 << SPI_SCK_BIT)| \
               (1 << SPI_SS_LCD)| \
               (1 << SPI_SS_ETH))
    out _SFR_IO_ADDR(SPI_MOSI_DDR), TMP1
#ifdef SPI_SLOW
    ldi TMP1, (1 << SPE)|(1 << MSTR)|(1 << SPR1)|(1 << SPR0)
#else
    ldi TMP1, (1 << SPE)|(1 << MSTR)|(1 << SPR1)
#endif
    out _SFR_IO_ADDR(SPCR), TMP1
    ret

SPI_MASTER_TRANSMIT:
    ;----------------------------------------------------------------------------
    ; We need to:
    ; - SS must be set previous to this rutine
    ; - Being lazy, setting both slave off after every transmition
    ; - Set data in register SPSR
    ; - Wait for transmission to finish
    ; - ? handle interrupt ?
    ; - Clear SS
    ;----------------------------------------------------------------------------
    ; Start transmission of data on (ARG_REG1)
    out _SFR_IO_ADDR(SPDR), ARG_REG1

    ; Wait for transmission complete
SPI_WAIT_TRANSMIT:
    sbis _SFR_IO_ADDR(SPSR), SPIF
    rjmp SPI_WAIT_TRANSMIT

    ; Clear SS for both slaves
    SPI_END_LCD

#ifdef SPI_SLOW
    rcall DELAY_TMP
#endif

    ; Get received message
    in RETURN_VALUE, _SFR_IO_ADDR(SPDR)
    ret

#endif
