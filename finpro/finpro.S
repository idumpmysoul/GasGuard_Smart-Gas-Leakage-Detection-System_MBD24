#define __SFR_OFFSET 0x00
#include <avr/io.h>

.section .text
.global main

main:
    ; ------------------ Stack Pointer ------------------
    ldi r16, 0x08
    out SPH, r16
    ldi r16, 0xFF
    out SPL, r16

    ; ------------------ GPIO Setup ------------------
    ldi r16, (1<<5)|(1<<6)|(1<<7)   ; PD5-7 as output (LEDs)
    out DDRD, r16
    sbi DDRB, 0                     ; PB0 as output (Buzzer)

    ; SPI Pins: MOSI (PB3), SCK (PB5), CS (PB2)
    ldi r16, (1<<2)|(1<<3)|(1<<5)
    out DDRB, r16
    sbi PORTB, 2                    ; CS HIGH

    ; Button on PD2 input + pull-up
    cbi DDRD, 2
    sbi PORTD, 2

    ; ------------------ SPI Init ------------------
    ldi r16, (1<<SPE)|(1<<MSTR)|(1<<SPR0)  ; SPE + MSTR + prescaler 16
    out SPCR, r16
    ldi r16, (1<<SPI2X)             ; Double speed
    out SPSR, r16

    ; ------------------ USART Init ------------------
    ldi r16, 103                    ; 9600 baud @ 16MHz
    sts UBRR0L, r16
    clr r16
    sts UBRR0H, r16
    ldi r16, (1<<TXEN0)             ; Enable TX
    sts UCSR0B, r16
    ldi r16, (1<<UCSZ01)|(1<<UCSZ00) ; 8-bit data
    sts UCSR0C, r16

    ; ------------------ MAX7219 Init ------------------
    rcall max7219_init

    ; ------------------ Startup Sequence ------------------
    rcall blink_leds
    sbi PORTB, 0                    ; Buzzer ON
    rcall delay_500ms
    cbi PORTB, 0                    ; Buzzer OFF
    rcall display_1234
    rcall delay_500ms

main_loop:
    ; Check button (PD2)
    sbic PIND, 2
    rjmp adc_start
    ; Button pressed - special display
    rcall display_test
    rcall delay_500ms
    rjmp main_loop

adc_start:
    ; -------- ADC Init & Start Conversion --------
    ldi r16, (1<<REFS0)             ; AVcc reference
    sts ADMUX, r16
    ldi r16, (1<<ADEN)|(1<<ADSC)|(1<<ADPS2)|(1<<ADPS1)|(1<<ADPS0) ; 128 prescaler
    sts ADCSRA, r16

adc_wait:
    lds r16, ADCSRA
    sbrs r16, ADIF
    rjmp adc_wait
    ldi r16, (1<<ADIF)              ; Clear flag
    sts ADCSRA, r16

    ; Read 8-bit result
    lds r18, ADCH

    ; Transmit raw ADC value
    mov r24, r18
    rcall send_decimal

    ; Evaluate level
    cpi r18, 50
    brlo level_safe
    cpi r18, 150
    brlo level_warn

level_danger:
    sbi PORTD, 7                    ; Red LED
    cbi PORTD, 6
    cbi PORTD, 5
    sbi PORTB, 0                    ; Buzzer ON
    rjmp display

level_warn:
    sbi PORTD, 6                    ; Yellow LED
    cbi PORTD, 7
    cbi PORTD, 5
    cbi PORTB, 0                    ; Buzzer OFF
    rjmp display

level_safe:
    sbi PORTD, 5                    ; Green LED
    cbi PORTD, 6
    cbi PORTD, 7
    cbi PORTB, 0                    ; Buzzer OFF

display:
    mov r24, r18
    rcall display_number
    rcall delay_500ms
    rjmp main_loop

; ------------------ Display Test Pattern ------------------
display_test:
    ldi r24, 1
    ldi r25, 0x0F                   ; Digit 1: all segments
    rcall spi_write
    ldi r24, 2
    ldi r25, 0x0F                   ; Digit 2: all segments
    rcall spi_write
    ldi r24, 3
    ldi r25, 0x0F                   ; Digit 3: all segments
    rcall spi_write
    ldi r24, 4
    ldi r25, 0x0F                   ; Digit 4: all segments
    rcall spi_write
    ret

; ------------------ Display 1234 ------------------
display_1234:
    ldi r24, 1
    ldi r25, 1
    rcall spi_write
    ldi r24, 2
    ldi r25, 2
    rcall spi_write
    ldi r24, 3
    ldi r25, 3
    rcall spi_write
    ldi r24, 4
    ldi r25, 4
    rcall spi_write
    ret

; ------------------ MAX7219 Init ------------------
max7219_init:
    ldi r24, 0x0F                   ; Display Test = Off
    ldi r25, 0x00
    rcall spi_write
    rcall delay_10ms
    ldi r24, 0x0C                   ; Shutdown = Normal
    ldi r25, 0x01
    rcall spi_write
    rcall delay_10ms
    ldi r24, 0x09                   ; Decode Mode = Code B decode for digits
    ldi r25, 0xFF
    rcall spi_write
    rcall delay_10ms
    ldi r24, 0x0A                   ; Intensity = medium
    ldi r25, 0x08
    rcall spi_write
    rcall delay_10ms
    ldi r24, 0x0B                   ; Scan Limit = 4 digits
    ldi r25, 0x03
    rcall spi_write
    rcall delay_10ms
    ret

; ------------------ Display Number (0-255) ------------------
display_number:
    ; Convert binary to decimal digits (r24 = number 0-255)
    clr r21                         ; Digit 2 (hundreds)
    clr r22                         ; Digit 3 (tens)
    clr r23                         ; Digit 4 (ones)

    ; Hundreds
hundreds:
    cpi r24, 100
    brlo tens
    subi r24, 100
    inc r21
    rjmp hundreds

    ; Tens
tens:
    cpi r24, 10
    brlo ones
    subi r24, 10
    inc r22
    rjmp tens

ones:
    mov r23, r24                    ; Remainder is ones digit

    ; Display digits (leading zero blanking)
    ; Digit 4 (ones)
    ldi r24, 1
    mov r25, r23
    rcall spi_write
    rcall delay_10ms

    ; Digit 3 (tens)
    ldi r24, 2
    mov r25, r22
    rcall spi_write
    rcall delay_10ms

    ; Digit 2 (hundreds)
    ldi r24, 3
    mov r25, r21
    rcall spi_write
    rcall delay_10ms

    ; Digit 1 (thousands - always 0)
    ldi r24, 4
    ldi r25, 0x0F                   ; Blank digit
    rcall spi_write
    rcall delay_10ms
    ret

; ------------------ SPI WRITE (r24=addr, r25=data) ------------------
spi_write:
    cbi PORTB, 2                    ; CS LOW
    out SPDR, r24
wait1:
    in r16, SPSR
    sbrs r16, SPIF
    rjmp wait1
    out SPDR, r25
wait2:
    in r16, SPSR
    sbrs r16, SPIF
    rjmp wait2
    sbi PORTB, 2                    ; CS HIGH
    ret

; ------------------ USART TX Byte ------------------
usart_tx:
wait_udre:
    lds r16, UCSR0A
    sbrs r16, UDRE0
    rjmp wait_udre
    sts UDR0, r24
    ret

; ------------------ Send ADC Value as Decimal ------------------
send_decimal:
    push r18
    push r19
    push r20
    push r21
    push r22
    push r23

    ; r24 contains the ADC value (0-255)
    clr r21                         ; Hundreds
    clr r22                         ; Tens
    clr r23                         ; Ones

    ; Hundreds
hundreds_tx:
    cpi r24, 100
    brlo tens_tx
    subi r24, 100
    inc r21
    rjmp hundreds_tx

    ; Tens
tens_tx:
    cpi r24, 10
    brlo ones_tx
    subi r24, 10
    inc r22
    rjmp tens_tx

ones_tx:
    mov r23, r24                    ; Remainder is ones digit

    ; Send digits
    ldi r24, '0'
    add r24, r21
    rcall usart_tx
    ldi r24, '0'
    add r24, r22
    rcall usart_tx
    ldi r24, '0'
    add r24, r23
    rcall usart_tx
    ldi r24, 10                     ; newline
    rcall usart_tx

    pop r23
    pop r22
    pop r21
    pop r20
    pop r19
    pop r18
    ret

; ------------------ Delay Functions ------------------
delay_10ms:
    ldi r16, 104
outer_10ms:
    ldi r17, 255
inner_10ms:
    dec r17
    brne inner_10ms
    dec r16
    brne outer_10ms
    ret

delay_500ms:
    ldi r16, 50
outer_500ms:
    rcall delay_10ms
    dec r16
    brne outer_500ms
    ret

; ------------------ LED Blink Sequence ------------------
blink_leds:
    sbi PORTD, 5
    rcall delay_500ms
    cbi PORTD, 5
    sbi PORTD, 6
    rcall delay_500ms
    cbi PORTD, 6
    sbi PORTD, 7
    rcall delay_500ms
    cbi PORTD, 7
    ret