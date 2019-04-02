/* vim: set filetype=S foldmethod=marker: */
.NOLIST
#include <avr/io.h>
#include "defs.h"
.LIST

.global EEPROM_READ_N_INC
.global EEPROM_WRITE_N_INC
.global EEPROM_COREDUMP

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
/*******************************************************************************
 * {{{
 ******************************************************************************/
EEPROM_COREDUMP:
    push  R29
    push  R30
    push  R31

    /* The value of this registers are going to be loaded from the stack */
    push  R31
    push  R30
    push  R29

    /* Get Program Counter into Stack */
    lds   ZL, SPL
    lds   ZH, SPH
    adiw  ZL, (1 + /* Pointing to first element of stack */ \
               6 + /* Push during EEPROM_COREDUMP */        \
               2 + /* Return address of EEPROM_COREDUMP */  \
               2   /* Push during INT1_vect */              \
              )
               
    ld    R29, Z+
    sts   EEPROM_PCH, R29
    ld    R29, Z+
    sts   EEPROM_PCL, R29

    /* Setup */
    clr   ZL
    clr   ZH
    /* Wait for previous write to finish */
WAIT_PREVIOUS_WRITE:
    sbic  _SFR_IO_ADDR(EECR), EEWE
    rjmp  WAIT_PREVIOUS_WRITE
    /* Set address */
    /* Here a loop could be inserted to be able to write multiple core dumps */
    ldi   R29, lo8(EEPROM_DEBUG)
    add   ZL, R29
    ldi   R29, hi8(EEPROM_DEBUG)
    adc   ZH, R29
    out   _SFR_IO_ADDR(EEARH), ZH
    out   _SFR_IO_ADDR(EEARL), ZL
    ldi   R29, hi8(EEPROM_DEBUG)
    sub   ZH, R29
    ldi   R29, lo8(EEPROM_DEBUG)
    sbc   ZL, R29
    /* Set data
     * For R29, R30 and R31, read from stack previous saved value */
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
    ld     R29, Z+
    rjmp   WRITE_TO_EEPROM
READ_FROM_SRAM_WITH_DISPLACEMENT:
    ldd    R29, Z + (EEPROM_COREDUMP_DISPLACEMENT - 0x5F)
    adiw   ZL, 1
    rjmp   WRITE_TO_EEPROM
READ_FROM_STACK:
    pop    R29
    adiw   ZL, 1

    /* Write to EEPROM */
WRITE_TO_EEPROM:
    out    _SFR_IO_ADDR(EEDR), R29
    /* Set master write enable and write enable */
    sbi   _SFR_IO_ADDR(EECR), EEMWE
    sbi   _SFR_IO_ADDR(EECR), EEWE

    cpi   ZL, 0x62
    brne  WAIT_PREVIOUS_WRITE

    pop   R31
    pop   R30
    pop   R29
    ret

