/* vim: set filetype=S foldmethod=marker: */
.NOLIST
#include <avr/io.h>
#include "defs.h"
.LIST

.global DHT11_SETUP
.global DHT11_READ
.global DHT11_INT1_vect

/* Tested At 1MHz */

/*******************************************************************************
 * Macros {{{
 ******************************************************************************/
/* Starting at 6, so it matches that every time we need to increment the
 * pointer, the last 3 bits of the counter are zero, and we can check that with
 * just one AND */
#define DHT11_RESPONSE_INIT                  6
#define DHT11_RESPONSE_SAVE_160uS            7
#define DHT11_RESPONSE_DATA_COMING           9
#define DHT11_RESPONSE_SAVE_BYTE_0          16 /* last 3 bits are 0 */
#define DHT11_RESPONSE_SAVE_BYTE_1          24 /* last 3 bits are 0 */
#define DHT11_RESPONSE_SAVE_BYTE_2          32 /* last 3 bits are 0 */
#define DHT11_RESPONSE_SAVE_BYTE_3          40 /* last 3 bits are 0 */
#define DHT11_RESPONSE_SAVE_BYTE_4          48 /* last 3 bits are 0 */

/* Reusing RETURN_VALUE as this routine doesn't return anything */
#define DHT11_COUNTER                      RETURN_VALUE
/* }}} */
/*******************************************************************************
 * DHT11 setup {{{ 
 * Setup interrupt in falling edge
 * Setup interrupt port as Input with value Zero
 ******************************************************************************/
DHT11_SETUP:
    /* Set INT1 on falling edge */
    in    TMP_REG2, _SFR_IO_ADDR(MCUCR)
    sbr   TMP_REG2, (1 << ISC11)
    out   _SFR_IO_ADDR(MCUCR), TMP_REG2

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
 * Data is store in DHT11_PAYLOAD
 * Interrupt are used with falling edge
 * BEWARE: Idle is the only sleep mode that support edge interrupts
 ******************************************************************************/
DHT11_READ:
    push  ZL
    push  ZH
    push  YL
    push  YH
    push  XL
    push  XH
    push  DHT11_COUNTER

    /* Setup initial Step, used when receiving stream of data */
    ldi   DHT11_COUNTER, DHT11_RESPONSE_INIT

    /* Set clock prescaler to 1024, to we can have ms easily */
    in    TMP_REG2, _SFR_IO_ADDR(TCCR1B)
    sbr   TMP_REG2, (1 << CS12)|(1 << CS10)
    out   _SFR_IO_ADDR(TCCR1B), TMP_REG2

    /* Start communication by pulling down */
    sbi   _SFR_IO_ADDR(DDRD),  PD3

    /* Clear the counter, high must be written first */
    clr   ZL
    out   _SFR_IO_ADDR(TCNT1H), ZL
    out   _SFR_IO_ADDR(TCNT1L), ZL
    /* Low must be read before high */
    /* Pulling Down data line for at least 18ms */
DHT11_READ_WAIT_START_SIGNAL:
    in    ZL, _SFR_IO_ADDR(TCNT1L)
    in    ZH, _SFR_IO_ADDR(TCNT1H)
    /* This may not work at other clock frequencies, should be improved, read
     * the LFuses and then set accordingly */
    cpi   ZL, 20
    brlo  DHT11_READ_WAIT_START_SIGNAL

    /* Set Clock counter back to prescaler 1 */
    in    TMP_REG2, _SFR_IO_ADDR(TCCR1B)
    cbr   TMP_REG2, (1 << CS12)
    out   _SFR_IO_ADDR(TCCR1B), TMP_REG2

    /* Now the DHT11 will take control of the data line, enable signal and wait
     * to change down */
    /* Set Interrupt in INT1, disable INT0 */
    in    TMP_REG2, _SFR_IO_ADDR(GICR)
    sbr   TMP_REG2, (1 << INT1)
    cbr   TMP_REG2, (1 << INT0)
    out   _SFR_IO_ADDR(GICR), TMP_REG2

    /* Set port as input, then with the pull-up, the line will go high */
    cbi   _SFR_IO_ADDR(DDRD), PD3

    /* Clear interrupt flag for INT1 before enabling interrupt, interrupt was
     * getting trigger before reaching sleep, don't know why FIXME? */
    in    TMP_REG2, _SFR_IO_ADDR(GIFR)
    sbr   TMP_REG2, (1 << INTF1)
    out   _SFR_IO_ADDR(GIFR), TMP_REG2

    ldi   ZH, hi8(DHT11_PAYLOAD)
    ldi   ZL, lo8(DHT11_PAYLOAD)

    /* Designed to work under nested interrupt, therefore, enable interrupt here
     * and disable later */
    sei

    /* 40 cycles, one for each bit, plus 2 falling edges at the beginning */
    /* TODO: add way to wakeup in case data doesn't arrive */
    ldi   TMP_REG1, 42
DHT11_TRANSMISSION_LOOP:
    sleep
    dec   TMP_REG1
    brne  DHT11_TRANSMISSION_LOOP

    /* FIXME: MOVE TO ITS OWN PLACE */
    /* ADC for MQ135 { */
    rcall ADC_ENABLE_N_START
    sleep
    rcall ADC_DISABLE
    /* ADC for MQ135 } */

    cli

    /* Set interrupts back */
    in    TMP_REG2, _SFR_IO_ADDR(GICR)
    cbr   TMP_REG2, (1 << INT1)
    sbr   TMP_REG2, (1 << INT0)
    out   _SFR_IO_ADDR(GICR), TMP_REG2

    pop   DHT11_COUNTER
    pop   XH
    pop   XL
    pop   YH
    pop   YL
    pop   ZH
    pop   ZL
    ret
/* }}} */
/*******************************************************************************
 * Handle INT1 interrupt {{{
 * Get and process data in every falling edge
 *
 * Use Y to hold the current counter since the last interrupt
 * Use X to hold 5/8 of the first cycle, which is 160uS
 * Use Z as pointer to the memory
 ******************************************************************************/
DHT11_INT1_vect:
    /* Read counter and reset it */
    in    YL, _SFR_IO_ADDR(TCNT1L)
    in    YH, _SFR_IO_ADDR(TCNT1H)
    clr   TMP_REG2
    out   _SFR_IO_ADDR(TCNT1H), TMP_REG2
    out   _SFR_IO_ADDR(TCNT1L), TMP_REG2

    /* Only write X before data is coming, the goal is to catch the 160uS at the
     * beginning */
    inc   DHT11_COUNTER
    cpi   DHT11_COUNTER, DHT11_RESPONSE_DATA_COMING
    brpl  DATA_IS_COMING

    /* divide Y in 5/8 */
    bst   YH, 0
    lsr   YH
    lsr   YL
    bld   YL, 7
    movw  XL, YL
    /* divide by 4 */
    bst   YH, 0
    lsr   YH
    lsr   YL
    bld   YL, 7
    bst   YH, 0
    lsr   YH
    lsr   YL
    bld   YL, 7
    /* Add 1/8 + 1/2 = 5/8 */
    add   XL, YL
    adc   XH, YH
    reti

DATA_IS_COMING:
    /* Load data from SRAM, shift left, decode incoming data, set LSB in case of
     * a one, save data back to SRAM */
    ld    TMP_REG2, Z
    lsl   TMP_REG2

    /* TODO: can I do a sub of the Lower byte followed by a sbc on the higher
     * byte and check whether is possitive, zero or negative ?
     * I guess that should produce less code */
    cp    XH, YH
    breq  DHT11_CP_L
    brlo  DHT11_SENT_1
    rjmp  DHT11_SENT_0
DHT11_CP_L:
    cp    XL, YL
    brlo  DHT11_SENT_1
    rjmp  DHT11_SENT_0

DHT11_SENT_1:
    sbr   TMP_REG2, 0x01
DHT11_SENT_0:
    st    Z, TMP_REG2

    /* Increment Z if we finished writing a byte */
    mov   TMP_REG2, DHT11_COUNTER
    andi  TMP_REG2, 0x07
    breq  DHT11_WRITE_NEXT_BYTE
    reti
DHT11_WRITE_NEXT_BYTE:
    adiw  ZL, 1
    reti
/* }}} */

#undef DHT11_COUNTER
