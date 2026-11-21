.include "io.inc"

.export jmpfr, jsrfar_init, jsrfar

.import __K_JSRFAR_LOAD__, __K_JSRFAR_RUN__, __K_JSRFAR_SIZE__

imparm = $80

.CODE

; *****************************************************************************
; Purpose...............: Initialize jsrfar function, copies RAM code
; Input.................: None
; Output................: None
; Preparatory rutines...: None
; Errors................: None
; Registers affected....: A, X, P
; Credits...............: New implementation
.proc jsrfar_init
	ldx #<__K_JSRFAR_SIZE__
:   lda __K_JSRFAR_LOAD__-1,x
    sta __K_JSRFAR_RUN__-1,x
    dex
    bne :-
    rts
.endproc

; *****************************************************************************
; Purpose...............: jsrfar utility
; Input.................: None, but a return address must be stored on the
;						  stack as when using the JSR instruction.
;						  At the return address this function expects to find
;					 	  the target address and bank to be called.
;						  Example calling $c000 in bank 2:
;							jsr jsrfar
;						 	.word $c000
;							.byte 2
;							; Execution continues here after jsrfar
; Output................: Output is set by the function that was called
; Preparatory rutines...: None
; Errors................: None
; Registers affected....: None, but the function called can affect registers 
; Credits...............: Based on implementation in X16-rom,
;						  Copyright 2019-2025 Commander Computers LLC, 
;						  Michael Steil, and others. BSD 2-clause license.
jsrfar:
	.include "jsrfar.inc"

.segment "K_JSRFAR"
__jsrfar3:
	sta rom_bank    ;set ROM bank
	pla
	plp
	jsr jmpfr
	php
	pha
	phx
	tsx
	lda $0104,x
	sta rom_bank    ;restore ROM bank
	lda $0103,x     ;overwrite reserved byte...
	sta $0104,x     ;...with copy of .p
	plx
	pla
	plp
	plp
	rts
__jmpfr:
	jmp $ffff
