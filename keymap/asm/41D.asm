; X16 Open Keyboard Table
; *** Auto-generated file ***

; Source:	41D Swedish.klc
; Locale:	sv-SE

.segment "KBDMETA"
	.byte "sv-SE", 0, 0, 0, 0, 0, 0, 0, 0, 0
	.word kbdtab_41D

.segment "KBDTABLES"
kbdtab_41D:
	.incbin "asm/41D.lzsa"
