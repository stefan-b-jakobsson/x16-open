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
.include "version.inc"

; Exports
.export get_ticks, set_ticks, tick
.export get_errmsg, set_errmsg
.export sys_info

; Variables
.segment "K_LRAM"
jiffies: .res 3

.CODE
; *****************************************************************************
; Purpose...............: Returns the jiffy counter
; Input.................: None
; Output................: A     Counter value, bits 0-7
;                         X     Counter value, bits 8-15
;                         Y     Counter value, bits 16-23
; Preparatory rutines...: None
; Errors................: None
; Registers affected....: A, X, Y, P
; Credits...............: New implementation
.proc get_ticks
    lda jiffies
    ldx jiffies+1
    ldy jiffies+2
    rts
.endproc

; *****************************************************************************
; Purpose...............: Sets the jiffy counter
; Input.................: A     Counter value, bits 0-7
;                         X     Counter value, bits 8-15
;                         Y     Counter value, bits 16-23
; Output................: None
; Preparatory rutines...: None
; Errors................: None
; Registers affected....: None
; Credits...............: New implementation
.proc set_ticks
    sta jiffies
    stx jiffies+1
    sty jiffies+2
    rts
.endproc

; *****************************************************************************
; Purpose...............: Increments jiffy counter
; Input.................: None
; Output................: None
; Preparatory rutines...: None
; Errors................: None
; Registers affected....: P
; Credits...............: New implementation
.proc tick
    inc jiffies
    bne exit
    inc jiffies+1
    bne exit
    inc jiffies+2
    
exit:
    rts
.endproc

; *****************************************************************************
; Purpose...............: Get last error message
; Input.................: None
; Output................: A         Error number
;                         r0-1      Error message address
;                         r2        Error message bank
; Preparatory rutines...: None
; Errors................: None
; Registers affected....: A, r0-2
; Credits...............: New implementation
.proc get_errmsg
    ; TODO: Not yet implemented
    rts
.endproc

; *****************************************************************************
; Purpose...............: Set error message
; Input ................: A         Error number
;                         r0-1      Error message address
;                         r2        Error message bank
; Output................: None
; Preparatory rutines...: None
; Errors................: None
; Registers affected....: None
; Credits...............: New implementation
.proc set_errmsg
    ; TODO: Not yet implemented
    rts
.endproc

; *****************************************************************************
; Purpose...............: Returns system information
; Input ................: None
; Output................: r0-2      Kernel version (major, minor, patch)
;                         r3-4      String buffer address in ROM bank 0
; Preparatory rutines...: None
; Errors................: None
; Registers affected....: None
; Credits...............: New implementation
.proc sys_info
    ; Set kernel version
    lda #version_major
    sta r0
    lda #version_minor
    sta r1
    lda #version_patch
    sta r2

    ; Set string address
    lda #<str
    sta r3
    lda #>str
    sta r4

    ; Exit
    rts

str:
    .byt .sprintf("X16 OPEN KERNEL V %u.%u.%u", version_major, version_minor, version_patch), 13, 13, 0
.endproc
