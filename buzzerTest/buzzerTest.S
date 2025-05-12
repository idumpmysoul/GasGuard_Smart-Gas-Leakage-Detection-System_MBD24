#define __SFR_OFFSET 0x00
#include <avr/io.h>

.section .text
.global main

main:
    ; Set stack pointer
    LDI   R16, 0x08
    OUT   SPH, R16
    LDI   R16, 0xFF
    OUT   SPL, R16

    ; Set PB0 as output (buzzer pin)
    sbi DDRB, 0          ; Set PB0 as output

loop:
    ; Turn buzzer ON
    sbi PORTB, 0         ; Set PB0 high
    rcall delay

    ; Turn buzzer OFF
    cbi PORTB, 0         ; Set PB0 low
    rcall delay

    rjmp loop

; Simple delay routine
delay:
    ldi r18, 100
outer:
    ldi r19, 255
inner:
    dec r19
    brne inner
    dec r18
    brne outer
    ret
