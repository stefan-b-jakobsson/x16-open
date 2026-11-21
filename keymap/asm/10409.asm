; X16 Open Keyboard Table
; *** Auto-generated file ***

; Source:	10409 United States-Dvorak.klc
; Locale:	en-US/Dvorak

.segment "KBDMETA"
	.byte "en-US/Dvorak", 0, 0
	.word kbdtab_10409

.segment "KBDTABLES"
kbdtab_10409:
	.incbin "asm/10409.lzsa"
