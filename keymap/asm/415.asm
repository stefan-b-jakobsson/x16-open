; X16 Open Keyboard Table
; *** Auto-generated file ***

; Source:	415 Polish (Programmers).klc
; Locale:	pl-PL

.segment "KBDMETA"
	.byte "pl-PL", 0, 0, 0, 0, 0, 0, 0, 0, 0
	.word kbdtab_415

.segment "KBDTABLES"
kbdtab_415:
	.incbin "asm/415.lzsa"
