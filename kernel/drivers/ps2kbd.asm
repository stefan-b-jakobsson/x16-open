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

.export ps2kbd_dispatch

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
        jmp (jmp_table,x)
    
jmp_table:
    .word init
    .word name              ; name
    .word not_implemented   ; open
    .word not_implemented   ; read
    .word not_supported     ; write
    .word not_implemented   ; close
    .word not_implemented   ; ioctl
    .word not_implemented   ; info
    .word not_implemented   ; on_irq
.endproc

.proc init
    rts
.endproc

.proc name
    ldx #<str
    ldy #>str
    clc
    rts
str:
    .byt "kbd",0
.endproc

.proc read
    ldx #$42
    ldy #$07

    ;jsr i2c_read_byte

    clc
    rts
.endproc

.proc not_implemented
    rts    
.endproc

.proc not_supported 
    sec
    rts
.endproc
