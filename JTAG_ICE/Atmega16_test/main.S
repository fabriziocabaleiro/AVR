/* vim: set filetype=S foldmethod=marker: */
.NOLIST
#ifndef __AVR_ATmega16A__
#   define __AVR_ATmega16A__
#endif
#include <avr/io.h>
.LIST

.global main

; Simple blink to test debugger
main:
	sbi	_SFR_IO_ADDR(DDRB), PB0 ;
	clr	r2
	clr	r3
	sbis	_SFR_IO_ADDR(PINB), PB0  ; Check if LED is on
	rjmp	1f
	cbi	_SFR_IO_ADDR(PORTB), PB0 ; Turn off LED
	rjmp	0f
1:	sbi	_SFR_IO_ADDR(PORTB), PB0 ; Turn on LED
0:	inc	r2
	brne	0b
	inc	r3
	brne	0b
	rjmp	main
