#define __SFR_OFFSET 0x00
#include <avr/io.h>

.section .vectors, "a", @progbits
    rjmp main                 ; Reset vector
    rjmp INT0_vect            ; External Interrupt Request 0
    .org 0x001E
    rjmp TIMER1_COMPA_vect    ; Timer1 Compare A interrupt

.section .text
.global main
.global INT0_vect
.global TIMER1_COMPA_vect

main:
    ; Set stack pointer
    LDI   R16, 0x08
    OUT   SPH, R16
    LDI   R16, 0xFF
    OUT   SPL, R16

    ; Initialize peripherals
    rcall init_io
    rcall init_adc
    rcall init_uart
    rcall init_spi
    rcall init_max7219
    rcall init_timer
    rcall init_interrupts

    sei
main_loop:
    rjmp main_loop

; ---------------------------
; Initialization Routines
; ---------------------------
init_io:
    sbi DDRD, 5    ; Green LED
    sbi DDRD, 6    ; Yellow LED
    sbi DDRD, 7    ; Red LED
    sbi DDRB, 0    ; Buzzer
    ret

init_adc:
    ldi r16, (1 << REFS0)
    sts ADMUX, r16
    ldi r16, (1 << ADEN) | (1 << ADPS2) | (1 << ADPS1) | (1 << ADPS0)
    sts ADCSRA, r16
    ret

init_uart:
    ldi r16, 103
    ldi r17, 0x00
    sts UBRR0H, r17
    sts UBRR0L, r16
    ldi r16, (1 << TXEN0)
    sts UCSR0B, r16
    ldi r16, (1 << UCSZ01) | (1 << UCSZ00)
    sts UCSR0C, r16
    ret

init_spi:
    ldi r16, (1 << PB2) | (1 << PB3) | (1 << PB5)
    out DDRB, r16
    ldi r16, (1 << SPE) | (1 << MSTR)
    out SPCR, r16
    ret

init_max7219:
    ldi r16, 0x09
    ldi r17, 0x0F
    rcall spi_write
    ldi r16, 0x0B
    ldi r17, 0x03
    rcall spi_write
    ldi r16, 0x0C
    ldi r17, 0x01
    rcall spi_write
    ldi r16, 0x0A
    ldi r17, 0x08
    rcall spi_write
    ret

init_timer:
    ldi r16, (1 << WGM12)             ; Set CTC mode (WGM12 bit)
    sts TCCR1B, r16                    ; Write to TCCR1B to configure the mode

    ldi r16, 0x68                      ; Load low byte of 15624 (0x3D68) into r16
    sts OCR1AL, r16                    ; Write low byte to OCR1AL
    ldi r16, 0x3D                      ; Load high byte of 15624 (0x3D68) into r16
    sts OCR1AH, r16                    ; Write high byte to OCR1AH

    ldi r16, (1 << OCIE1A)             ; Enable Timer1 compare interrupt A
    sts TIMSK1, r16                    ; Write to TIMSK1 to enable interrupt

    ldi r16, (1 << CS12) | (1 << CS10) ; Set prescaler (prescaler = 1024)
    sts TCCR1B, r16                    ; Write to TCCR1B to start the timer with the prescaler

    ret                                 ; Return from function

init_interrupts:
    cbi DDRD, 2
    sbi PORTD, 2
    ldi r16, (1 << ISC01)
    sts EICRA, r16
    ldi r16, (1 << INT0)
    sts EIMSK, r16
    ret

; ---------------------------
; SPI Write
; ---------------------------
spi_write:
    out SPDR, r16
wait_spi_1:
    in r18, SPSR
    sbrs r18, SPIF
    rjmp wait_spi_1
    out SPDR, r17
wait_spi_2:
    in r18, SPSR
    sbrs r18, SPIF
    rjmp wait_spi_2
    ret

; ---------------------------
; UART Send
; ---------------------------
send_uart:
    lds r19, UCSR0A
    sbrs r19, UDRE0
    rjmp send_uart
    sts UDR0, r16
    ret

; ---------------------------
; BCD Display Routine
; ---------------------------
display_value:
    ; r17:r18 = 10-bit ADC value → r20 = approx ppm
    mov r20, r17       ; crude ppm from high byte
    ldi r21, 4         ; 4 digits
    clr r22            ; digit index
next_digit:
    mov r23, r20
    andi r23, 0x0F     ; get lowest nibble
    mov r16, r22       ; digit address (0 = rightmost)
    mov r17, r23       ; digit value
    rcall spi_write
    lsr r20
    lsr r20
    lsr r20
    lsr r20
    inc r22
    dec r21
    brne next_digit
    ret

; ---------------------------
; Interrupt Vectors
; ---------------------------
INT0_vect:
    cbi PORTD, 5
    cbi PORTD, 6
    cbi PORTD, 7
    cbi PORTB, 0
    reti

TIMER1_COMPA_vect:
    ; Start ADC conversion
    ldi r16, (1 << ADSC)
    sts ADCSRA, r16
wait_adc:
    lds r16, ADCSRA
    sbrs r16, ADSC
    rjmp adc_done
    rjmp wait_adc
adc_done:
    lds r18, ADCL
    lds r17, ADCH

    ; Threshold logic
    cbi PORTD, 5
    cbi PORTD, 6
    cbi PORTD, 7
    cpi r17, 50
    brlo safe
    cpi r17, 100
    brlo warning

danger:
    sbi PORTD, 7        ; Red
    sbi PORTB, 0        ; Buzzer
    rjmp update_display

warning:
    sbi PORTD, 6        ; Yellow
    sbi PORTB, 0        ; Buzzer
    rjmp update_display

safe:
    sbi PORTD, 5        ; Green
    cbi PORTB, 0        ; Buzzer

update_display:
    rcall display_value
    mov r16, r17
    rcall send_uart
    ret
    reti
