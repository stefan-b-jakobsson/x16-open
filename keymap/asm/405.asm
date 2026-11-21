; X16 Open Keyboard Table
; *** Auto-generated file ***

; Source:	405 Czech.klc
; Locale:	cs-CZ

.segment "KBDMETA"
	.byte "cs-CZ", 0, 0, 0, 0, 0, 0, 0, 0, 0
	.word kbdtab_405

.segment "KBDTABLES"
kbdtab_405:
	.incbin "asm/405.lzsa"
