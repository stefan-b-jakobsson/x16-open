.import __K_FETCH_LOAD__, __K_FETCH_RUN__, __K_FETCH_SIZE__

.include "io.inc"
.include "regs.inc"

.export fetch_init, fetch, fetvec

.CODE
; *****************************************************************************
; Purpose...............: Initialize fetch function, copies RAM code
; Input.................: None
; Output................: None
; Preparatory rutines...: None
; Errors................: None
; Registers affected....: A, X, P
; Credits...............: New implementation
.proc fetch_init
    ldx #<__K_FETCH_SIZE__
:   lda __K_FETCH_LOAD__-1,x
    sta __K_FETCH_RUN__-1,x
    dex
    bne :-
    rts
.endproc

; *****************************************************************************
; Purpose...............: Fetches a byte value from another RAM or ROM bank
;					      using a zero-page register
; Input.................: A     Zero-page register
;                         Y     Address offset
;                         X     RAM or ROM bank
; Output................: A		Value
; Preparatory rutines...: None
; Errors................: None
; Registers affected....: A, X, P
; Credits...............: This code is based on the X16-rom stash function,
;                         (c) 2019 Michael Steil, License: 2-clause BSD
.proc fetch
	sta fetvec
    lda ram_bank    ;save current config (RAM)
	pha
	lda rom_bank    ;save current config (ROM)
	pha
	txa
	sta ram_bank    ;set RAM bank
	plx             ;original ROM bank
	php
	sei
	jsr fetch2
	plp
	plx
	stx ram_bank    ;restore RAM bank
	ora #0          ;set flags
	rts
.endproc

.segment "K_FETCH"
fetch2:
    sta rom_bank    ;set new ROM bank
    fetvec = *+1
	lda ($ff),y     ;get the byte ($ff here is a dummy address, 'FETVEC')
	stx rom_bank    ;restore ROM bank
	rts

