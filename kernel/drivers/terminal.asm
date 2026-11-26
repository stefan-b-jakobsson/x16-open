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

; Includes
.include "regs.inc"
.include "io.inc"

; Exports
.export terminal_dispatch

; Imports
.import fetch
.import device_call

; Definitions
VERA_CHARSET_ADDR = charset_addr
VERA_SCREEN_ADDR = screen_addr

.code
; *****************************************************************************
; Purpose...............: Terminal driver dispatch function
; Input.................: Y         Driver function ID
;                         Further input as required by the driver function
; Output................: According to driver function documentation
; Preparatory routines..: None
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
    .word open                      ; ID 4, open
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
; Preparatory routines..: None
; Errors................: None
; Preserved registers...: None
; Credits...............: New implementation, not based on previous work
.proc on_register
    ; Set screen dimensions
    lda #80
    sta screen_width
    lda #60
    sta screen_height

    ; Set default color
    lda #$61
    sta color
    sta color_backup
    lda #($61<<4) & $ff
    sta color_background

    ; Reset VERA + DCSEL=0 + ADDRSEL=0
    lda #$80
    sta VERA_CTRL

    ; Upload charset to VERA
    stz VERA_ADDR_L
    lda #((VERA_CHARSET_ADDR>>8) & 255)
    sta VERA_ADDR_M
    lda #(((VERA_CHARSET_ADDR>>16) & 1) | %00010000)
    sta VERA_ADDR_H

    lda #$00    ; Set font start address, $c000
    sta r0
    lda #$c0
    sta r1

    ldy #0
:   lda #r0
    ldx #2      ; Bank 2
    jsr fetch
    sta VERA_DATA0
    iny
    bne :-
    inc r1
    lda r1
    cmp #$c8
    bcc :-
    
    ; VERA Layer 1 config
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
    jsr clear_screen

    ; Cursor show
    lda #1
    sta cursor_state

    ; Exit function
    clc
    lda #%10000010
    rts
.endproc

;*****************************************************************************
; Purpose...............: File open
; Input.................: None
; Output................: A         Kernel file flags
; Preparatory routines..: None
; Errors................: None
; Preserved registers...: None
; Credits...............: New implementation, not based on previous work
.proc open
    ldy #0
    lda #%10001010
    clc
    rts
.endproc

; *****************************************************************************
; Purpose...............: Writes a byte to the screen
; Input.................: r0        Byte value
; Output................: None
; Preparatory routines..: open
; Errors................: None
; Preserved registers...: None
; Credits...............: New implementation, not based on previous work
.proc write_byte
    ; Backup cursor state on stack
    php ; Backup P
    cli ; Disable interrupts
    lda cursor_state
    stz cursor_state
    plp ; Restore P
    pha

    ; Setup VERA address to cursor position
    jsr vera_to_cursor

    ; Hide cursor
    inc VERA_ADDR_L
    lda color_backup
    sta VERA_DATA0

    ; Get byte value
    lda r0

controlcode_lower:
    ; Check if lower control code range ($00-1f)
    cmp #$20
    bcs controlcode_upper

    ; Yes, jump to control code handler
    asl
    tax
    jmp (cc_jmptbl,x)

controlcode_upper:
    ; Check if upper control code range ($80-9f)
    cmp #$80
    bcc print
    cmp #$a0
    bcs print
    
    ; Yes, jump to control code handler
    sec
    sbc #$60
    asl
    tax
    jmp (cc_jmptbl,x)

print:
    ; Set color
    ldx color
    stx VERA_DATA0
    dec VERA_ADDR_L

    ; Output char
    sta VERA_DATA0

    ; Move cursor position
    inc terminal_x
    lda terminal_x
    cmp #80
    bcc restore_cursor
    stz terminal_x
    inc terminal_y

restore_cursor:
    ; Enable cursor 
    pla
    beq exit
    
    lda #1
    sta cursor_state

exit:
    clc
    rts

; Control code jump table
cc_jmptbl: 
    .word cc_null               ; $00 NULL
    .word cc_swap_colors        ; $01 Swap Colors
    .word cc_page_down          ; $02 Page Down
    .word cc_stop               ; $03 Stop
    .word cc_end                ; $04 End
    .word cc_set_color          ; $05 Color: white
    .word cc_null               ; $06 Menu
    .word cc_bell               ; $07 Bell
    .word cc_null               ; $08 Disallow Charset Switch
    .word cc_tab                ; $09 Tab
    .word cc_lf                 ; $0a LF
    .word cc_null               ; $0b Layout Swap
    .word cc_null               ; $0c --
    .word cc_return             ; $0d Return
    .word cc_null               ; $0e Charset: Lower/Upper
    .word cc_null               ; $0f Charset: ISO On
    .word cc_null               ; $10 F9
    .word cc_crs_down           ; $11 Cursor Down
    .word cc_rvs_on             ; $12 Reverse On
    .word cc_home               ; $13 Home
    .word cc_backspace          ; $14 Backspace (Deletes char to the left of the cursor)
    .word cc_null               ; $15 F10
    .word cc_null               ; $16 F11 
    .word cc_null               ; $17 F12 
    .word cc_shft_tab           ; $18 Shift + Tab
    .word cc_delete             ; $19 Delete (Deletes char to the right of the cursor)
    .word cc_null               ; $1a --
    .word cc_null               ; $1b Esc
    .word cc_set_color          ; $1c Color: red
    .word cc_crs_right          ; $1d Cursor Right
    .word cc_set_color          ; $1e Color: green
    .word cc_set_color          ; $1f Color: blue
    
    .word cc_null               ; $80 Verbatim mode
    .word cc_set_color          ; $81 Color: orange
    .word cc_pageup             ; $82 Page Up
    .word cc_null               ; $83 Run
    .word cc_null               ; $84 Help
    .word cc_null               ; $85 F1
    .word cc_null               ; $86 F3
    .word cc_null               ; $87 F5
    .word cc_null               ; $88 F7
    .word cc_null               ; $89 F2
    .word cc_null               ; $8a F4 
    .word cc_null               ; $8b F6
    .word cc_null               ; $8c F8
    .word cc_shft_return        ; $8d Shift return
    .word cc_null               ; $8e Charset upper/PETSCII
    .word cc_null               ; $8f Charset: ISO off
    .word cc_set_color          ; $90 Color: black
    .word cc_crs_up             ; $91 Cursor Up 
    .word cc_rvs_off            ; $92 Reverse off 
    .word cc_cls                ; $93 Clear
    .word cc_insert             ; $94 Insert 
    .word cc_set_color          ; $95 Color: Brown
    .word cc_set_color          ; $96 Color: Light Red
    .word cc_set_color          ; $97 Color: Dark Gray
    .word cc_set_color          ; $98 Color: Middle Gray
    .word cc_set_color          ; $99 Color: Light Green
    .word cc_set_color          ; $9a Color: Light Blue
    .word cc_set_color          ; $9b Color: Light Gray
    .word cc_set_color          ; $9c Color: Purple
    .word cc_crs_left           ; $9d Cursor Left
    .word cc_set_color          ; $9e Color: Yellow
    .word cc_set_color          ; $9f Color: Cyan
.endproc

; *****************************************************************************
; Purpose...............: Called by the Kernel on IRQ
; Input.................: None
; Output................: None
; Preparatory routines..: None
; Errors................: None
; Preserved registers...: None
; Credits...............: New implementation, not based on previous work
.proc on_irq
    ; Backup VERA
    jsr vera_backup

    ; Get cursor state
    lda cursor_state
    bne update_timer

exit:
    jsr vera_restore
    clc
    rts

update_timer:
    dec cursor_state
    bne hide

show:
    ldx #60
    stx cursor_state
    bra set_state

hide:
    lda cursor_state
    cmp #30
    bne exit

set_state:
    jsr vera_to_cursor
    inc VERA_ADDR_L
    jsr toggle_cursor
    bra exit
.endproc

; *****************************************************************************
; Purpose...............: Functions not (yet) implemented are pointed here
; Input.................: None
; Output................: None
; Preparatory routines..: open
; Errors................: None
; Preserved registers...: None
; Credits...............: New implementation, not based on previous work
.proc not_implemented
    clc
    rts
.endproc

.proc vera_backup
    lda VERA_ADDR_L
    sta vera
    lda VERA_ADDR_M
    sta vera+1
    lda VERA_ADDR_H
    sta vera+2
    lda VERA_CTRL
    sta vera+3
    rts
.endproc

.proc vera_restore
    lda vera
    sta VERA_ADDR_L
    lda vera+1
    sta VERA_ADDR_M
    lda vera+2
    sta VERA_ADDR_H
    lda vera+3
    sta VERA_CTRL
    rts
.endproc

; *****************************************************************************
; Purpose...............: Get/set screen mode
; Input.................: .C=0 => Set screen mode, .C=1 => Get screen mode
;                         .A = New screen mode
; Output................: .A = Screen mode
;                         .X = Tile width
;                         .Y = Tile height
; Preparatory routines..: None
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


; *****************************************************************************
; Control code functions
; Input: A      Control character
; *****************************************************************************
.proc cc_null
    jmp write_byte::restore_cursor
.endproc

.proc cc_swap_colors
    lda color
    jsr swap_nibbles
    sta color
    asl
    asl
    asl
    asl
    sta color_background
    jmp write_byte::restore_cursor
.endproc

.proc cc_page_down
    ldy #10
loop:
    lda screen_height
    dec
    cmp terminal_y
    beq scroll
    inc terminal_y
loop2:
    dey
    bne loop
exit:
    jmp write_byte::restore_cursor
scroll:
    phy
    ldy terminal_y
    jsr scroll_up
    ply
    bra loop2
.endproc

.proc cc_stop
    jmp write_byte::restore_cursor
.endproc

.proc cc_end
    jmp write_byte::restore_cursor
.endproc

.proc cc_bell
    jmp write_byte::restore_cursor
.endproc

.proc cc_tab
    jmp write_byte::restore_cursor
.endproc

.proc cc_lf
    jmp cc_return
.endproc

.proc cc_return
    stz terminal_x
    bra cc_crs_down
.endproc

.proc cc_crs_down
    lda screen_height
    dec
    cmp terminal_y
    beq atedge
    inc terminal_y
exit:
   jmp write_byte::restore_cursor
atedge:
    ldy terminal_y
    jsr scroll_up
    bra exit
.endproc

.proc cc_rvs_on
    jmp write_byte::restore_cursor
.endproc

.proc cc_home
    stz terminal_x
    stz terminal_y
    jmp write_byte::restore_cursor
.endproc

.proc cc_backspace
    lda terminal_x
    bne default

    ; Cursor at left edge
    lda screen_width
    dec
    sta terminal_x
    lda terminal_y
    bne notattop
attop:
    ldy #0
    jsr scroll_down
    jmp write_byte::restore_cursor
notattop:
    dec terminal_y
    bra clear
default:

    ; Cursor not at left edge
    dec terminal_x
clear:
    jsr vera_to_cursor
    lda #32
    sta VERA_DATA0
    jmp write_byte::restore_cursor
.endproc

.proc cc_shft_tab
    jmp write_byte::restore_cursor
.endproc

.proc cc_delete
    jmp write_byte::restore_cursor
.endproc

.proc cc_pageup
    ldy #10
loop:
    lda terminal_y
    beq scroll
    dec terminal_y
loop2:
    dey
    bne loop
exit:
    jmp write_byte::restore_cursor
scroll:
    phy
    ldy #0
    jsr scroll_down
    ply
    bra loop2
.endproc

.proc cc_crs_right
    lda screen_width
    dec
    cmp terminal_x
    beq atedge    
    inc terminal_x
exit:
    jmp write_byte::restore_cursor
atedge:
    stz terminal_x
    jmp cc_crs_down
.endproc

.proc cc_shft_return
    jmp write_byte::restore_cursor
.endproc

.proc cc_crs_up
    lda terminal_y
    beq atedge
    dec terminal_y
exit:
    jmp write_byte::restore_cursor
atedge:
    ldy #0
    jsr scroll_down
    bra exit
.endproc

.proc cc_rvs_off
    jmp write_byte::restore_cursor
.endproc

.proc cc_cls
    jsr clear_screen
    jmp write_byte::restore_cursor
.endproc

.proc cc_insert
    jmp write_byte::restore_cursor
.endproc

.proc cc_crs_left
    lda terminal_x
    beq atedge
    dec terminal_x
exit:
    jmp write_byte::restore_cursor
atedge:
    lda screen_width
    dec
    sta terminal_x
    jmp cc_crs_up
.endproc

.proc cc_set_color
    ldx #16
:   cmp chars-1,x
    beq match
    dex
    bne :-
    bra exit

match:
    lda color
    and #$f0
    ora colors-1,x
    sta color
    asl
    asl
    asl
    asl
    sta color_background

exit:
    jmp write_byte::restore_cursor

chars:   .byt $0a, $38, $3c, $3e, $42, $60, $6a, $6c, $6e, $70, $72, $74, $76, $78, $7c, $7e
colors:  .byt $01, $02, $05, $06, $08, $00, $09, $0a, $0b, $0c, $0d, $0e, $0f, $04, $07, $03

.endproc

; *****************************************************************************
; Helper functions
; *****************************************************************************

; Purpose: Set VERA address to cursor
; Input..: None
; Output.: None
.proc vera_to_cursor
    lda terminal_x
    asl
    sta VERA_ADDR_L
    clc
    lda terminal_y
    adc #>VERA_SCREEN_ADDR
    sta VERA_ADDR_M
    lda #^VERA_SCREEN_ADDR
    adc #0
    sta VERA_ADDR_H
    lda VERA_CTRL
    and #(~1)&255
    sta VERA_CTRL
    rts
.endproc

; Purpose: Toggles the cursor
; Input..: VERA address set to cursor color location
; Output.: None
.proc toggle_cursor
    lda cursor_state
    cmp #60
    beq show_cursor
    cmp #30
    beq hide_cursor
    rts

show_cursor:
    lda VERA_DATA0
    sta color_backup
    lsr
    lsr
    lsr
    lsr
    ora color_background
    sta VERA_DATA0
    rts

hide_cursor:
    lda color_backup
    sta VERA_DATA0
    rts
.endproc

; Purpose: Clears the screen
; Input..: None
; Output.: None
.proc clear_screen
    ; Setup VERA address
    stz VERA_ADDR_L
    lda #>VERA_SCREEN_ADDR
    sta VERA_ADDR_M
    lda #^VERA_SCREEN_ADDR + %00010000
    sta VERA_ADDR_H

    ldy screen_height
    sty terminal_y
    ldx screen_width
    ldy color
loop1:   
    lda #32
loop2:
    sta VERA_DATA0
    sty VERA_DATA0
    dex
    bne loop2
    ldx screen_width
    inc VERA_ADDR_M
    stz VERA_ADDR_L
    dec terminal_y
    bne loop1

    ; Cursor position to top left, Y is already 0
    stz terminal_x
    
    rts
.endproc

; Purpose: Swaps high and low nibble
; Input..: A    Value
; Output.: A    Value after swapping nibbles
.proc swap_nibbles
    asl
    adc #$80
    rol
    asl
    adc #$80
    rol
    rts
.endproc

; Purpose: Scrolls screen one row up
; Input..: Y    Row index where to start
; Output.: None
.proc scroll_up
    ; Backup start row index on stack
    phy
    
    ; Set VERA address port 0 to start of line 1
    lda VERA_CTRL
    and #(~1) & $ff
    sta VERA_CTRL

    stz VERA_ADDR_L
    clc
    lda #>VERA_SCREEN_ADDR
    adc #1
    sta VERA_ADDR_M
    lda #^VERA_SCREEN_ADDR
    adc #0
    sta VERA_ADDR_H

    lda screen_width
    asl
    tax
copy:
    lda VERA_DATA0
    dec VERA_ADDR_M
    sta VERA_DATA0
    inc VERA_ADDR_M
    inc VERA_ADDR_L
    dex
    bne copy
    
    lda screen_width
    asl
    tax
    stz VERA_ADDR_L
    inc VERA_ADDR_M
    dey
    bne copy

clear_row:
    clc
    pla
    adc #>VERA_SCREEN_ADDR
    sta VERA_ADDR_M
    lda #^VERA_SCREEN_ADDR + %00010000
    adc #0
    sta VERA_ADDR_H
    lda #32
    ldy color
    ldx screen_width
clear:
    sta VERA_DATA0
    sty VERA_DATA0
    dex
    bne clear

    rts
.endproc

; Purpose: Scrolls screen one row down
; Input..: Y    Row index where to start
; Output.: None
.proc scroll_down
    ; Calulcate address where to stop copying
    tya
    clc
    adc #>VERA_SCREEN_ADDR
    tay

    ; Set VERA address port 0
    lda VERA_CTRL
    and #(~1) & $ff
    sta VERA_CTRL

    stz VERA_ADDR_L
    clc
    lda screen_height
    dec
    dec
    adc #>VERA_SCREEN_ADDR
    sta VERA_ADDR_M
    lda #^VERA_SCREEN_ADDR
    adc #0
    sta VERA_ADDR_H

    lda screen_width
    asl
    tax
copy:
    lda VERA_DATA0
    inc VERA_ADDR_M
    sta VERA_DATA0
    dec VERA_ADDR_M
    inc VERA_ADDR_L
    dex
    bne copy
    
    lda screen_width
    asl
    tax
    stz VERA_ADDR_L
    dec VERA_ADDR_M

    cpy VERA_ADDR_M
    bcc copy
    beq copy

clear_row:
    tya
    sta VERA_ADDR_M
    lda VERA_ADDR_H
    ora #%00010000
    sta VERA_ADDR_H

    lda #32
    ldy color
    ldx screen_width
clear:
    sta VERA_DATA0
    sty VERA_DATA0
    dex
    bne clear

    rts
.endproc

.segment "K_LRAM"
    screen_active_mode: .res 1
    screen_width: .res 1
    screen_height: .res 1
    terminal_x: .res 1
    terminal_y: .res 1
    cursor_state: .res 1

    color: .res 1
    color_background: .res 1
    color_backup: .res 1

    vera: .res 4
