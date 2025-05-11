#define __SFR_OFFSET 0x00
#include "avr/io.h"

.global main

.section .text

main:
    ; Set stack pointer
    LDI   R16, 0x08
    OUT   SPH, R16
    LDI   R16, 0xFF
    OUT   SPL, R16

    ; Set LEDs (D5, D6, D7) and Buzzer (D8) as output
    sbi DDRD, 5
    sbi DDRD, 6
    sbi DDRD, 7
    sbi DDRB, 0

    ; Enable INT0 (button on PD2)
    cbi DDRD, 2
    sbi PORTD, 2
    ldi r16, (1 << ISC01)      ; falling edge
    sts EICRA, r16
    ldi r16, (1 << INT0)
    sts EIMSK, r16

    ; USART0 Init for 9600 baud
    ldi r16, 0x00
    sts UBRR0H, r16
    ldi r16, 103              ; UBRR0 = 103 for 9600 @ 16MHz
    sts UBRR0L, r16
    ldi r16, (1 << TXEN0)
    sts UCSR0B, r16
    ldi r16, (1 << UCSZ01) | (1 << UCSZ00)
    sts UCSR0C, r16

    ; SPI Init (PB2 = CS, PB3 = MOSI, PB5 = SCK)
    ldi r16, (1 << PB2) | (1 << PB3) | (1 << PB5)
    out DDRB, r16
    ldi r16, (1 << SPE) | (1 << MSTR)
    out SPCR, r16

    ; ADC Init (AVcc ref, ADC0)
    ldi r16, (1 << REFS0)
    sts ADMUX, r16
    ldi r16, (1 << ADEN) | (1 << ADPS2) | (1 << ADPS1) | (1 << ADPS0)
    sts ADCSRA, r16

main_loop:
    ; Blink LEDs
    sbi PORTD, 5
    rcall delay
    cbi PORTD, 5
    sbi PORTD, 6
    rcall delay
    cbi PORTD, 6
    sbi PORTD, 7
    rcall delay
    cbi PORTD, 7

    ; Buzzer on and off
    sbi PORTB, 0
    rcall delay
    cbi PORTB, 0

    ; Read ADC and print dummy char
    rcall read_adc
    ldi r16, 'C'
    rcall send_uart

    ; SPI test command to MAX7219
    ldi r16, 0x0C      ; Shutdown register
    rcall spi_send
    ldi r16, 0x01      ; Normal operation
    rcall spi_send

    rjmp main_loop

; ========== ADC Read ==========
read_adc:
    ldi r16, (1 << ADSC)
    sts ADCSRA, r16
wait_adc:
    lds r16, ADCSRA
    sbrc r16, ADSC
    rjmp wait_adc
    lds r18, ADCL
    lds r17, ADCH
    ret

; ========== UART Send ==========
send_uart:
    lds r19, UCSR0A
    sbrs r19, UDRE0
    rjmp send_uart
    sts UDR0, r16
    ret

; ========== SPI Send ==========
spi_send:
    out SPDR, r16
wait_spi:
    in r19, SPSR
    sbrs r19, SPIF
    rjmp wait_spi
    ret

; ========== Delay ==========
delay:
    ldi r20, 100
outer:
    ldi r21, 255
inner:
    dec r21
    brne inner
    dec r20
    brne outer
    ret

.global INT0_vect
INT0_vect:
    cbi PORTD, 5
    cbi PORTD, 6
    cbi PORTD, 7
    cbi PORTB, 0
    reti
