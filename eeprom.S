/* vim: set filetype=S foldmethod=marker: */
/* INCLUDES {{{1 */
.NOLIST
#include <avr/io.h>
#include "defs.h"
#include "eeprom_data.h"
.LIST

/* GLOBAL {{{1 ---------------------------------------------------------------*/
.global EEPROM_READ_N_INC
.global EEPROM_WRITE_N_INC
.global EEPROM_COREDUMP

.global SRAM_EEPROM_TMP_REG1_SAVE
.global SRAM_EEPROM_SREG
.global SRAM_EEPROM_TMP_REG1_SAVE

/* DATA  {{{1 ----------------------------------------------------------------*/
.section .data
SRAM_EEPROM_COREDUMP_DISPLACEMENT:
SRAM_EEPROM_SREG:          .skip 1
SRAM_EEPROM_PCH:           .skip 1
SRAM_EEPROM_PCL:           .skip 1
/* Save t1 during INT1_vect */
/* TODO: cleanup */
SRAM_EEPROM_TMP_REG1_SAVE: .skip 1
AFTER_LAST_COREDUMP_ELEMENT:

/* TEXT {{{1 -----------------------------------------------------------------*/
.section .text

/* Read bytes pointed by Y and return them on x4 {{{2 -------------------
 * Y gets incremented after every call */
EEPROM_READ_N_INC:
    /* Wait for previous write to finish */
    sbic  _SFR_IO_ADDR(EECR), EEWE
    rjmp  EEPROM_READ_N_INC
    /* Set address */
    out   _SFR_IO_ADDR(EEARH), YH
    out   _SFR_IO_ADDR(EEARL), YL
    /* Set Read Enable and read */
    sbi   _SFR_IO_ADDR(EECR), EERE
    in    x4, _SFR_IO_ADDR(EEDR)
    /* Increment Y for continuous eeprom reading */
    adiw  YL, 1
    ret

/* Write x1 to EEPROM pointer by Y {{{2 ----------------------------------
 * Y gets incremented after every call */
EEPROM_WRITE_N_INC:
    /* Wait for previous write to finish */
    sbic  _SFR_IO_ADDR(EECR), EEWE
    rjmp  EEPROM_WRITE_N_INC
    /* Set address */
    out   _SFR_IO_ADDR(EEARH), YH
    out   _SFR_IO_ADDR(EEARL), YL
    /* Set data */
    out    _SFR_IO_ADDR(EEDR), x1
    /* Set master write enable and write enable */
    sbi   _SFR_IO_ADDR(EECR), EEMWE
    sbi   _SFR_IO_ADDR(EECR), EEWE
    adiw  YL, 1
    ret

/* Coredump into EEPROM {{{2 -------------------------------------------------*/
EEPROM_COREDUMP:
    /* Using YH as tmp reg */
    push  YH
    push  ZL
    push  ZH

    /* The value of this registers are going to be loaded from the stack */
    push  ZH
    push  ZL
    push  YH

    /* Get Program Counter into Stack */
    lds   ZL, SPL
    lds   ZH, SPH
    adiw  ZL, (1 + /* Pointing to first element of stack */ \
               6 + /* Push during EEPROM_COREDUMP */        \
               2 + /* Return address of EEPROM_COREDUMP */  \
               2   /* Push during INT1_vect */              \
              )

    ld    YH, Z+
    sts   SRAM_EEPROM_PCH, YH
    ld    YH, Z+
    sts   SRAM_EEPROM_PCL, YH

    /* Setup */
    clr   ZL
    clr   ZH
    /* Wait for previous write to finish */
WAIT_PREVIOUS_WRITE:
    sbic  _SFR_IO_ADDR(EECR), EEWE
    rjmp  WAIT_PREVIOUS_WRITE
    /* Set address */
    /* Here a loop could be inserted to be able to write multiple core dumps */
    /* Using Z as read and write pointer, when reading, Z starts at zero, when
     * writing, Z starts at EEPROM_DEBUG, therefore EEPROM_DEBUG get added to Z
     * before setting EEARH,EEARL and subtracted afterwards */
    ldi   YH, lo8(EEPROM_DEBUG)
    add   ZL, YH
    ldi   YH, hi8(EEPROM_DEBUG)
    adc   ZH, YH
    out   _SFR_IO_ADDR(EEARH), ZH
    out   _SFR_IO_ADDR(EEARL), ZL
    ldi   YH, hi8(EEPROM_DEBUG)
    sub   ZH, YH
    ldi   YH, lo8(EEPROM_DEBUG)
    sbc   ZL, YH
    /* Set data
     * For YH, ZL and ZH, read from stack previous saved value */
    cpi    ZL, 29
    breq   READ_FROM_STACK
    cpi    ZL, 30
    breq   READ_FROM_STACK
    cpi    ZL, 31
    breq   READ_FROM_STACK
    /* Write SREG and Program Counter 15:0 */
    cpi    ZL, 0x5F
    brsh   READ_FROM_SRAM_WITH_DISPLACEMENT
READ_FROM_SRAM:
    ld     YH, Z+
    rjmp   WRITE_TO_EEPROM
READ_FROM_SRAM_WITH_DISPLACEMENT:
    ldd    YH, Z + (SRAM_EEPROM_COREDUMP_DISPLACEMENT - 0x5F)
    adiw   ZL, 1
    rjmp   WRITE_TO_EEPROM
READ_FROM_STACK:
    pop    YH
    adiw   ZL, 1

    /* Write to EEPROM */
WRITE_TO_EEPROM:
    out    _SFR_IO_ADDR(EEDR), YH
    /* Set master write enable and write enable */
    sbi   _SFR_IO_ADDR(EECR), EEMWE
    sbi   _SFR_IO_ADDR(EECR), EEWE

    cpi   ZL, AFTER_LAST_COREDUMP_ELEMENT
    brne  WAIT_PREVIOUS_WRITE

    pop   ZH
    pop   ZL
    pop   YH
    ret

.end
