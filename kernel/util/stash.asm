.segment "MEMDRV"

; Includes
.include "io.inc"

; Exports
.export stash_init, set_stavec, stash

; Imports
.import __K_STASH_SIZE__, __K_STASH_LOAD__, __K_STASH_RUN__

.CODE
; *****************************************************************************
; Purpose...............: Initialize stash function, copies RAM code
; Input.................: None
; Output................: None
; Preparatory rutines...: None
; Errors................: None
; Registers affected....: A, X, P
; Credits...............: New implementation
.proc stash_init
    ldx #<__K_STASH_SIZE__
:   lda __K_STASH_LOAD__-1,x
    sta __K_STASH_RUN__-1,x
    dex
    bne :-
    rts
.endproc

; *****************************************************************************
; Purpose...............: Set stash zero page vector
; Input.................: A     Stash vector in zero-page
; Output................: None
; Preparatory rutines...: None
; Errors................: None
; Registers affected....: None
; Credits...............: New implementation
.proc set_stavec
    sta stavec
    rts
.endproc

; *****************************************************************************
; Purpose...............: Stores a byte value in another RAM or ROM bank, the
;                         latter relevant if RAM is placed in the ROM address
;                         range, for instance in a cartridge. The target
;                         address is (stavec) + Y.
; Input.................: A     Byte value
;                         Y     Address offset
;                         X     RAM or ROM bank
; Output................: None
; Preparatory rutines...: set_stavec
; Errors................: None
; Registers affected....: X, P
; Credits...............: This code is based on the X16-rom stash function,
;                         (c) 2019 Michael Steil, License: 2-clause BSD
.proc stash
    pha             ; Save input
	lda ram_bank    ; Save current RAM bank
	pha
	stx ram_bank    ; Set RAM bank
	jmp stash_ram
.endproc

.segment "K_STASH"
stash_ram:
    lda rom_bank
    pha
    stx rom_bank
    tsx
    lda $0103,x ; Get value from SP-3
stavec = *+1
	sta ($ff),y     ;put the byte ($ff here is a dummy address, 'STAVEC')
	plx
    stx rom_bank
    plx
    stx ram_bank
    pla ; Restore stack
	rts
;*** End of stash *************************************************************
