; X16 Open Keyboard Table
; *** Auto-generated file ***

; Source:	80C Belgian French.klc
; Locale:	fr-BE

.segment "KBDMETA"
	.byte "fr-BE", 0, 0, 0, 0, 0, 0, 0, 0, 0
	.word kbdtab_80C

.segment "KBDTABLES"
kbdtab_80C:
	.incbin "asm/80C.lzsa"
