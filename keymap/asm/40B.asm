; X16 Open Keyboard Table
; *** Auto-generated file ***

; Source:	40B Finnish.klc
; Locale:	fi-FI

.segment "KBDMETA"
	.byte "fi-FI", 0, 0, 0, 0, 0, 0, 0, 0, 0
	.word kbdtab_40B

.segment "KBDTABLES"
kbdtab_40B:
	.incbin "asm/40B.lzsa"
