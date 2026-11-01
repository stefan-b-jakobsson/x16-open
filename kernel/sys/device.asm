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

.include "device.inc"
.include "file.inc"

; Exports
.export device_init, device_register, device_unregister, device_call

; Imports
.import ft_driver, ft_context, ft_flags
.import terminal_dispatch
.import ps2kbd_dispatch

; *****************************************************************************
; Global device table
.segment "K_LRAM"
dt_addr:    .res DRIVER_COUNT*2
dt_bank:    .res DRIVER_COUNT
dt_flags:   .res DRIVER_COUNT


.CODE
; *****************************************************************************
; Purpose...............: First sets all devices not present, and then
;                         registers built-in device drivers that are always
;                         present, i.e.:
;                         0: Terminal driver
;                         1: I2C driver
;                         2: PS/2 keyboard driver
;                         3: PS/2 mouse driver
;                         4: SNES controller driver
;                         5: Built-in SD card driver
; Input.................: None
; Output................: None
; Errors................: None
; Preserved registers...: None
; Credits...............: New implementation
.proc device_init
    ; Set all devices not present
    lda #0
    ldx #DRIVER_COUNT
:   sta dt_flags-1,x
    dex
    bne :-

    ; #0: Register terminal driver (STDOUT)
    lda #<terminal_dispatch
    sta dt_addr
    lda #>terminal_dispatch
    sta dt_addr+1
    stz dt_bank
    lda #DFLAGS_NO_BANK + DFLAGS_WRITING + DFLAGS_READING + $80
    sta dt_flags
    ldx #0
    ldy #0
    jsr device_call

    ; #2: Register PS/2 mouse driver
    ; TODO...

    ; #3: Register SNES game controller driver
    ; TODO...

    ; #4: Register SD card driver
    ; TODO...
    
    rts
.endproc

; *****************************************************************************
; Purpose...............: Registers a new device driver
; Input.................: X         Driver number
;                         r0-1      Driver address
;                         r2        Driver bank
; Output................: A         Device driver ID
; Errors................: C         Set on error
;                         A         Error code, ENODEVSPC, EDEVBUSY, EIO
; Preserved registers...: None
; Credits...............: New implementation
.proc device_register
    clc
    rts
.endproc

; *****************************************************************************
; Purpose...............: Unregisters a device driver
; Input.................: X         Driver number

; Output................: None
; Errors................: C         Set on error
;                         A         Error code, EDEVBUSY, EIO
; Preserved registers...: None
; Credits...............: New implementation
.proc device_unregister
    clc
    rts
.endproc


; *****************************************************************************
; Purpose...............: Calls device driver function, used internally
;                         by the kernel
; Input.................: X         Driver number
;                         Y         Function number
;                         A         Primary function argument
;                         r0-13     Additional function arguments
; Output................: Set by driver function
; Errors................: C = 1
; Preserved registers...: None
; Credits...............: New implementation
.proc device_call
    ; Backup A
    pha
    
    ; Check driver flag bits 5-6, where 
    ;   00 = device not present
    ;   01 = Stored in ROM bank 0 or low RAM
    ;   10 = Stored in ROM bank > 0
    ;   11 = Stored in RAM bank
    lda dt_flags,x
    and #$60
    beq not_present
    cmp #$40
    bcs banking_required

no_banking:
    ; Driver number * 2
    txa
    asl
    tax
    
    ; Restore A
    pla

    ; Call driver
    jmp (dt_addr,x)

not_present:
    pla
    sec
    rts
    
banking_required:
    ; TODO: Not yet implemented ...
    pla
    sec
    rts
.endproc
