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

.include "io.inc"
.include "regs.inc"

.export on_reset

.import device_init, device_call
.import irq_init

.CODE

; *****************************************************************************
; Purpose...............: System reset function called by the vector at
;                         address $fffc
; Input.................: None
; Output................: None
; Preparatory rutines...: None
; Errors................: None
; Preserved registers...: None
; Credits...............: New implementation
.proc on_reset
    ; Disable interrupts
    sei

    ; Set ROM bank
    stz rom_bank

    ; Initialize core device drivers
    jsr device_init

    ; Initialize interrupts
    jsr irq_init
    
    ; Print hello
    ldx #0
:   phx
    lda hello,x
    beq exit
    sta r0
    ldx #0 ; Vera
    ldy #12 ; Write
    jsr device_call
    plx
    inx
    bne :-

exit:
    cli
:   bra :-

hello:
    .byt "X16 OPEN KERNEL V. 0.0.1",13,0
.endproc
