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

; Exports
.export ps2kbd_dispatch

; Imports
.import i2c_read_byte

.segment "K_LRAM"
BUFSIZE = 10
buf: .res BUFSIZE
buf_head: .res 1
buf_tail: .res 1

.CODE

; *****************************************************************************
; Purpose...............: PS/2 keyboard driver dispatch function
; Input.................: X = Driver function ID
; Output................: None
; Preparatory rutines...: None
; Errors................: None
; Preserved registers...: None
; Credits...............: New implementation, not based on previous work
.proc ps2kbd_dispatch
    ; Move Y to X
    phy
    plx

    ; Call sub-function
    jmp (jmp_table,x)
    
jmp_table:
    .word on_register               ; ID 0, on_register
    .word not_implemented           ; ID 2, on_unregister
    .word open                      ; ID 4, open
    .word read_byte                 ; ID 8, read_byte
    .word not_implemented           ; ID 10, read_block
    .word not_implemented           ; ID 12, write_byte
    .word not_implemented           ; ID 14, write_block
    .word not_implemented           ; ID 16, seek
    .word not_implemented           ; ID 18, position
    .word not_implemented           ; ID 20, close
    .word not_implemented           ; ID 22, ioctl
    .word on_irq                    ; ID 24, on_irq
    .word not_implemented           ; ID 26, driver_string
.endproc

.proc on_register
    ; Reset buffer pointers
    stz buf_head
    stz buf_tail

    ; Set device flags
    lda #%10000001
    
    ; Exit
    clc
    rts
.endproc

.proc open
    ldy #0
    lda #%10001001
    clc
    rts
.endproc

.proc read_byte
    ldx buf_head
    cpx buf_tail
    beq empty

    lda buf,x
    inx
    cpx #BUFSIZE
    bcc exit
    ldx #0
exit:
    stx buf_head
    clc
    rts

empty:
    lda #0
    clc
    rts
.endproc

.proc on_irq
    ; Get keycode from the SMC
    ldx #$42
    ldy #$07
    jsr i2c_read_byte
    beq exit ; No key
    bpl keydown
    
exit:
    clc
    rts

keydown:
    ; Move keycode to Y
    tay

    ; Calculate new tail, and check if buffer is full
    lda buf_tail ; Get current tail
    inc ; Increment by 1
    cmp #BUFSIZE ; Check if less than buffer size
    bcc :+ ; Yes
    lda #0 ; No, wrap around to 0
:   cmp buf_head ; Check if new tail is same as head
    beq exit ; Indeed, buffer is full

    ; Store value
    pha ; Save new tail on stack
    ldx buf_tail ; Get current tail again
    lda keytable,y ; Get character code
    sta buf,x ; Store in buffer
    plx ; Retrieve new tail from stack
    stx buf_tail ; And store it
    bra exit ; We're done.
.endproc

.proc not_implemented
    clc
    rts
.endproc

keytable:
    .byt 0, 96, 49, 50, 51, 52, 53, 54, 55, 56
    .byt 57, 48, 45, 61, 0, 20, 9, 81, 87, 69
    .byt 82, 84, 89, 85, 73, 79, 80, 91, 93, 92
    .byt 0, 65, 83, 68, 70, 71, 72, 74, 75, 76
    .byt 59, 39, 0, 13, 0, 0, 90, 88, 67, 86
    .byt 66, 78, 77, 44, 46, 47, 0, 0, 0, 0
    .byt 0, 32, 0, 0, 32, 0, 0, 0, 0, 0
    .byt 0, 0, 0, 0, 0, 75, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 55, 52, 49, 0, 47, 56, 53, 50, 48, 42, 57, 54, 51, 46, 45, 43, 0, 13, 0, 27, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
