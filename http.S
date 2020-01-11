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
 * z must be pointing to first byte of TCP payload
 * a4: output HTTP length in bytes
 */
HTTP_HANDLE_PKT:
    ldi   xl, lo8(EEPROM_HTTP_RESPONSE)
    ldi   xh, hi8(EEPROM_HTTP_RESPONSE)
    ldi   a1, (EEPROM_HTTP_RESPONSE_END - EEPROM_HTTP_RESPONSE)
    rcall E_MEMCPY
    /* Set back z to beginning of HTTP payload */
    sbiw  zl, (EEPROM_HTTP_RESPONSE_END - EEPROM_HTTP_RH_OFFSET)

    /* RH */
    ldi   xl, lo8(SRAM_DHT11_PAYLOAD)
    ldi   xh, hi8(SRAM_DHT11_PAYLOAD)

    rcall FILL_8_DOT_8_VALUE

    /* Temperature */
    adiw  zl, 4
    rcall FILL_8_DOT_8_VALUE

    /* Set return value to payload size */
    ldi   a4, (EEPROM_HTTP_RESPONSE_END - EEPROM_HTTP_RESPONSE)

    ret

/* Fill 8.8 value into xx.x placeholder on HTTP body {{{2 ----------------------
 * X points to 8.8 value
 * Z points to http payload to write to
 */
FILL_8_DOT_8_VALUE:
    /* RH */
    ld    a1, x+
    ldi   a2, 10
    rcall SDIV
    subi  a4, -ASCII_ZERO /* + '0' */
    subi  a3, -ASCII_ZERO /* + '0' */
    st    z+, a4
    st    z+, a3

    /* Skip the dot xx.x */
    adiw  zl, 1

    /* Decimal part from DHT11 ranges from 0 to 9, so just add '0' */
    ld    a1, x+
    subi  a1, -ASCII_ZERO /* + '0' */
    st    z+, a1

    ret

.end
