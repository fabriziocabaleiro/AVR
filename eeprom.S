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

/* DATA  {{{1 ----------------------------------------------------------------*/
.section .data

/* TEXT {{{1 -----------------------------------------------------------------*/
.section .text

/* Read bytes pointed by x and return them on a4 {{{2 -------------------
 * x gets incremented after every call */
EEPROM_READ_N_INC:
    /* Wait for previous write to finish */
0:  sbic  _SFR_IO_ADDR(EECR), EEWE
    rjmp  0b
    /* Set address */
    out   _SFR_IO_ADDR(EEARL), xl
    out   _SFR_IO_ADDR(EEARH), xh
    /* Set Read Enable and read */
    sbi   _SFR_IO_ADDR(EECR), EERE
    in    a4, _SFR_IO_ADDR(EEDR)
    adiw  xl, 1 /* Increment x for continuous EEPROM reading */
    ret

/* Write a1 to EEPROM pointer by z {{{2 ----------------------------------
 * z gets incremented after every call */
EEPROM_WRITE_N_INC:
    /* Wait for previous write to finish */
0:  sbic  _SFR_IO_ADDR(EECR), EEWE
    rjmp  0b
    /* Set address */
    out   _SFR_IO_ADDR(EEARL), zl
    out   _SFR_IO_ADDR(EEARH), zh
    /* Set data */
    out    _SFR_IO_ADDR(EEDR), a1
    /* Set master write enable and write enable */
    sbi   _SFR_IO_ADDR(EECR), EEMWE
    sbi   _SFR_IO_ADDR(EECR), EEWE
    adiw  zl, 1 /* Increment z for continuous EEPROM writing */
    ret

.end
