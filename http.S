/* vim: set filetype=S foldmethod=marker: */
/* INCLUDES {{{1 */
.NOLIST
#include <avr/io.h>
#include "defs.h"
#include "eeprom_data.h"
.LIST

/* MACORS {{{1 ---------------------------------------------------------------*/
#define ASCII_ZERO 48

/* GLOBAL {{{1 ---------------------------------------------------------------*/
.global HTTP_HANDLE_PKT

/* DATA  {{{1 ----------------------------------------------------------------*/
.section .data

/* TEXT {{{1 -----------------------------------------------------------------*/
.section .text

/* HTTP handle {{{2  -----------------------------------------------------------
 * Z must be pointing to first byte of TCP payload
 * RTV_L_REG: HTTP length in bytes
 */
HTTP_HANDLE_PKT:
    ldi   YL, lo8(EEPROM_HTTP_RESPONSE)
    ldi   YH, hi8(EEPROM_HTTP_RESPONSE)
    ldi   ARG_REG1, (EEPROM_HTTP_RESPONSE_END - EEPROM_HTTP_RESPONSE)
    rcall ES_MEMCPY
    /* Set back Z to beginning of HTTP payload */
    sbiw  ZL, (EEPROM_HTTP_RESPONSE_END - EEPROM_HTTP_RH_OFFSET)

    /* RH */
    ldi   YL, lo8(SRAM_DHT11_PAYLOAD)
    ldi   YH, hi8(SRAM_DHT11_PAYLOAD)

    rcall FILL_8_DOT_8_VALUE

    /* Temperature */
    adiw  ZL, 4
    rcall FILL_8_DOT_8_VALUE

    /* Set return value to payload size */
    ldi   RTV_L_REG, (EEPROM_HTTP_RESPONSE_END - EEPROM_HTTP_RESPONSE)

    ret

/* Fill 8.8 value into xx.x placeholder on HTTP body {{{2 ----------------------
 */
FILL_8_DOT_8_VALUE:
    /* RH */
    ld    ARG_REG1, Y+
    ldi   ARG_REG2, 10
    rcall SDIV
    subi  RTV_L_REG, -ASCII_ZERO /* + '0' */
    subi  RTV_H_REG, -ASCII_ZERO /* + '0' */
    st    Z+, RTV_L_REG
    st    Z+, RTV_H_REG

    adiw  ZL, 1

    ld    ARG_REG1, Y+
    ldi   TMP_REG2, ASCII_ZERO
    ldi   TMP_REG1, 10
    mul   ARG_REG1, TMP_REG1
    add   XMULX_RTV_H_REG, TMP_REG2 /* + '0' */
    st    Z+, XMULX_RTV_H_REG
    mul   XMULX_RTV_L_REG, TMP_REG1
    add   XMULX_RTV_H_REG, TMP_REG2 /* + '0' */
    st    Z+, XMULX_RTV_H_REG

    ret

.end
