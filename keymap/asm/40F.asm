; X16 Open Keyboard Table
; *** Auto-generated file ***

; Source:	40F Icelandic.klc
; Locale:	is-IS

.segment "KBDMETA"
	.byte "is-IS", 0, 0, 0, 0, 0, 0, 0, 0, 0
	.word kbdtab_40F

.segment "KBDTABLES"
kbdtab_40F:
	.incbin "asm/40F.lzsa"
