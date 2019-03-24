/* vim: set filetype=S foldmethod=marker: */
.NOLIST
#include <avr/io.h>
#include "defs.h"
.LIST

.global EEPROM_READ_N_INC
.global EEPROM_WRITE_N_INC
.global EEPROM_DEBUG_INIT
.global EEPROM_DEBUG_WRITE

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
 * EEPROM debug init {{{
 ******************************************************************************/
EEPROM_DEBUG_INIT:
    /* Clear all the debug register bit fields */
    ldi   TMP_REG1, 0
    sts   EEPROM_DEBUG_R0_7,   TMP_REG1
    sts   EEPROM_DEBUG_R8_15,  TMP_REG1
    ldi   TMP_REG1, 7
    sts   EEPROM_DEBUG_R16_23, TMP_REG1
    sts   EEPROM_DEBUG_R24_31, TMP_REG1

    /* Set Y debug pointer to the beginning of the debug space */
    ldi   TMP_REG1, hi8(EEPROM_DEBUG)
    sts   EEPROM_DEBUG_YH, TMP_REG1
    ldi   TMP_REG1, lo8(EEPROM_DEBUG)
    sts   EEPROM_DEBUG_YL, TMP_REG1
    
    ret
/* }}} */
/*******************************************************************************
 * Write ARG_REG1 to EEPROM pointer by Y {{{
 * Y gets incremented after every call
 ******************************************************************************/
EEPROM_DEBUG_WRITE:
    push  YL
    push  YH
    push  ARG_REG1
    push  R31
    push  ARG_REG1

    lds   YL, EEPROM_DEBUG_YL
    lds   YH, EEPROM_DEBUG_YH

    ldi   ARG_REG1, 0xFF
    rcall EEPROM_WRITE_N_INC

    lds   R31, EEPROM_DEBUG_R0_7

    sbrs  R31, 0
    rjmp  R31_1
    mov   ARG_REG1, R0
    rcall EEPROM_WRITE_N_INC
R31_1:
    sbrs  R31, 1
    rjmp  R31_2
    mov   ARG_REG1, R1
    rcall EEPROM_WRITE_N_INC
R31_2:
    sbrs  R31, 2
    rjmp  R31_3
    mov   ARG_REG1, R2
    rcall EEPROM_WRITE_N_INC
R31_3:
    sbrs  R31, 3
    rjmp  R31_4
    mov   ARG_REG1, R3
    rcall EEPROM_WRITE_N_INC
R31_4:
    sbrs  R31, 4
    rjmp  R31_5
    mov   ARG_REG1, R4
    rcall EEPROM_WRITE_N_INC
R31_5:
    sbrs  R31, 5
    rjmp  R31_6
    mov   ARG_REG1, R5
    rcall EEPROM_WRITE_N_INC
R31_6:
    sbrs  R31, 6
    rjmp  R31_7
    mov   ARG_REG1, R6
    rcall EEPROM_WRITE_N_INC
R31_7:
    sbrs  R31, 7
    rjmp  R31_8
    mov   ARG_REG1, R7
    rcall EEPROM_WRITE_N_INC
R31_8:

    lds   R31, EEPROM_DEBUG_R8_15

    sbrs  R31, 0
    rjmp  R31_9
    mov   ARG_REG1, R8
    rcall EEPROM_WRITE_N_INC
R31_9:
    sbrs  R31, 1
    rjmp  R31_10
    mov   ARG_REG1, R9
    rcall EEPROM_WRITE_N_INC
R31_10:
    sbrs  R31, 2
    rjmp  R31_11
    mov   ARG_REG1, R10
    rcall EEPROM_WRITE_N_INC
R31_11:
    sbrs  R31, 3
    rjmp  R31_12
    mov   ARG_REG1, R11
    rcall EEPROM_WRITE_N_INC
R31_12:
    sbrs  R31, 4
    rjmp  R31_13
    mov   ARG_REG1, R12
    rcall EEPROM_WRITE_N_INC
R31_13:
    sbrs  R31, 5
    rjmp  R31_14
    mov   ARG_REG1, R13
    rcall EEPROM_WRITE_N_INC
R31_14:
    sbrs  R31, 6
    rjmp  R31_15
    mov   ARG_REG1, R14
    rcall EEPROM_WRITE_N_INC
R31_15:
    sbrs  R31, 7
    rjmp  R31_16
    mov   ARG_REG1, R15
    rcall EEPROM_WRITE_N_INC
R31_16:

    lds   R31, EEPROM_DEBUG_R16_23

    sbrs  R31, 0
    rjmp  R31_17
    mov   ARG_REG1, TMP_REG1 // R16
    rcall EEPROM_WRITE_N_INC
R31_17:
    sbrs  R31, 1
    rjmp  R31_18
    mov   ARG_REG1, TMP_REG2 // R17
    rcall EEPROM_WRITE_N_INC
R31_18:
    sbrs  R31, 2
    rjmp  R31_19
    mov   ARG_REG1, TMP_REG3 // R18
    rcall EEPROM_WRITE_N_INC
R31_19:
    sbrs  R31, 3
    rjmp  R31_20
    // mov   ARG_REG1, R19
    pop   ARG_REG1
    rcall EEPROM_WRITE_N_INC
R31_20:
    sbrs  R31, 4
    rjmp  R31_21
    mov   ARG_REG1, ARG_REG2 // R20
    rcall EEPROM_WRITE_N_INC
R31_21:
    sbrs  R31, 5
    rjmp  R31_22
    mov   ARG_REG1, RETURN_VALUE // R21
    rcall EEPROM_WRITE_N_INC
R31_22:
    sbrs  R31, 6
    rjmp  R31_23
    mov   ARG_REG1, COUNTER_REG // R22
    rcall EEPROM_WRITE_N_INC
R31_23:
    sbrs  R31, 7
    rjmp  R31_24
    mov   ARG_REG1, R23
    rcall EEPROM_WRITE_N_INC
R31_24:

    lds   R31, EEPROM_DEBUG_R24_31

    sbrs  R31, 0
    rjmp  R31_25
    mov   ARG_REG1, R24
    rcall EEPROM_WRITE_N_INC
R31_25:
    sbrs  R31, 1
    rjmp  R31_26
    mov   ARG_REG1, R25
    rcall EEPROM_WRITE_N_INC
R31_26:
    sbrs  R31, 2
    rjmp  R31_27
    mov   ARG_REG1, R26
    rcall EEPROM_WRITE_N_INC
R31_27:
    sbrs  R31, 3
    rjmp  R31_28
    mov   ARG_REG1, R27
    rcall EEPROM_WRITE_N_INC
R31_28:
    sbrs  R31, 4
    rjmp  R31_29
    mov   ARG_REG1, R28
    rcall EEPROM_WRITE_N_INC
R31_29:
    sbrs  R31, 5
    rjmp  R31_30
    mov   ARG_REG1, R29
    rcall EEPROM_WRITE_N_INC
R31_30:
    sbrs  R31, 6
    rjmp  R31_31
    mov   ARG_REG1, R30
    rcall EEPROM_WRITE_N_INC
R31_31:
    sbrs  R31, 7
    rjmp  R31_32
    // mov   ARG_REG1, R31
    pop   R31
    rcall EEPROM_WRITE_N_INC
R31_32:

    sts   EEPROM_DEBUG_YL, YL
    sts   EEPROM_DEBUG_YH, YH

    pop   ARG_REG1
    pop   YH
    pop   YL
    ret
