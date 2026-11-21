; X16 Open Keyboard Table
; *** Auto-generated file ***

; Source:	41B Slovak.klc
; Locale:	sk-SK

.segment "KBDMETA"
	.byte "sk-SK", 0, 0, 0, 0, 0, 0, 0, 0, 0
	.word kbdtab_41B

.segment "KBDTABLES"
kbdtab_41B:
	.incbin "asm/41B.lzsa"
