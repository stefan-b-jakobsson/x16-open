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

; Exports
.export on_reset

; Imports
.import device_init, device_call
.import file_init
.import irq_init
.import i2c_restore
.import set_ticks
.import shell_main

.CODE

; *****************************************************************************
; Purpose...............: Target for hardware reset vector ($fffc); may also be
;                         called in runtime code to reset the system.
; Input.................: None
; Output................: None
; Preparatory rutines...: None
; Errors................: None
; Preserved registers...: None
; Credits...............: New implementation
.proc on_reset
    ; Disable interrupts
    sei

    ; Ensure ROM bank register is 0
    stz rom_bank

    ; Initialize I2C library
    jsr i2c_restore

    ; Initialize device drivers
    jsr device_init

    ; Initialize files
    jsr file_init

    ; Initialize interrupts
    jsr irq_init

    ; Reset jiffy clock
    lda #0
    ldx #0
    ldy #0
    jsr set_ticks

    ; Reset complete
    cli
    jmp shell_main
.endproc
