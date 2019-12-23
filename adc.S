/* vim: set filetype=S foldmethod=marker: */
/* INCLUDES {{{1 */
.NOLIST
#include <avr/io.h>
#include "defs.h"
#include "macros.S"
.LIST

/* ADC prescaler documentation {{{1 --------------------------------------------
 * By default, the successive approximation circuitry requires an input clock
 * frequency between 50kHz and 200kHz to get maximum resolution. If a lower
 * resolution than 10 bits is needed, the input clock frequency to the ADC can
 * be higher than 200kHz to get a higher sample rate.
 *
 * +--------+--------+--------+-----------------+
 * | ADPS2  | ADPS1  | ADPS0  | Division Factor |
 * +--------+--------+--------+-----------------+
 * |   0    |   0    |   0    |       2         |
 * |   0    |   0    |   1    |       2         |
 * |   0    |   1    |   0    |       4         |
 * |   0    |   1    |   1    |       8         |
 * |   1    |   0    |   0    |       16        |
 * |   1    |   0    |   1    |       32        |
 * |   1    |   1    |   0    |       64        |
 * |   1    |   1    |   1    |       128       |
 * +--------+--------+--------+-----------------+
 *
 * 1M /  8 = 125k, so 0 1 1
 * 2M / 16 = 125k, so 1 0 0
 * 4M / 32 = 125k, so 1 0 1
 * 8M / 64 = 125k, so 1 1 0
 */

/* MACORS {{{1 ---------------------------------------------------------------*/
#ifndef F_CPU
#   error "CPU frequency not specified, cannot calculate ADC prescaler"
#endif

#if   F_CPU == 1000000
#   define ADC_PRESCALER (1 << ADPS1)|(1 << ADPS0)
#elif F_CPU == 2000000
#   define ADC_PRESCALER (1 << ADPS2)
#elif F_CPU == 4000000
#   define ADC_PRESCALER (1 << ADPS2)|(1 << ADPS0)
#elif F_CPU == 8000000
#   define ADC_PRESCALER (1 << ADPS2)|(1 << ADPS1)
#else
#   error "Unsupported F_CPU value"
#endif

#define ADC0_DATA_LEN 2
#if MQ135_PAYLOAD_LEN != ADC0_DATA_LEN
#   error ADC0 data length != MQ135 payload length
#endif

/* GLOBAL {{{1 ---------------------------------------------------------------*/
.global ADC_ENABLE_N_START
.global ADC_vect

.global SRAM_ADC0

/* DATA  {{{1 ----------------------------------------------------------------*/
.section .data
SRAM_ADC0: .skip ADC0_DATA_LEN

/* TEXT {{{1 -----------------------------------------------------------------*/
.section .text

/* Enable ADC and start conversion {{{2 ----------------------------------------
 * Also setting at the same time:
 *   Enable ADC interrupt
 *   ADC prescaler to 8 (expecting running at 1MHz) */
ADC_ENABLE_N_START:
    in    t1, _SFR_IO_ADDR(ADCSRA)
    sbr   t1, (1 << ADEN)|(1 << ADSC)|(1 << ADIE)|(ADC_PRESCALER)
    out   _SFR_IO_ADDR(ADCSRA), t1
    ret

/* ADC interrupt routine {{{2 --------------------------------------------------
 * Read the content of [ADCH:ADCL] and store it into SRAM */
ADC_vect:
    push  t1
    in    t1, _SFR_IO_ADDR(SREG)
    push  t1

    in    t1, _SFR_IO_ADDR(ADCL)
    sts   SRAM_ADC0 + 1, t1
    in    t1, _SFR_IO_ADDR(ADCH)
    sts   SRAM_ADC0 + 0, t1

    /* Disable ADC after conversion */
    cbi   _SFR_IO_ADDR(ADCSRA), ADEN

    pop   t1
    out   _SFR_IO_ADDR(SREG), t1
    pop   t1
    reti

.end
