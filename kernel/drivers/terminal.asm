; *****************************************************************************
; Copyright 2026 Stefan Jakobsson
;
; Redistribution and use in source and binary forms, with or without 
; modification, are permitted provided that the following conditions are met:
;
; 1. Redistributions of source code must retain the above copyright notice, 
;    this list of conditions and the following disclaimer.
;
; 2. Redistributions in binary form must reproduce the above copyright notice, 
;    this list of conditions and the following disclaimer in the documentation 
;    and/or other materials provided with the distribution.
;
; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
; AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
; IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
; ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE 
; LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
; CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
; SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
; INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
; CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
; ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
; POSSIBILITY OF SUCH DAMAGE.
; *****************************************************************************

.include "regs.inc"

.export terminal_dispatch

.import petscii

.include "io.inc"

VERA_CHARSET_ADDR = charset_addr
VERA_SCREEN_ADDR = screen_addr

.CODE

; *****************************************************************************
; Purpose...............: Terminal driver dispatch function
; Input.................: Y         Driver function ID
;                         Further input as required by the driver function
; Output................: According to driver function documentation
; Preparatory rutines...: None
; Errors................: C         Set on error
;                         A         Error code, according to driver function
;                                   documentation
; Preserved registers...: None
; Credits...............: New implementation, not based on previous work
.proc terminal_dispatch
    ; Move Y to X
    phy
    plx

    ; Call sub-function
    jmp (jmp_table,x)
    
jmp_table:
    .word on_register               ; ID 0, on_register
    .word not_implemented           ; ID 2, on_unregister
    .word not_implemented           ; ID 4, open
    .word not_implemented           ; ID 6, dup
    .word not_implemented           ; ID 8, read_byte
    .word not_implemented           ; ID 10, read_block
    .word write_byte                ; ID 12, write_byte
    .word not_implemented           ; ID 14, write_block
    .word not_implemented           ; ID 16, seek
    .word not_implemented           ; ID 18, position
    .word not_implemented           ; ID 20, close
    .word not_implemented           ; ID 22, ioctl
    .word on_irq                    ; ID 24, on_irq
    .word not_implemented           ; ID 26, driver_string
.endproc

;*****************************************************************************
; Purpose...............: Clear screen and setup terminal driver
; Input.................: None
; Output................: None
; Preparatory rutines...: None
; Errors................: None
; Preserved registers...: None
; Credits...............: New implementation, not based on previous work
.proc on_register
    ; Cursor position to top left
    stz terminal_x
    stz terminal_y

    ; Activate cursor
    lda #1
    sta cursor_state

    ; Reset VERA + DCSEL=0 + ADDRSEL=0
    lda #$80
    sta VERA_CTRL

    ; Upload charset
    lda #<petscii
    sta $22
    lda #>petscii
    sta $23

    stz VERA_ADDR_L
    lda #((VERA_CHARSET_ADDR>>8) & 255)
    sta VERA_ADDR_M
    lda #(((VERA_CHARSET_ADDR>>16) & 1) | %00010000)
    sta VERA_ADDR_H

    ldy #0
    ldx #8
:   lda ($22),y
    sta VERA_DATA0
    iny
    bne :-
    inc $23
    dex
    bne :-
    
    ; Layer 1 config
    lda #$60                            ; Map height 64 + Map width 128
    sta VERA_L1_CONFIG

    lda #(VERA_SCREEN_ADDR>>9)          ; Screen buffer (16:9)
    sta VERA_L1_MAPBASE

    lda #((VERA_CHARSET_ADDR>>11)<<2)   ; Charset buffer (16:11) + tile height 8px + tile width 8px
    sta VERA_L1_TILEBASE

    ; Set screen mode 0
    clc
    lda #$00
    jsr screen_mode

    ; Clear screen
    stz VERA_ADDR_L
    lda #$b0
    sta VERA_ADDR_M
    lda #%00010001
    sta VERA_ADDR_H
    ldx #80
    ldy #97
:   lda #32
    sta VERA_DATA0
    sty VERA_DATA0
    dex
    bne :-
    ldx #80
    inc VERA_ADDR_M
    stz VERA_ADDR_L
    lda VERA_ADDR_M
    cmp #$b0+60
    bcc :-

    ; Exit function
    clc
    rts
.endproc

; *****************************************************************************
; Purpose...............: Writes a byte to the screen
; Input.................: r0        Byte value
; Output................: None
; Preparatory rutines...: open
; Errors................: None
; Preserved registers...: None
; Credits...............: New implementation, not based on previous work
.proc write_byte
    ; Get byte value
    ldx r0

    ; Check if CR
    cpx #13
    bne :+
    stz terminal_x
    inc terminal_y
    clc
    rts
    
    ; Setup VERA address based on cursor position
:   lda terminal_x
    asl
    sta VERA_ADDR_L
    clc
    lda terminal_y
    adc #$b0
    sta VERA_ADDR_M
    lda #1
    sta VERA_ADDR_H

    ; Convert PETSCII to screen code
    lda r0
    clc

    cmp #$20
    bcs :+
    adc #$80
    bra print

:   cmp #$40
    bcc print

    cmp #$60
    bcs :+
    adc #$c0
    bra print

:   cmp #$80
    bcs :+
    adc #$e0
    bra print

:   cmp #$a0
    bcs :+
    adc #$c0
    bra print

:   cmp #$ff
    beq :+
    adc #$80
    bra print

:   lda #$5e

print:
    sta VERA_DATA0

    ; Move cursor position
    inc terminal_x
    lda terminal_x
    cmp #80
    bcc :+
    stz terminal_x
    inc terminal_y

:   ; Exit function
    clc
    rts
.endproc

.proc on_irq
    lda cursor_state
    bne :+

exit:
    clc
    rts

:   dec cursor_state
    beq show

    lda cursor_state
    cmp #30
    bne exit

hide:
    ldx #97
    bra update

show:
    lda #60
    sta cursor_state
    ldx #22

update:
    lda terminal_x
    asl
    inc
    sta VERA_ADDR_L

    clc
    lda terminal_y
    adc #$b0
    sta VERA_ADDR_M
    lda #1
    sta VERA_ADDR_H
    stx VERA_DATA0
    
    clc
    rts
.endproc

; *****************************************************************************
; Purpose...............: Functions not (yet) implemented are pointed here
; Input.................: None
; Output................: None
; Preparatory rutines...: open
; Errors................: None
; Preserved registers...: None
; Credits...............: New implementation, not based on previous work
.proc not_implemented
    clc
    rts
.endproc

; *****************************************************************************
; Purpose...............: Get/set screen mode
; Input.................: .C=0 => Set screen mode, .C=1 => Get screen mode
;                         .A = New screen mode
; Output................: .A = Screen mode
;                         .X = Tile width
;                         .Y = Tile height
; Preparatory rutines...: None
; Errors................: .C = 1 if requesting to set unsupported mode
; Registers affected....: .A, .X, .Y
; Credits...............: New implementation, not based on previous work
.proc screen_mode
    bcs getmode

setmode:
    cmp #128
    beq graphmode
    cmp #12
    bcc textmode
    
unsupported:
    sec
    rts

graphmode:
    ; TODO: Not yet implemented
    sec
    rts

textmode:
    sta screen_active_mode

    ; Move screen mode to X
    tax

    ; Enable Layer 1 + Disable Layer 0 + VGA output
    lda #%00100001
    sta VERA_DC_VIDEO

    ; Set screen params
    lda #$02            ; DCSEL=1
    sta VERA_CTRL

    lda hstart,x
    sta VERA_DC_HSTART
    lda hstop,x
    sta VERA_DC_HSTOP
    lda vstart,X
    sta VERA_DC_VSTART
    lda vstop,x
    sta VERA_DC_VSTOP

    lda #$00            ; DCSEL=0
    sta VERA_CTRL

    lda hscale,x
    sta VERA_DC_HSCALE
    lda vscale,x
    sta VERA_DC_VSCALE

    lda width,x
    sta screen_width
    lda height,x
    sta screen_height

    clc

getmode:
    lda screen_active_mode
    ldx screen_width
    ldy screen_height
    rts

; ---------------------------------------------------------------------
; Mode:        0    1    2    3    4    5    6    7    8    9   10   11
; ---------------------------------------------------------------------
hscale: .byt 128, 128,  64,  64,  64,  32,  32,  64, 128, 128,  64,  64
vscale: .byt 128,  64, 128,  64,  32,  64,  32,  64, 129,  64, 128,  64
hstart: .byt   0,   0,   0,   0,   0,   0,   0,  36,  16,  16,  16,  16
hstop:  .byt 160, 160, 160, 160, 160, 160, 160, 124, 144, 144, 144, 144
vstart: .byt   0,   0,   0,   0,   0,   0,   0,  28,  20,  20,  20,  20
vstop:  .byt 240, 240, 240, 240, 240, 240, 240, 212, 220, 220, 220, 220
width:  .byt  80,  80,  40,  40,  40,  20,  20,  22,  64,  64,  32,  32
height: .byt  60,  30,  60,  30,  15,  30,  15,  23,  50,  25,  50,  25

.endproc

.segment "K_LRAM"
    screen_active_mode: .res 1
    screen_width: .res 1
    screen_height: .res 1
    terminal_x: .res 1
    terminal_y: .res 1
    cursor_state: .res 1
