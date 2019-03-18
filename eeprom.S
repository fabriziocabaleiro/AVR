/* vim: set filetype=S foldmethod=marker: */
.NOLIST
#include <avr/io.h>
#include "defs.h"
.LIST

.global EEPROM_READ_N_INC
.global EEPROM_WRITE_N_INC

/*******************************************************************************
 * Read bytes pointed by Y and return them on RETURN_VALUE {{{
 * Y gets incremented after every call
 ******************************************************************************/
EEPROM_READ_N_INC:
    /* Wait for previous write to finish */
    sbic  _SFR_IO_ADDR(EECR), EEWE
    rjmp  EEPROM_READ_N_INC
    /* Set address */
    out   _SFR_IO_ADDR(EEARH), YH
    out   _SFR_IO_ADDR(EEARL), YL
    /* Set Read Enable and read */
    sbi   _SFR_IO_ADDR(EECR), EERE
    in    RETURN_VALUE, _SFR_IO_ADDR(EEDR)
    /* Increment Y for continuous eeprom reading */
    adiw  YL, 1
    ret
/* }}} */
    
/*******************************************************************************
 * Write ARG_REG1 to EEPROM pointer by Y {{{
 * Y gets incremented after every call
 ******************************************************************************/
EEPROM_WRITE_N_INC:
    /* Wait for previous write to finish */
    sbic  _SFR_IO_ADDR(EECR), EEWE
    rjmp  EEPROM_WRITE_N_INC
    /* Set address */
    out   _SFR_IO_ADDR(EEARH), YH
    out   _SFR_IO_ADDR(EEARL), YL
    /* Set data */
    out    _SFR_IO_ADDR(EEDR), ARG_REG1
    /* Set master write enable and write enable */
    sbi   _SFR_IO_ADDR(EECR), EEMWE
    sbi   _SFR_IO_ADDR(EECR), EEWE
    adiw  YL, 1
    ret
/* }}} */
    
