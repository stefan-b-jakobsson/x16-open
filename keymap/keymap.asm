.segment "KBDMETA"

.include "asm/99409.asm"  ; United States-Extended (Mac)
.include "asm/20409.asm"  ; United States-International (Win)
.include "asm/809.asm"    ; United Kingdom
.include "asm/41D.asm"    ; Swedish
.include "asm/407.asm"    ; German
.include "asm/406.asm"    ; Danish
.include "asm/410.asm"    ; Italian
.include "asm/415.asm"    ; Polish (Programmers)
.include "asm/414.asm"    ; Norwegian
.include "asm/40E.asm"    ; Hungarian
.include "asm/40A.asm"    ; Spanish
.include "asm/40B.asm"    ; Finnish
.include "asm/416.asm"    ; Portuguese (Brazil ABNT)
.include "asm/405.asm"    ; Czech
.include "asm/40C.asm"    ; French
.include "asm/807.asm"    ; Swiss German
.include "asm/10409.asm"  ; Dvorak
.include "asm/425.asm"    ; Estonian
.include "asm/80C.asm"    ; Belgian French
.include "asm/1009.asm"   ; Canadian French
.include "asm/40F.asm"    ; Icelandic
.include "asm/816.asm"    ; Portuguese
.include "asm/41A.asm"    ; Croatian
.include "asm/41B.asm"    ; Slovak
.include "asm/424.asm"    ; Slovenian
.include "asm/426.asm"    ; Latvian
.include "asm/427.asm"    ; Lithuanian IBM

.segment "KBDMETA"
	; terminator, fills out the 31 "metadata" slots.
	; if another layout is added above, remove one of these
	.byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	.byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	.byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	.byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	.byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
