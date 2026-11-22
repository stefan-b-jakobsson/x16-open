; ROM banks
BANK_KERNAL  = $00
BANK_KEYBD   = $01
BANK_FONT    = $02

; *****************************************************************************
; Purpose...............: These macros are used to safely set the Kernel's
;                         RAM bank (0) and restore the original RAM bank
;                         on exiting a Kernel function.
; Credits...............: Originally implemented in X16-rom
;                         Copyright Michael Steil and others, 2-clause BSD
.macro KVARS_START
.import kvswitch_tmp1, kvswitch_tmp2
	php
	sei
	sta kvswitch_tmp1
	pla
	sta kvswitch_tmp2
	lda ram_bank
	pha
	stz ram_bank
	lda kvswitch_tmp2
	pha
	lda kvswitch_tmp1
	plp
.endmacro

.macro KVARS_END
	php
	sei
	sta kvswitch_tmp1
	pla
	sta kvswitch_tmp2
	pla
	sta ram_bank
	lda kvswitch_tmp2
	pha
	lda kvswitch_tmp1
	plp
.endmacro

.macro KVARS_START_TRASH_A_NZ
.import kvswitch_tmp1, kvswitch_tmp2
	lda ram_bank
	pha
	stz ram_bank
.endmacro

.macro KVARS_END_TRASH_A_NZ
	pla
	sta ram_bank
.endmacro

.macro KVARS_START_TRASH_X_NZ
.import kvswitch_tmp1, kvswitch_tmp2
	ldx ram_bank
	phx
	stz ram_bank
.endmacro

.macro KVARS_END_TRASH_X_NZ
	plx
	stx ram_bank
.endmacro
