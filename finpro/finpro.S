#define __SFR_OFFSET 0x00
#include <avr/io.h>

; Pin assignments for Arduino Uno:
; LEDs: PD5 (Green), PD6 (Yellow), PD7 (Red) [Digital pins 5,6,7]
; Buzzer: PB0 (Digital pin 8)
; Button: PD2 (Digital pin 2)
; MAX7219: MOSI (PB3/11), SCK (PB5/13), CS (PB2/10)
; MQ-7 sensor: ADC0 (PC0/A0)

.section .text
.global main
.global INT0_vect

; Register usage:
; r19 - Buzzer state flag (0 = OFF, 1 = ON)
; r20 - Temporary counter/tracking
; r21-r23 - Temporary calculations
; r24-r25 - Function parameters
; r16-r18 - General purpose/temporary

main:
    ; ------------------ Stack Initialization ------------------
    ldi r16, 0x08        ; High byte of RAMEND
    out SPH, r16
    ldi r16, 0xFF        ; Low byte of RAMEND
    out SPL, r16

    ; ------------------ I/O Setup ------------------
    rcall init_io        ; Setup I/O ports

    ; ------------------ Startup Sequence ------------------
    rcall uart_init      ; Initialize UART first to send messages

    ; Send "PREPARING" message
    ldi ZL, lo8(msg_prep)
    ldi ZH, hi8(msg_prep)
    rcall uart_send_string
    
    ; Buzzer test
    sbi PORTB, 0         ; Buzzer ON
    rcall delay_500ms
    cbi PORTB, 0         ; Buzzer OFF
    
    ; LED test
    rcall blink_leds
    
    ; MAX7219 initialization
    rcall max7219_init
    rcall display_1234   ; Show test pattern 1234
    rcall delay_500ms
    
    ; Finish other initializations
    rcall adc_init
    rcall int0_init      ; Initialize external interrupt
    
    ; Clear buzzer state
    clr r19              ; r19 = 0 (buzzer not latched)
    
    ; Enable global interrupts
    sei

; Main program loop
main_loop:
    ; Start ADC conversion
    lds r16, ADCSRA
    ori r16, (1<<ADSC)
    sts ADCSRA, r16
    
    ; Wait for conversion to complete
adc_wait:
    lds r16, ADCSRA
    sbrc r16, ADSC
    rjmp adc_wait
    
    ; Read ADC result (8-bit precision is enough)
    lds r20, ADCL        ; Read low byte first (required)
    lds r21, ADCH        ; Then high byte
    
    ; Display ADC value on MAX7219
    mov r24, r21
    rcall display_adc_value
    
    ; Check thresholds and set indicators
    cpi r21, 200
    brsh danger_level
    cpi r21, 100
    brsh warning_level
    
safe_level:
    sbi PORTD, 5         ; Green LED ON
    cbi PORTD, 6         ; Yellow LED OFF
    cbi PORTD, 7         ; Red LED OFF
    cbi PORTB, 0         ; Buzzer OFF
    clr r19              ; Clear buzzer latch
    
    ; Send UART message
    ldi ZL, lo8(msg_safe)
    ldi ZH, hi8(msg_safe)
    rcall uart_send_string
    mov r24, r21
    rcall uart_send_decimal
    rcall uart_send_newline
    
    rjmp main_delay
    
warning_level:
    cbi PORTD, 5         ; Green LED OFF
    sbi PORTD, 6         ; Yellow LED ON
    cbi PORTD, 7         ; Red LED OFF
    cbi PORTB, 0         ; Buzzer OFF
    clr r19              ; Clear buzzer latch
    
    ; Send UART message
    ldi ZL, lo8(msg_warning)
    ldi ZH, hi8(msg_warning)
    rcall uart_send_string
    mov r24, r21
    rcall uart_send_decimal
    rcall uart_send_newline
    
    rjmp main_delay
    
danger_level:
    cbi PORTD, 5         ; Green LED OFF
    cbi PORTD, 6         ; Yellow LED OFF
    sbi PORTD, 7         ; Red LED ON
    
    ; Only turn on buzzer if not already latched
    tst r19
    brne skip_buzzer     ; If r19 ≠ 0, skip turning on buzzer
    sbi PORTB, 0         ; Buzzer ON
    ldi r19, 1           ; Set buzzer latch flag
skip_buzzer:
    
    ; Send UART message
    ldi ZL, lo8(msg_danger)
    ldi ZH, hi8(msg_danger)
    rcall uart_send_string
    mov r24, r21
    rcall uart_send_decimal
    rcall uart_send_newline
    
main_delay:
    rcall delay_500ms    ; Delay before next reading
    rjmp main_loop

; Reset button pressed (non-interrupt handling)
; [This function is not used since we're using INT0 interrupt]
reset_pressed:
    ret

; Interrupt handler for external interrupt INT0 (reset button)
INT0_vect:
    push r16             ; Save register
    in r16, SREG
    push r16             ; Save status register
    
    ; Simple debounce
    rcall delay_10ms
    
    ; Check if button is still pressed
    sbic PIND, 2
    rjmp int0_done       ; Button no longer pressed - exit interrupt
    
    ; Reset buzzer state
    clr r19              ; Clear buzzer latch
    cbi PORTB, 0         ; Buzzer OFF
    
    ; Reset display to 1234
    rcall display_1234
    
    ; Send reset message
    ldi ZL, lo8(msg_reset)
    ldi ZH, hi8(msg_reset)
    rcall uart_send_string
    rcall uart_send_newline
    
int0_done:
    ; Restore registers
    pop r16
    out SREG, r16
    pop r16
    reti

; ------------------ Initialization Functions ------------------

init_io:
    ; Setup LED outputs
    sbi DDRD, 5          ; Green LED output
    sbi DDRD, 6          ; Yellow LED output
    sbi DDRD, 7          ; Red LED output
    
    ; Setup buzzer output
    sbi DDRB, 0          ; Buzzer output
    
    ; Setup button input with pull-up
    cbi DDRD, 2          ; Reset button input
    sbi PORTD, 2         ; Enable pull-up
    
    ; Setup SPI pins for MAX7219
    sbi DDRB, 2          ; CS as output
    sbi DDRB, 3          ; MOSI as output
    sbi DDRB, 5          ; SCK as output
    sbi PORTB, 2         ; CS high (inactive)
    ret

uart_init:
    ; 9600 baud @ 16MHz (Arduino Uno)
    ldi r16, 0x00
    sts UBRR0H, r16
    ldi r16, 103         ; 16MHz / (16 * 9600) - 1 = 103.166... = 103
    sts UBRR0L, r16
    
    ; Enable transmitter
    ldi r16, (1<<TXEN0)
    sts UCSR0B, r16
    
    ; 8 data bits, 1 stop bit, no parity (8N1)
    ldi r16, (1<<UCSZ01)|(1<<UCSZ00)
    sts UCSR0C, r16
    ret

; ------------------ ADC Init and Reading ------------------
adc_init:
    ; Setup ADC with ADC0 (PC0) input and proper reference
    ldi r16, (1<<REFS0)  ; AVCC reference
    sts ADMUX, r16       ; ADC0 channel (default)
    
    ; Enable ADC, set prescaler to 128 (16MHz/128 = 125kHz)
    ldi r16, (1<<ADEN)|(1<<ADPS2)|(1<<ADPS1)|(1<<ADPS0)
    sts ADCSRA, r16
    
    ; Dummy reading to initialize ADC
    ldi r16, (1<<ADEN)|(1<<ADSC)|(1<<ADPS2)|(1<<ADPS1)|(1<<ADPS0)
    sts ADCSRA, r16
adc_init_wait:
    lds r16, ADCSRA
    sbrc r16, ADSC
    rjmp adc_init_wait
    ; Discard first result
    lds r16, ADCL        ; Must read ADCL first
    lds r16, ADCH
    ret

int0_init:
    ; Setup external interrupt INT0
    ldi r16, (1<<ISC01)  ; Falling edge
    sts EICRA, r16
    
    ; Enable INT0
    ldi r16, (1<<INT0)
    out EIMSK, r16
    ret

max7219_init:
    ; Initialize SPI for MAX7219
    ldi r16, (1<<SPE)|(1<<MSTR)|(1<<SPR0)
    out SPCR, r16
    
    ; Setup MAX7219 registers
    ldi r24, 0x09        ; Decode mode
    ldi r25, 0xFF        ; Code B for all digits
    rcall spi_write
    
    ldi r24, 0x0A        ; Intensity
    ldi r25, 0x08        ; Medium brightness (0-F)
    rcall spi_write
    
    ldi r24, 0x0B        ; Scan limit
    ldi r25, 0x03        ; Display 4 digits (0-3)
    rcall spi_write
    
    ldi r24, 0x0C        ; Shutdown
    ldi r25, 0x01        ; Normal operation
    rcall spi_write
    
    ldi r24, 0x0F        ; Display test
    ldi r25, 0x00        ; Normal operation
    rcall spi_write
    ret

; ------------------ Display Functions ------------------

; Display 1234 on the MAX7219
display_1234:
    ldi r24, 1           ; Digit 1 (rightmost)
    ldi r25, 4
    rcall spi_write
    
    ldi r24, 2           ; Digit 2
    ldi r25, 3
    rcall spi_write
    
    ldi r24, 3           ; Digit 3
    ldi r25, 2
    rcall spi_write
    
    ldi r24, 4           ; Digit 4 (leftmost)
    ldi r25, 1
    rcall spi_write
    ret

; Display ADC value (r24) as decimal on MAX7219
display_adc_value:
    ; Convert value to BCD
    clr r22              ; Hundreds
    clr r23              ; Tens
    clr r25              ; Ones
    
    ; Extract hundreds
hundreds_div:
    cpi r24, 100
    brlo tens_div
    subi r24, 100
    inc r22
    rjmp hundreds_div
    
    ; Extract tens
tens_div:
    cpi r24, 10
    brlo ones_div
    subi r24, 10
    inc r23
    rjmp tens_div
    
    ; Extract ones
ones_div:
    mov r25, r24
    
    ; Display on MAX7219
    ldi r24, 1           ; Digit 1 (ones)
    rcall spi_write
    
    ldi r24, 2           ; Digit 2 (tens)
    mov r25, r23
    rcall spi_write
    
    ldi r24, 3           ; Digit 3 (hundreds)
    mov r25, r22
    rcall spi_write
    
    ldi r24, 4           ; Digit 4 (blank/zero)
    ldi r25, 0x0F        ; Blank
    rcall spi_write
    ret

; ------------------ UART Functions ------------------

; Send string from program memory (Z-pointer)
uart_send_string:
    lpm r16, Z+          ; Load byte from program memory into r16
    cpi r16, 0           ; Check for null terminator
    breq uart_send_done
    rcall uart_send_byte ; Send the byte
    rjmp uart_send_string
uart_send_done:
    ret

; Send decimal value via UART (0-255)
uart_send_decimal:
    ; Save registers
    push r22
    push r23
    push r25
    
    ; Convert r24 to BCD
    clr r22              ; Hundreds
    clr r23              ; Tens
    clr r25              ; Ones
    
    ; Extract hundreds
hundreds_uart:
    cpi r24, 100
    brlo tens_uart
    subi r24, 100
    inc r22
    rjmp hundreds_uart
    
    ; Extract tens
tens_uart:
    cpi r24, 10
    brlo ones_uart
    subi r24, 10
    inc r23
    rjmp tens_uart
    
    ; Extract ones
ones_uart:
    mov r25, r24
    
    ; Send digits
    mov r16, r22
    subi r16, -'0'
    rcall uart_send_byte
    
    mov r16, r23
    subi r16, -'0'
    rcall uart_send_byte
    
    mov r16, r25
    subi r16, -'0'
    rcall uart_send_byte
    
    ; Restore registers
    pop r25
    pop r23
    pop r22
    ret

; Send newline via UART
uart_send_newline:
    ldi r16, 13          ; CR
    rcall uart_send_byte
    ldi r16, 10          ; LF
    rcall uart_send_byte
    ret

; Send single byte via UART
uart_send_byte:
    lds r17, UCSR0A
    sbrs r17, UDRE0
    rjmp uart_send_byte
    sts UDR0, r16
    ret

; ------------------ Helper Functions ------------------

; SPI write to MAX7219 (r24=address, r25=data)
spi_write:
    cbi PORTB, 2         ; CS low
    
    out SPDR, r24        ; Send address
wait_spi1:
    in r16, SPSR
    sbrs r16, SPIF
    rjmp wait_spi1
    
    out SPDR, r25        ; Send data
wait_spi2:
    in r16, SPSR
    sbrs r16, SPIF
    rjmp wait_spi2
    
    sbi PORTB, 2         ; CS high
    ret

; Blink LEDs in sequence
blink_leds:
    sbi PORTD, 5         ; Green ON
    cbi PORTD, 6
    cbi PORTD, 7
    rcall delay_500ms
    
    cbi PORTD, 5
    sbi PORTD, 6         ; Yellow ON
    cbi PORTD, 7
    rcall delay_500ms
    
    cbi PORTD, 5
    cbi PORTD, 6
    sbi PORTD, 7         ; Red ON
    rcall delay_500ms
    
    cbi PORTD, 5
    cbi PORTD, 6
    cbi PORTD, 7         ; All OFF
    ret

; Delay 10ms
delay_10ms:
    push r16
    push r17
    push r18
    
    ldi r16, 80          ; Adjust based on CPU frequency
outer_10ms:
    ldi r17, 100
inner_10ms:
    ldi r18, 10
core_10ms:
    dec r18
    brne core_10ms
    dec r17
    brne inner_10ms
    dec r16
    brne outer_10ms
    
    pop r18
    pop r17
    pop r16
    ret

; Delay 500ms
delay_500ms:
    push r16
    
    ldi r16, 50
delay_loop:
    rcall delay_10ms
    dec r16
    brne delay_loop
    
    pop r16
    ret

; ------------------ Messages in Program Memory ------------------
.section .progmem
msg_prep:    .ascii "PREPARING"
             .byte 13, 10, 0        ; CR, LF, Null terminator
msg_safe:    .ascii "SAFE: "
             .byte 0                ; Null terminator
msg_warning: .ascii "WARNING: "
             .byte 0                ; Null terminator
msg_danger:  .ascii "DANGER: "
             .byte 0                ; Null terminator
msg_reset:   .ascii "RESET"
             .byte 13, 10, 0        ; CR, LF, Null terminator