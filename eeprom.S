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

/* Read bytes pointed by x and return them on a4 {{{2 -------------------
 * x gets incremented after every call */
EEPROM_READ_N_INC:
    /* Wait for previous write to finish */
    sbic  _SFR_IO_ADDR(EECR), EEWE
    rjmp  EEPROM_READ_N_INC
    /* Set address */
    out   _SFR_IO_ADDR(EEARH), xh
    out   _SFR_IO_ADDR(EEARL), xl
    /* Set Read Enable and read */
    sbi   _SFR_IO_ADDR(EECR), EERE
    in    a4, _SFR_IO_ADDR(EEDR)
    /* Increment x for continuous eeprom reading */
    adiw  xl, 1
    ret

/* Write a1 to EEPROM pointer by x {{{2 ----------------------------------
 * x gets incremented after every call */
EEPROM_WRITE_N_INC:
    /* Wait for previous write to finish */
    sbic  _SFR_IO_ADDR(EECR), EEWE
    rjmp  EEPROM_WRITE_N_INC
    /* Set address */
    out   _SFR_IO_ADDR(EEARH), xh
    out   _SFR_IO_ADDR(EEARL), xl
    /* Set data */
    out    _SFR_IO_ADDR(EEDR), a1
    /* Set master write enable and write enable */
    sbi   _SFR_IO_ADDR(EECR), EEMWE
    sbi   _SFR_IO_ADDR(EECR), EEWE
    adiw  xl, 1
    ret

/* Coredump into EEPROM {{{2 -------------------------------------------------*/
EEPROM_COREDUMP:
    /* Using xh as tmp reg */
    push  xh
    push  zl
    push  zh

    /* The value of this registers are going to be loaded from the stack */
    push  zh
    push  zl
    push  xh

    /* Get Program Counter into Stack */
    lds   zl, SPL
    lds   zh, SPH
    adiw  zl, (1 + /* Pointing to first element of stack */ \
               6 + /* Push during EEPROM_COREDUMP */        \
               2 + /* Return address of EEPROM_COREDUMP */  \
               2   /* Push during INT1_vect */              \
              )

    ld    xh, z+
    sts   SRAM_EEPROM_PCH, xh
    ld    xh, z+
    sts   SRAM_EEPROM_PCL, xh

    /* Setup */
    clr   zl
    clr   zh
    /* Wait for previous write to finish */
WAIT_PREVIOUS_WRITE:
    sbic  _SFR_IO_ADDR(EECR), EEWE
    rjmp  WAIT_PREVIOUS_WRITE
    /* Set address */
    /* Here a loop could be inserted to be able to write multiple core dumps */
    /* Using z as read and write pointer, when reading, z starts at zero, when
     * writing, z starts at EEPROM_DEBUG, therefore EEPROM_DEBUG get added to z
     * before setting EEARH,EEARL and subtracted afterwards */
    ldi   xh, lo8(EEPROM_DEBUG)
    add   zl, xh
    ldi   xh, hi8(EEPROM_DEBUG)
    adc   zh, xh
    out   _SFR_IO_ADDR(EEARH), zh
    out   _SFR_IO_ADDR(EEARL), zl
    ldi   xh, hi8(EEPROM_DEBUG)
    sub   zh, xh
    ldi   xh, lo8(EEPROM_DEBUG)
    sbc   zl, xh
    /* Set data
     * For xh, zl and zh, read from stack previous saved value */
    cpi    zl, 29
    breq   READ_FROM_STACK
    cpi    zl, 30
    breq   READ_FROM_STACK
    cpi    zl, 31
    breq   READ_FROM_STACK
    /* Write SREG and Program Counter 15:0 */
    cpi    zl, 0x5F
    brsh   READ_FROM_SRAM_WITH_DISPLACEMENT
READ_FROM_SRAM:
    ld     xh, z+
    rjmp   WRITE_TO_EEPROM
READ_FROM_SRAM_WITH_DISPLACEMENT:
    ldd    xh, z + (SRAM_EEPROM_COREDUMP_DISPLACEMENT - 0x5F)
    adiw   zl, 1
    rjmp   WRITE_TO_EEPROM
READ_FROM_STACK:
    pop    xh
    adiw   zl, 1

    /* Write to EEPROM */
WRITE_TO_EEPROM:
    out    _SFR_IO_ADDR(EEDR), xh
    /* Set master write enable and write enable */
    sbi   _SFR_IO_ADDR(EECR), EEMWE
    sbi   _SFR_IO_ADDR(EECR), EEWE

    cpi   zl, AFTER_LAST_COREDUMP_ELEMENT
    brne  WAIT_PREVIOUS_WRITE

    pop   zh
    pop   zl
    pop   xh
    ret

.end
