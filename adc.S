/* vim: set filetype=S foldmethod=marker: */
.NOLIST
#include <avr/io.h>
#include "defs.h"
.LIST

.global ADC_ENABLE_N_START
.global ADC_DISABLE
.global ADC_vect

/*******************************************************************************
 * ADC prescaler documentation {{{
 *******************************************************************************
   By default, the successive approximation circuitry requires an input clock
   frequency between 50kHz and 200kHz to get maximum resolution. If a lower
   resolution than 10 bits is needed, the input clock frequency to the ADC can
   be higher than 200kHz to get a higher sample rate.

  +--------+--------+--------+-----------------+
  | ADPS2  | ADPS1  | ADPS0  | Division Factor |
  +--------+--------+--------+-----------------+
  |   0    |   0    |   0    |       2         |
  |   0    |   0    |   1    |       2         |
  |   0    |   1    |   0    |       4         |
  |   0    |   1    |   1    |       8         |
  |   1    |   0    |   0    |       16        |
  |   1    |   0    |   1    |       32        |
  |   1    |   1    |   0    |       64        |
  |   1    |   1    |   1    |       128       |
  +--------+--------+--------+-----------------+

  1M /  8 = 125k, so 0 1 1
  2M / 16 = 125k, so 1 0 0
  4M / 32 = 125k, so 1 0 1
  8M / 64 = 125k, so 1 1 0
}}} */
/*******************************************************************************
 * Prescaler setup {{{
 ******************************************************************************/
#ifndef F_CPU
#   error "CPU frequency not specified, cannot calculate ADC prescaler"
#endif

#if F_CPU == 1000000
#   define ADC_PRESCALER (1 << ADPS1)|(1 << ADPS0)
#elif F_CPU == 2000000
#   define ADC_PRESCALER (1 << ADPS2)
#elif F_CPU == 4000000
#   define ADC_PRESCALER (1 << ADPS2)|(1 << ADPS0)
#elif F_CPU == 8000000
#   define ADC_PRESCALER (1 << ADPS2)|(1 << ADPS1)
#else
#   error "Unsupported F_CPU value"
#endif /* }}} */
/*******************************************************************************
 * Enable ADC and start conversion {{{
 * Also setting at the same time:
 *   Enable ADC interrupt
 *   ADC prescaler to 8 (expecting running at 1MHz)
 ******************************************************************************/
ADC_ENABLE_N_START:
    in    TMP_REG1, _SFR_IO_ADDR(ADCSRA)
    sbr   TMP_REG1, (1 << ADEN)|(1 << ADSC)|(1 << ADIE)|ADC_PRESCALER
    out   _SFR_IO_ADDR(ADCSRA), TMP_REG1
    ret
/* }}} */
/*******************************************************************************
 * Disable ADC {{{
 ******************************************************************************/
ADC_DISABLE:
    cbi   _SFR_IO_ADDR(ADCSRA), ADEN
    ret
/* }}} */
/*******************************************************************************
 * ADC interrupt routine {{{
 * Read the content of [ADCH:ADCL] and store it into SRAM
 ******************************************************************************/
ADC_vect:
    push  TMP_REG1
    in    TMP_REG1, _SFR_IO_ADDR(SREG)
    push  TMP_REG1

    in    TMP_REG1, _SFR_IO_ADDR(ADCL)
    sts   MQ135_PAYLOAD + 1, TMP_REG1
    in    TMP_REG1, _SFR_IO_ADDR(ADCH)
    sts   MQ135_PAYLOAD + 0, TMP_REG1

    pop   TMP_REG1
    out   _SFR_IO_ADDR(SREG), TMP_REG1
    pop   TMP_REG1
    reti
/* }}} */
