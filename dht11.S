/* vim: set filetype=S foldmethod=marker: */
.NOLIST
#include <avr/io.h>
#include "dht11.h"
#include "defs.h"
.LIST

.global DHT11_SETUP
.global DHT11_READ
.global DHT11_INT1_vect
.global TIMER2_OVF_vect

.global SRAM_DHT11_PAYLOAD

.section .data
SRAM_DHT11_PAYLOAD: .skip DHT11_PAYLOAD_LEN

.section .text

/* Tested At 1MHz */
/*******************************************************************************
 * Macros {{{
 ******************************************************************************/
/* Starting at 6, so it matches that every time we need to increment the
 * pointer, the last 3 bits of the counter are zero, and we can check that with
 * just one AND */
#define DHT11_RESPONSE_INIT                  6
#define DHT11_RESPONSE_DATA_COMING           9

#ifndef F_CPU
#   error "CPU frequency not specified, cannot calculate timer parameters"
#endif

#if   F_CPU == 1000000
#   define  WAIT_20uS          20
#   define  INTERVAL_THRESHOLD 12
#elif F_CPU == 2000000
#   define  WAIT_20uS          40
#   define  INTERVAL_THRESHOLD 24
#elif F_CPU == 4000000
#   define  WAIT_20uS          80
#   define  INTERVAL_THRESHOLD 48
#elif F_CPU == 8000000
#   define  WAIT_20uS          160
#   define  INTERVAL_THRESHOLD 96
#else
#   error "Unsupported F_CPU value"
#endif

/* Reusing registers that aren't used on this routines */
#define DHT11_COUNTER                      RETURN_VALUE
#define DHT11_TRANSMISSION_INTERVAL        ARG_REG1
/* }}} */
/*******************************************************************************
 * DHT11 setup {{{ 
 * Setup interrupt in falling edge
 * Setup interrupt port as Input with value Zero
 ******************************************************************************/
DHT11_SETUP:
    /* Set INT1 on falling edge */
    in    TMP_REG1, _SFR_IO_ADDR(MCUCR)
    sbr   TMP_REG1, (1 << ISC11)
    out   _SFR_IO_ADDR(MCUCR), TMP_REG1

    /* Set INT1 */
    /* This line must be hold high while the DHT11 is not in used. */
    cbi   _SFR_IO_ADDR(DDRD), PD3
    /* PORTD(3) is going to be zero, when we change DDRD(3) to output, then, it
     * will pull down the line, when changed back to input, it will be high
     * impedance */
    cbi   _SFR_IO_ADDR(PORTD), PD3
    ret
/* }}} */
/*******************************************************************************
 * Read data from sensor {{{
 * Data is store in SRAM_DHT11_PAYLOAD
 * Interrupt are used with falling edge
 * BEWARE: Idle is the only sleep mode that support edge interrupts
 ******************************************************************************/
DHT11_READ:
    push  ZL
    push  ZH
    push  DHT11_TRANSMISSION_INTERVAL
    push  DHT11_COUNTER

    /* Setup initial Step, used when receiving stream of data */
    ldi   DHT11_COUNTER, DHT11_RESPONSE_INIT

    /* Set clock prescaler to 1024, to we can have ms easily */
    in    TMP_REG2, _SFR_IO_ADDR(TCCR2)
    sbr   TMP_REG2, (1 << CS22)|(1 << CS21)|(1 << CS20)
    out   _SFR_IO_ADDR(TCCR2), TMP_REG2

    /* Disable INT1, so communication start doesn't trigger and interrupt */
    in    TMP_REG1, _SFR_IO_ADDR(GICR)
    cbr   TMP_REG1, (1 << INT1)
    out   _SFR_IO_ADDR(GICR), TMP_REG1

    /* Start communication by pulling down */
    sbi   _SFR_IO_ADDR(DDRD),  PD3

    /* Clear the counter */
    clr   ZL
    out   _SFR_IO_ADDR(TCNT2), ZL
    /* Pulling Down data line for at least 18ms */
DHT11_READ_WAIT_START_SIGNAL:
    in    ZL, _SFR_IO_ADDR(TCNT2)
    cpi   ZL, WAIT_20uS
    brlo  DHT11_READ_WAIT_START_SIGNAL

    /* Set clock prescaler to 8, which gives good precision to differentiate
     * between a ZERO or ONE sent by the DHT11 */
    in    TMP_REG2, _SFR_IO_ADDR(TCCR2)
    cbr   TMP_REG2, (1 << CS22)|(1 << CS20)
    sbr   TMP_REG2, (1 << CS21)
    out   _SFR_IO_ADDR(TCCR2), TMP_REG2

    /* Clear interrupt flag for INT1 before enabling interrupt, when we send the
     * start of communication, we trigger an interrupt (falling edge) */
    in    TMP_REG2, _SFR_IO_ADDR(GIFR)
    sbr   TMP_REG2, (1 << INTF1)
    out   _SFR_IO_ADDR(GIFR), TMP_REG2

    /* Set Interrupt in INT1 */
    in    TMP_REG2, _SFR_IO_ADDR(GICR)
    sbr   TMP_REG2, (1 << INT1)
    out   _SFR_IO_ADDR(GICR), TMP_REG2

    ldi   ZH, hi8(SRAM_DHT11_PAYLOAD)
    ldi   ZL, lo8(SRAM_DHT11_PAYLOAD)

    /* Set bitfield to call DHT11 handle on interrupt */
    lds   TMP_REG1, BIT_FIELD_1
    sbr   TMP_REG1, BIT_FIELD_1_INT1_DHT11
    sts   BIT_FIELD_1, TMP_REG1

    /* Now the DHT11 will take control of the data line, enable signal and wait
     * to change down */
    /* Set port as input, then with the pull-up, the line will go high */
    cbi   _SFR_IO_ADDR(DDRD), PD3

    /* 40 cycles, one for each bit, plus 2 falling edges at the beginning */
    /* TODO: add way to wakeup in case data doesn't arrive */
    ldi   TMP_REG1, 42
DHT11_TRANSMISSION_LOOP:
    sleep
    dec   TMP_REG1
    brne  DHT11_TRANSMISSION_LOOP

    /* Unset bitfield to call DHT11 handle on interrupt */
    lds   TMP_REG1, BIT_FIELD_1
    cbr   TMP_REG1, BIT_FIELD_1_INT1_DHT11
    sts   BIT_FIELD_1, TMP_REG1

    /* FIXME: MOVE TO ITS OWN PLACE */
    /* ADC for MQ135 { */
    // rcall ADC_ENABLE_N_START
    // sleep
    // rcall ADC_DISABLE
    /* ADC for MQ135 } */

    pop   DHT11_COUNTER
    pop   DHT11_TRANSMISSION_INTERVAL
    pop   ZH
    pop   ZL
    ret
/* }}} */
/*******************************************************************************
 * Handle INT1 interrupt {{{
 * Get and process data in every falling edge
 *
 * Use DHT11_TRANSMISSION_INTERVAL to hold the current counter since the last
 * interrupt
 *
 * Use Z as pointer to the memory
 ******************************************************************************/
DHT11_INT1_vect:
    /* Read counter and reset it */
    in    DHT11_TRANSMISSION_INTERVAL, _SFR_IO_ADDR(TCNT2)
    clr   TMP_REG2
    out   _SFR_IO_ADDR(TCNT2), TMP_REG2

    inc   DHT11_COUNTER
    cpi   DHT11_COUNTER, DHT11_RESPONSE_DATA_COMING
    /* Return right away for the two falling edges before data transmission */
    brmi  DHT11_INT1_vect_EXIT

DATA_IS_COMING:
    /* Load data from SRAM, shift left, decode incoming data, set LSB in case of
     * a one, save data back to SRAM */
    ld    TMP_REG2, Z
    lsl   TMP_REG2

    cpi   DHT11_TRANSMISSION_INTERVAL, INTERVAL_THRESHOLD
    brlo  DHT11_SENT_0

DHT11_SENT_1:
    sbr   TMP_REG2, 0x01
DHT11_SENT_0:
    st    Z, TMP_REG2

    /* Increment Z if we finished writing a byte */
    mov   TMP_REG2, DHT11_COUNTER
    andi  TMP_REG2, 0x07
    brne  DHT11_INT1_vect_EXIT
    adiw  ZL, 1
DHT11_INT1_vect_EXIT:
    reti
/* }}} */

#undef DHT11_COUNTER

.end
