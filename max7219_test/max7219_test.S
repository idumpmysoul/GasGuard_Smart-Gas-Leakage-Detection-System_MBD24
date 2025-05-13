;
; MAX7219_Display_Test.S - Simple test for MAX7219 seven-segment display
;
; This code initializes the MAX7219 and displays numbers 1234 on the 7-segment display
;

#define __SFR_OFFSET 0x00
#include "avr/io.h"

.section .text
.global main

main:
    ; Stack initialization
    ldi r16, 0x08      ; High byte of RAMEND
    out 0x3E, r16      ; SPH
    ldi r16, 0xFF      ; Low byte of RAMEND
    out 0x3D, r16      ; SPL
    
    ; Initialize SPI pins
    ; DDRB (0x04) - Set MOSI (PB3/11), SCK (PB5/13), and CS (PB2/10) as outputs
    ldi r16, (1 << 3) | (1 << 5) | (1 << 2)
    out 0x04, r16      ; DDRB
    
    ; Set CS high initially
    sbi 0x05, 2        ; Set bit 2 in PORTB (CS pin high)
    
    ; Initialize SPI (Master mode, MSB first, Mode 0, Fosc/4)
    ldi r16, (1 << 6) | (1 << 4)  ; SPE | MSTR (enable SPI, master mode)
    out 0x2C, r16      ; SPCR
    
    ; Wait for a bit after power-up
    rcall delay_ms
    
    ; Initialize MAX7219
    rcall max7219_init
    
    ; Display numbers
    rcall display_numbers
    
    ; Main loop
main_loop:
    rjmp main_loop

; Simple delay function
delay_ms:
    ldi r20, 250       ; Adjust for approximate millisecond delay
delay_outer:
    ldi r21, 200
delay_inner:
    dec r21
    brne delay_inner
    dec r20
    brne delay_outer
    ret

; Initialize MAX7219
max7219_init:
    ; Shutdown the display during initialization
    ldi r16, 0x0C      ; Shutdown register
    ldi r17, 0x00      ; Shutdown mode
    rcall max7219_send
    
    ; Disable test mode
    ldi r16, 0x0F      ; Display test register
    ldi r17, 0x00      ; Normal operation
    rcall max7219_send
    
    ; Use BCD decode mode for all digits (0-7)
    ldi r16, 0x09      ; Decode mode register
    ldi r17, 0xFF      ; BCD decode for all digits
    rcall max7219_send
    
    ; Set scan limit to display all digits (0-7)
    ldi r16, 0x0B      ; Scan limit register
    ldi r17, 0x07      ; Scan digits 0-7
    rcall max7219_send
    
    ; Set intensity/brightness (medium)
    ldi r16, 0x0A      ; Intensity register
    ldi r17, 0x08      ; Middle brightness (0-15)
    rcall max7219_send
    
    ; Clear all digits
    ldi r18, 0x01      ; Start with digit 0
    ldi r19, 0x08      ; 8 digits to clear
clear_loop:
    mov r16, r18       ; Select digit
    ldi r17, 0x00      ; Value = blank (0)
    rcall max7219_send
    inc r18
    dec r19
    brne clear_loop
    
    ; Take the display out of shutdown mode
    ldi r16, 0x0C      ; Shutdown register
    ldi r17, 0x01      ; Normal operation
    rcall max7219_send
    
    ret

; Display numbers 1234
display_numbers:
    ; Display 1 on digit 0 (rightmost)
    ldi r16, 0x01
    ldi r17, 0x01
    rcall max7219_send
    
    ; Display 2 on digit 1
    ldi r16, 0x02
    ldi r17, 0x02
    rcall max7219_send
    
    ; Display 3 on digit 2
    ldi r16, 0x03
    ldi r17, 0x03
    rcall max7219_send
    
    ; Display 4 on digit 3
    ldi r16, 0x04
    ldi r17, 0x04
    rcall max7219_send
    
    ret

; Send a command to MAX7219
; r16 = register address, r17 = data
max7219_send:
    cbi 0x05, 2        ; CS low (select device)
    
    ; Send register address
    out 0x2E, r16      ; SPDR
wait_tx1:
    in r16, 0x2D       ; SPSR
    sbrs r16, 7        ; Check SPIF bit
    rjmp wait_tx1
    
    ; Send data
    out 0x2E, r17      ; SPDR
wait_tx2:
    in r16, 0x2D       ; SPSR
    sbrs r16, 7        ; Check SPIF bit
    rjmp wait_tx2
    
    sbi 0x05, 2        ; CS high (deselect device)
    
    ; Short delay for reliability
    ldi r20, 50
delay_loop:
    dec r20
    brne delay_loop
    
    ret