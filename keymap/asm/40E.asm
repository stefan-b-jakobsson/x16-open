; X16 Open Keyboard Table
; *** Auto-generated file ***

; Source:	40E Hungarian.klc
; Locale:	hu-HU

.segment "KBDMETA"
	.byte "hu-HU", 0, 0, 0, 0, 0, 0, 0, 0, 0
	.word kbdtab_40E

.segment "KBDTABLES"
kbdtab_40E:
	.incbin "asm/40E.lzsa"
