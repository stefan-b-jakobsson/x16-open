; X16 Open Keyboard Table
; *** Auto-generated file ***

; Source:	40A Spanish.klc
; Locale:	es-ES

.segment "KBDMETA"
	.byte "es-ES", 0, 0, 0, 0, 0, 0, 0, 0, 0
	.word kbdtab_40A

.segment "KBDTABLES"
kbdtab_40A:
	.incbin "asm/40A.lzsa"
