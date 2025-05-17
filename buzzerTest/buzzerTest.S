#define __SFR_OFFSET 0x00
#include "avr/io.h"

.global main
.global INT0_vect

.section .text

main:
    ; Initialize stack pointer to 0x08FF
    ldi r16, 0x08
    out SPH, r16
    ldi r16, 0xFF
    out SPL, r16

    ; Set PB0 as output (buzzer)
    sbi DDRB, 0

    ; Set PD2 as input with pull-up (button)
    cbi DDRD, 2
    sbi PORTD, 2

    ; Configure INT0 for falling edge
    ldi r16, (1 << ISC01)
    sts EICRA, r16

    ; Enable INT0 interrupt
    ldi r16, (1 << INT0)
    out EIMSK, r16

    ; Clear state register (buzzer OFF)
    clr r19

    ; Enable global interrupts
    sei

loop:
    rjmp loop

; -----------------------------------------
; INT0 ISR - Toggle buzzer state on button
; -----------------------------------------
INT0_vect:
    ; Toggle r19 (buzzer state): XOR with 1
    ldi r16, 0x01
    eor r19, r16

    ; If r19 == 1 → turn buzzer ON
    tst r19
    breq buzzer_off

buzzer_on:
    sbi PORTB, 0
    reti

buzzer_off:
    cbi PORTB, 0
    reti
