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

; Exports
.export irq_init, on_irq_request, irq_default_handler, irq_exit

; Imports
.import __K_IRQ_LOAD__, __K_IRQ_RUN__, __K_IRQ_SIZE__
.import device_call, device_on_irq
.import tick

irq_vector = $0314

.CODE

; *****************************************************************************
; Purpose...............: Initializes IRQ; copying IRQ handler RAM part,
;                         setting up the IRQ vector and activates the IRQ
;                         flag
; Input.................: None
; Output................: None
; Preparatory rutines...: Before calling this function, disable IRQs with the
;                         CLI instruction
; Errors................: None
; Preserved registers...: None
; Credits...............: New implementation
.proc irq_init
    ; Copy the IRQ handler RAM part (IRQ exit)
    ldx #<__K_IRQ_SIZE__
:   lda __K_IRQ_LOAD__-1,x
    sta __K_IRQ_RUN__-1,x
    dex
    bne :-

    ; Setup the IRQ vector
    lda #<irq_default_handler
    sta irq_vector
    lda #>irq_default_handler
    sta irq_vector+1

    ; Enable IRQ on VSYNC
    lda #1
    sta VERA_IEN
    lda #1
    sta VERA_ISR

    rts
.endproc

; *****************************************************************************
; Purpose...............: Target for the hardware IRQ vector ($fffe)
; Input.................: None
; Output................: None
; Preparatory rutines...: None
; Errors................: None
; Preserved registers...: None
; Credits...............: New implementation
.proc on_irq_request
    ; Backup registers, status register backup up by the hardware
    pha
    phx
    phy

    ; Backup ROM bank
    lda rom_bank
    pha

    ; Select Kernal ROM bank
    stz rom_bank

    ; Call IRQ vector
    jmp (irq_vector)
.endproc

; *****************************************************************************
; Purpose...............: Default IRQ handler
; Input.................: None
; Output................: None
; Preparatory rutines...: None
; Errors................: None
; Preserved registers...: None
; Credits...............: New implementation
.proc irq_default_handler
    ; Device IRQ functions
    jsr device_on_irq

    ; Increment jiffy clock
    jsr tick
    
    ; Clear IRQ flag
    lda #1
    sta VERA_ISR

    jmp irq_exit
.endproc

; *****************************************************************************
; Purpose...............: Default IRQ handler - RAM part
; Input.................: None
; Output................: None
; Preparatory rutines...: None
; Errors................: None
; Preserved registers...: None
; Credits...............: New implementation, not based on previous work
.segment "K_IRQ"
.proc irq_exit
    ; Restore ROM bank
    pla
    sta rom_bank

    ; Restore registers
    ply
    plx
    pla

    ; Return
    rti
.endproc
