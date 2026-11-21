; X16 Open Keyboard Table
; *** Auto-generated file ***

; Source:	40C French.klc
; Locale:	fr-FR

.segment "KBDMETA"
	.byte "fr-FR", 0, 0, 0, 0, 0, 0, 0, 0, 0
	.word kbdtab_40C

.segment "KBDTABLES"
kbdtab_40C:
	.incbin "asm/40C.lzsa"
