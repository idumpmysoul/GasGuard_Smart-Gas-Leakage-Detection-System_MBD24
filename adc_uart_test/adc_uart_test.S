#define __SFR_OFFSET 0x00
#include "avr/io.h"

.global main

main:
    ; Initialize Stack Pointer (0x08FF)
    LDI   R16, 0x08
    OUT   SPH, R16
    LDI   R16, 0xFF
    OUT   SPL, R16

    ; UART Init (9600 baud @ 16MHz -> UBRR = 103)
    LDI   R16, 0x67         ; 103 in decimal
    STS   UBRR0L, R16
    LDI   R16, 0x00
    STS   UBRR0H, R16
    LDI   R16, (1<<TXEN0) | (1<<RXEN0)
    STS   UCSR0B, R16
    LDI   R16, (1<<UCSZ01) | (1<<UCSZ00)
    STS   UCSR0C, R16

    ; Load pointer to welcome string
    LDI   R30, lo8(msg_welcome)
    LDI   R31, hi8(msg_welcome)

    ; Print message
    RCALL PrintSerial

loop:
    RJMP loop

; --------------------------------------------------------
; Subroutine: PrintSerial
; Z points to null-terminated string in SRAM
; --------------------------------------------------------
PrintSerial:
    LD    R24, Z+           ; Load character from Z
    CPI   R24, 0
    BREQ  DonePrint

WaitUDRE:
    LDS   R25, UCSR0A
    SBRS  R25, UDRE0
    RJMP  WaitUDRE

    STS   UDR0, R24
    RJMP  PrintSerial

DonePrint:
    RET

; --------------------------------------------------------
; Data section with welcome message
; --------------------------------------------------------
.section .data
msg_welcome:
    .asciz "Welcome!\r\n"