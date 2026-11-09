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
.include "device.inc"
.include "file.inc"
.include "error.inc"

; Exports
.export device_init, device_register, device_unregister, device_call, device_on_irq

; Imports
.import ft_flags, ft_driver
.import terminal_dispatch
.import ps2kbd_dispatch
.import file_open

; *****************************************************************************
; Global device table
.segment "K_LRAM"
dt_addr:    .res DRIVER_COUNT*2
dt_bank:    .res DRIVER_COUNT
dt_flags:   .res DRIVER_COUNT

.CODE
; *****************************************************************************
; Purpose...............: Initializes the device table and registers the
;                         core device drivers:
;                         0: Terminal driver
;                         1: I2C driver
;                         2: PS/2 keyboard driver
;                         3: PS/2 mouse driver
;                         4: SNES controller driver
;                         5: Built-in SD card driver
; Input.................: None
; Output................: None
; Errors................: C         Set on error
;                         A         Error code, ENODEVSPC, EDEVBUSY, EIO
; Registers affected:...: A, X, Y, P
; Credits...............: New implementation
.proc device_init
    ; Disable interrupts
    php
    sei

    ; Clear device table
    lda #0
    ldx #DRIVER_COUNT
:   sta dt_flags-1,x
    dex
    bne :-

    ; Register terminal device driver
    lda #<terminal_dispatch
    sta r0
    lda #>terminal_dispatch
    sta r1
    stz r2
    ldx #DEVICE_TERMINAL
    jsr device_register
    bcs err

    ; Register I2C device driver
    ; TODO...

    ; Register PS/2 keyboard device driver
    lda #<ps2kbd_dispatch
    sta r0
    lda #>ps2kbd_dispatch
    sta r1
    stz r2
    ldx #DEVICE_KEYBOARD
    jsr device_register
    bcs err

    ; Register PS/2 mouse device driver
    ; TODO...

    ; Register SNES game controller device driver
    ; TODO...

    ; Register SD card device driver
    ; TODO...

exit:
    plp ; Restore IRQ
    clc
    rts

err:
    plp ; Restore IRQ
    sec
    rts
.endproc

; *****************************************************************************
; Purpose...............: Registers a device driver
; Input.................: X         Device driver
;                         r0-1      Driver address
;                         r2        Driver bank
; Output................: X         Device driver
; Errors................: C         Set on error
;                         A         Error code, ENODEVSPC, EINVAL, EDEVBUSY, EIO
; Registers affected....: A, X, Y, P
; Credits...............: New implementation
.proc device_register
    ; If X = $ff, then find next available ID, else try to register the specified ID
    cpx #$ff
    bne check_valid

    ; Find next available
    ldx #0
loop:
    lda dt_flags,x
    and #$60
    beq register
    inx
    cpx #DRIVER_COUNT
    bcs err_toomany
    bra loop

check_valid:
    cpx #DRIVER_COUNT
    bcs err_invalid

check_busy:
    lda dt_flags,x
    and #$60
    bne err_busy

register:
    ; Set bank
    lda r2
    sta dt_bank,x

    ; Set location
    ldy r1 ; Get addrH
    lda #$20 ; Flag value for low RAM and ROM bank 0
    cpy #$a0 ; Check if low RAM...
    bcc set_location ; ...Yes
    cpy #$c0 ; Check if banked RAM...
    bcc bram ; ...Yes

rom:
    ldy r2 ; Get ROM bank
    beq set_location ; In ROM bank 0, go ahead
    lda #$40 ; Else select flag for ROM bank > 0
    bra set_location

bram:
    lda #$60 ; Select flag for banked RAM

set_location:
    sta dt_flags,x

set_addr:
    phx ; Store driver ID on stack
    
    txa ; Move driver ID to A
    asl ; Multiply by 2
    tax ; Move driver ID back to X
    lda r0 ; Store addrL
    sta dt_addr,x
    lda r1 ; Store addrH
    sta dt_addr+1,x
    plx ; Retrieve driver ID from stack

    ; Call driver's on_register function
    ldy #DRIVER_ON_REGISTER
    phx ; Store driver ID on stack
    jsr device_call
    bcs err_driver

    ; Set flags returned from driver
    plx
    and #$9f ; Ensure location bits (5-6) are not changed by the driver
    ora dt_flags,x
    sta dt_flags,x

    ; Exit
    clc
    rts

err_toomany:
    ; Too many devices
    lda #ENODEVSPC
    bra err

err_invalid:
    ; Invalid driver ID
    lda #EINVAL
    bra err

err_busy:
    ; Device ID is already used
    lda #EDEVBUSY

err_driver:
    ; Driver error
    plx
    pha
    lda #0
    sta dt_flags,x
    pla

err:
    sec
    rts
.endproc

; *****************************************************************************
; Purpose...............: Unregisters a device driver
; Input.................: X         Device driver ID
; Output................: None
; Errors................: C         Set on error
;                         A         Error code, EINVAL, ENODEV, EDEVBUSY, EIO
; Registers affected....: A, Y, P
; Credits...............: New implementation
.proc device_unregister
    ; Verify device driver ID
    cpx #DRIVER_COUNT
    bcs err_invalid

    ; Verify driver present
    lda dt_flags,x
    and #%01100000
    beq err_notpresent

    ; Check if used by on open file
    ldy #FILE_COUNT
:   lda ft_flags-1,y
    bpl :+
    txa
    cmp ft_driver,y
    beq err_busy
:   dey
    bne :--

    ; Backup device driver ID
    phx

    ; Call driver's on_unregister function
    ldy #DRIVER_ON_UNREGISTER
    jsr device_call
    bcs err_driver

    ; Remove device from table
    plx
    lda #0
    sta dt_flags,x

    ; Exit
    rts

err_invalid:
    lda #EINVAL
    bra err

err_notpresent:
    lda #ENODEV
    bra err

err_busy:
    lda #EDEVBUSY
    bra err

err_driver:
    ; Restore stack
    plx

err:
    sec
    rts
.endproc


; *****************************************************************************
; Purpose...............: Calls device driver function, used internally
;                         by the kernel
; Input.................: X         Driver ID
;                         Y         Driver function index
;                         A         Primary function argument
;                         r0-13     Additional function arguments
; Output................: Set by driver function
; Errors................: C         Set on error
;                         A         Error code, as specified by the selected
;                                   driver function
; Registers affected....: A, X, Y, P
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
    ; Calculate Driver ID x 2, needed to reference the device table's address word
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

; *****************************************************************************
; Purpose...............: Calls on_irq function of all registered devices
;                         that have flag bit 7 set in the device table
; Input.................: None
; Output................: None
; Errors................: None
; Registers affected....: A, X, Y, P
; Credits...............: New implementation
.proc device_on_irq
    ldx #0

loop:
    lda dt_flags,x
    bpl next ; Bit 7 clear, select next driver
    phx
    ldy #DRIVER_ON_IRQ
    jsr device_call
    plx

next:
    inx
    cpx #DRIVER_COUNT
    bcc loop

    rts
.endproc
