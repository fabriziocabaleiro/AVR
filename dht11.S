; vim: set filetype=S:
#ifndef __DHT11_S__
#define __DHT11_S__
#include "defs.h"

/* Tested At 1MHz */

/*******************************************************************************
 * Macros
 ******************************************************************************/
#define DHT11_RESPONSE_INIT                          0
#define DHT11_RESPONSE_SAVE_160uS                    1
#define DHT11_RESPONSE_DATA_COMING                   3
#define DHT11_RESPONSE_SAVE_BYTE_0                  10
#define DHT11_RESPONSE_SAVE_BYTE_1                  18
#define DHT11_RESPONSE_SAVE_BYTE_2                  26
#define DHT11_RESPONSE_SAVE_BYTE_3                  34
#define DHT11_RESPONSE_SAVE_BYTE_4                  42

/*******************************************************************************
 * Setup interrupt in falling edge
 * Setup interrupt port as Input with value Zero
 ******************************************************************************/
DHT11_SETUP:
    /* Set INT1 on falling edge */
    in    TMP1, _SFR_IO_ADDR(MCUCR)
    sbr   TMP1, (1 << ISC11)
    out   _SFR_IO_ADDR(MCUCR), TMP1

    /* Set INT1 */
    /* This line must be hold high while the DHT11 is not in used. */
    cbi   _SFR_IO_ADDR(DDRD), PD3
    /* PORTD(3) is going to be zero, when we change DDRD(3) to output, then, it
     * will pull down the line, when changed back to input, it will be high
     * impedance */
    cbi   _SFR_IO_ADDR(PORTD), PD3
    ret

/*******************************************************************************
 * Read data from sensor
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
    push  TMP1

    /* Setup initial Step, used when receiving stream of data */
    ldi   TMP1, DHT11_RESPONSE_INIT
    sts   DHT11_STEP, TMP1

    /* Set clock prescaler to 1024, to we can have ms easily */
    in    TMP1, _SFR_IO_ADDR(TCCR1B)
    sbr   TMP1, (1 << CS12)|(1 << CS10)
    out   _SFR_IO_ADDR(TCCR1B), TMP1

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
    in    TMP1, _SFR_IO_ADDR(TCCR1B)
    cbr   TMP1, (1 << CS12)
    out   _SFR_IO_ADDR(TCCR1B), TMP1

    /* Now the DHT11 will take control of the data line, enable signal and wait
     * to change down */
    /* Set Interrupt in INT1, disable INT0 */
    in    TMP1, _SFR_IO_ADDR(GICR)
    sbr   TMP1, (1 << INT1)
    cbr   TMP1, (1 << INT0)
    out   _SFR_IO_ADDR(GICR), TMP1

    /* Set port as input, then with the pull-up, the line will go high */
    cbi   _SFR_IO_ADDR(DDRD), PD3

    /* Clear interrupt flag for INT1 before enabling interrupt, interrupt was
     * getting trigger before reaching sleep, don't know why FIXME? */
    in    TMP1, _SFR_IO_ADDR(GIFR)
    sbr   TMP1, (1 << INTF1)
    out   _SFR_IO_ADDR(GIFR), TMP1

    ldi   ZH, hi8(DHT11_PAYLOAD)
    ldi   ZL, lo8(DHT11_PAYLOAD)

    /* Designed to work under nested interrupt, therefore, enable interrupt here
     * and disable later */
    sei

    /* 40 cycles, one for each bit, plus 2 falling edges at the beginning */
    ldi   MAIN_COUNTER_REG, 42
DHT11_TRANSMISSION_LOOP:
    sleep
    dec   MAIN_COUNTER_REG
    brne  DHT11_TRANSMISSION_LOOP

    cli

    /* Set interrupts back */
    in    TMP1, _SFR_IO_ADDR(GICR)
    cbr   TMP1, (1 << INT1)
    sbr   TMP1, (1 << INT0)
    out   _SFR_IO_ADDR(GICR), TMP1

    pop   TMP1
    pop   XH
    pop   XL
    pop   YH
    pop   YL
    pop   ZH
    pop   ZL
    ret

/*******************************************************************************
 * Get and process data in every falling edge
 *
 * Use Y to hold the current counter since the last interrupt
 * Use X to hold 5/8 of the first cycle, which is 160uS
 * Use Z as pointer to the memory
 *
 *
 *
 *
 ******************************************************************************/
INT1_vect:
    /* Read counter and reset it */
    in    YL, _SFR_IO_ADDR(TCNT1L)
    in    YH, _SFR_IO_ADDR(TCNT1H)
    clr   TMP1
    out   _SFR_IO_ADDR(TCNT1H), TMP1
    out   _SFR_IO_ADDR(TCNT1L), TMP1

    /* Only write X before data is coming, the goal is to catch the 160uS at the
     * beginning */
    lds   TMP1, DHT11_STEP
    inc   TMP1
    sts   DHT11_STEP, TMP1
    cpi   TMP1, DHT11_RESPONSE_DATA_COMING
    brpl  DHT11_DATA_IS_COMING

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

DHT11_DATA_IS_COMING:
    cp    XH, YH
    breq  DHT11_CP_L
    brlo  DHT11_SENT_1
    rjmp  DHT11_SENT_0
DHT11_CP_L:
    cp    XL, YL
    brlo  DHT11_SENT_1
    rjmp  DHT11_SENT_0

DHT11_SENT_0:
    clt
    rjmp  DHT11_STORE_BIT_N_SHIFT
DHT11_SENT_1:
    set
DHT11_STORE_BIT_N_SHIFT:
    ld    TMP1, Z
    lsl   TMP1
    bld   TMP1, 0
    st    Z, TMP1

    /* Increment Z if we finished writing a byte */
    lds   TMP1, DHT11_STEP
    cpi   TMP1, DHT11_RESPONSE_SAVE_BYTE_0
    breq  DHT11_WRITE_NEXT_BYTE
    cpi   TMP1, DHT11_RESPONSE_SAVE_BYTE_1
    breq  DHT11_WRITE_NEXT_BYTE
    cpi   TMP1, DHT11_RESPONSE_SAVE_BYTE_2
    breq  DHT11_WRITE_NEXT_BYTE
    cpi   TMP1, DHT11_RESPONSE_SAVE_BYTE_3
    breq  DHT11_WRITE_NEXT_BYTE
    cpi   TMP1, DHT11_RESPONSE_SAVE_BYTE_4
    breq  DHT11_WRITE_NEXT_BYTE
    reti
DHT11_WRITE_NEXT_BYTE:
    adiw  ZL, 1
    reti

#endif
