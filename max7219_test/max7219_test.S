#define __SFR_OFFSET 0x00
#include <avr/io.h>

.section .text
.global main

main:
    ; Set up stack
    LDI   R16, 0x08
    OUT   SPH, R16
    LDI   R16, 0xFF
    OUT   SPL, R16

    ; Set MOSI (PB3), SCK (PB5), CS (PB2) as output
    ldi r16, (1 << PB2) | (1 << PB3) | (1 << PB5)
    out DDRB, r16

    ; Enable SPI (Master mode)
    ldi r16, (1 << SPE) | (1 << MSTR)
    out SPCR, r16

    ; Initialize MAX7219
    ldi r16, 0x09    ; Decode mode: BCD digits 0–3
    ldi r17, 0x0F
    rcall spi_send

    ldi r16, 0x0A    ; Intensity (brightness)
    ldi r17, 0x08
    rcall spi_send

    ldi r16, 0x0B    ; Scan limit (digits 0–3)
    ldi r17, 0x03
    rcall spi_send

    ldi r16, 0x0C    ; Shutdown register = normal operation
    ldi r17, 0x01
    rcall spi_send

    ; Display digits 1 2 3 4
    ldi r16, 1
    ldi r17, 4
    rcall spi_send

    ldi r16, 2
    ldi r17, 3
    rcall spi_send

    ldi r16, 3
    ldi r17, 2
    rcall spi_send

    ldi r16, 4
    ldi r17, 1
    rcall spi_send

end_loop:
    rjmp end_loop

; ========================
; SPI Send Subroutine
; r16 = address (digit)
; r17 = data (value)
; ========================
spi_send:
    out SPDR, r16
wait1:
    in r18, SPSR
    sbrs r18, SPIF
    rjmp wait1
    out SPDR, r17
wait2:
    in r18, SPSR
    sbrs r18, SPIF
    rjmp wait2
    ret
