; X16 Open Keyboard Table
; *** Auto-generated file ***

; Source:	425 Estonian.klc
; Locale:	et-EE

.segment "KBDMETA"
	.byte "et-EE", 0, 0, 0, 0, 0, 0, 0, 0, 0
	.word kbdtab_425

.segment "KBDTABLES"
kbdtab_425:
	.incbin "asm/425.lzsa"
