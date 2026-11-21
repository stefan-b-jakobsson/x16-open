; X16 Open Keyboard Table
; *** Auto-generated file ***

; Source:	816 Portuguese.klc
; Locale:	pt-PT

.segment "KBDMETA"
	.byte "pt-PT", 0, 0, 0, 0, 0, 0, 0, 0, 0
	.word kbdtab_816

.segment "KBDTABLES"
kbdtab_816:
	.incbin "asm/816.lzsa"
