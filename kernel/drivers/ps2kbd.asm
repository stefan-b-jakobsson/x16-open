; *****************************************************************************
; Copyright 2026 Stefan Jakobsson
;
; Redistribution and use in source and binary forms, with or without 
; modification, are permitted provided that the following conditions are met:
;
; 1. Redistributions of source code must retain the above copyright notice, 
;    this list of conditions and the following disclaimer.
;
; 2. Redistributions in binary form must reproduce the above copyright notice, 
;    this list of conditions and the following disclaimer in the documentation 
;    and/or other materials provided with the distribution.
;
; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
; AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
; IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
; ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE 
; LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
; CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
; SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
; INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
; CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
; ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
; POSSIBILITY OF SUCH DAMAGE.
; *****************************************************************************

.include "regs.inc"
.include "io.inc"
.include "keycode.inc"
.include "keymap.inc"
.include "banks.inc"

; Exports
.export ps2kbd_dispatch

; Imports
.import i2c_read_byte
.import memory_decompress_internal, fetch, fetvec

.segment "K_LRAM"
BUFSIZE = 10
buf: .res BUFSIZE
buf_head: .res 1
buf_tail: .res 1
modifier_state: .res 1
modifier_justified: .res 1
deadkey_index: .res 1

; Modifier keys
MOD_SHIFT       = %00000001
MOD_CTRL        = %00000010
MOD_ALT         = %00000100
MOD_ALTGR       = %00001000
MOD_CAPSLOCK    = %10000000

.CODE

; *****************************************************************************
; Purpose...............: PS/2 keyboard driver dispatch function
; Input.................: X = Driver function ID
; Output................: None
; Preparatory rutines...: None
; Errors................: None
; Preserved registers...: None
; Credits...............: New implementation, not based on previous work
.proc ps2kbd_dispatch
    ; Move Y to X
    phy
    plx

    ; Call sub-function
    jmp (jmp_table,x)
    
jmp_table:
    .word on_register               ; ID 0, on_register
    .word not_implemented           ; ID 2, on_unregister
    .word open                      ; ID 4, open
    .word read_byte                 ; ID 8, read_byte
    .word not_implemented           ; ID 10, read_block
    .word not_implemented           ; ID 12, write_byte
    .word not_implemented           ; ID 14, write_block
    .word not_implemented           ; ID 16, seek
    .word not_implemented           ; ID 18, position
    .word not_implemented           ; ID 20, close
    .word not_implemented           ; ID 22, ioctl
    .word on_irq                    ; ID 24, on_irq
    .word not_implemented           ; ID 26, driver_string
.endproc

; *****************************************************************************
; Purpose...............: Called by Kernel on registering the device
; Input.................: None
; Output................: A     Device driver flags
; Preparatory rutines...: None
; Errors................: None
; Preserved registers...: None
; Credits...............: New implementation, not based on previous work
.proc on_register
    ; Reset keyboard buffer pointers
    stz buf_head
    stz buf_tail

    ; Init keyboard modifier and dead key state
    stz modifier_state
    lda #$ff
    sta deadkey_index

    ; Load first keyboard layout from ROM
    lda #$00
    sta r3
    lda #$c0
    sta r4
    jsr load_layout

    ; Set device flags
    lda #%10000001
    
    ; Exit
    clc
    rts
.endproc

; *****************************************************************************
; Purpose...............: Called by the Kernel when a file is opened using
;                         this device driver. The keyboard driver ignores the
;                         the file path.
; Input.................: None
; Output................: A     Device driver flags
;                         Y     File context ID, always 0
; Preparatory rutines...: None
; Errors................: None
; Preserved registers...: None
; Credits...............: New implementation, not based on previous work
.proc open
    ldy #0 ; File context
    lda #%10001001 ; Flags: for reading + a file, not a directory + opened successfully
    clc
    rts
.endproc

; *****************************************************************************
; Purpose...............: Returns one byte from the keyboard buffer. The 
;                         function returns 0 if no data is available.
; Input.................: A     File context ID, ignored
; Output................: A     Byte value
; Preparatory rutines...: open
; Errors................: None
; Preserved registers...: None
; Credits...............: New implementation, not based on previous work
.proc read_byte
    ; Check if buffer is empty
    ldx buf_head
    cpx buf_tail
    beq empty

    ; Get value
    lda buf,x

    ; Calculate new head position in the ring buffer
    inx
    cpx #BUFSIZE
    bcc exit
    ldx #0
exit:
    stx buf_head
    clc
    rts

empty:
    lda #0
    clc
    rts
.endproc

; *****************************************************************************
; Purpose...............: Called by the Kernel on IRQ
; Input.................: None
; Output................: None
; Preparatory rutines...: open
; Errors................: None
; Preserved registers...: None
; Credits...............: New implementation, not based on previous work
.proc on_irq
    jmp scan_keyboard
.endproc

; *****************************************************************************
; Purpose...............: Loads a new keyboard layout from ROM bank 1
; Input.................: r3-4      Pointer to item in list at $01:c000-c1ff
; Output................: None
; Preparatory rutines...: None
; Errors................: None
; Affected registers....: A, X, Y, P, r0, r1, r2, r3, r8, r9
; Credits...............: New implementation, not based on previous work
.proc load_layout
    KVARS_START

    ; Get layout start address
    ldy #14
    lda #r3
    ldx #1
    jsr fetch
    sta r0
    iny
    lda #r3
    ldx #1
    jsr fetch
    sta r1

    ; Decompress to $00:a000
    stz r2
    lda #$a0
    sta r3
    lda #<fetch_kbd
    sta r8
    lda #>fetch_kbd
    sta r9
    jsr memory_decompress_internal

    KVARS_END
    rts

fetch_kbd:
	php
	phx
	phy
	ldy #0
	ldx #1
	lda #r0
	jsr fetch
	inc r0
	bne :+
	inc r1
:	ply
	plx
	plp
	rts
.endproc

; *****************************************************************************
; Purpose...............: Get a key stroke from the SMC, and, if applicable,
;                         convert it into a character that is stored in the
;                         keyboard ring buffer
; Input.................: None
; Output................: None
; Preparatory rutines...: None
; Errors................: None
; Preserved registers...: None
; Credits...............: New implementation, not based on previous work
.proc scan_keyboard
    ; Fetch key number from the SMC
    ldx #$42 ; I2C address
    ldy #$07 ; SMC function ID
    jsr i2c_read_byte
    bne select_ram_bank

exit:
    rts

select_ram_bank:
    KVARS_START_TRASH_X_NZ

update_modifier:
    ; Store key number on stack
    pha

    ; Filter out key up/down bit
    and #%01111111

    ; Check if it is one of the modifier keys
    ldx #6
update_modifier_lookup:
    cmp modifier_keynum-1,x
    beq update_modifier_match ; It is a modifier key
    dex
    bne update_modifier_lookup
    bra assert_keydown ; no match, continue

update_modifier_match:
    lda modifier_keybit-1,x ; Get modifier key bitmask value
    ply ; Restore key number from stack
    bmi update_modifier_key_up

update_modifier_key_down:
    ora modifier_state
    sta modifier_state
    jmp restore_ram_bank

update_modifier_key_up:
    eor #$ff
    and modifier_state
    sta modifier_state
    jmp restore_ram_bank

assert_keydown:
    ply ; Restore key number from stack
    bpl toggle_capslock
    jmp restore_ram_bank

toggle_capslock:
    cpy #KEYCODE_CAPSLOCK ; Check if Caps Lock key number
    bne assert_buffer_not_full ; No, continue
    lda modifier_state ; Yes, toggle Caps Lock state
    eor #MOD_CAPSLOCK ; Toggle bit
    sta modifier_state
    jmp restore_ram_bank

assert_buffer_not_full:
    ; Calculate next ring buffer tail
    lda buf_tail ; Get current tail
    inc
    cmp #BUFSIZE ; Check if less than buffer size
    bcc :+
    lda #0 ; Wrap around to 0
:   cmp buf_head ; Check if next tail is same as head = buffer full
    bne :+
    jmp restore_ram_bank
:   pha ; Store next tail on stack

apply_capslock:
    ; Is Caps Lock active?
    lda modifier_state
    sta modifier_justified ; Holds modifier state after Caps Lock effect has been applied
    bpl lookup_char ; No, continue

    ; Get index of key number in the layout's Caps Lock table (= Key Number / 8)
    tya ; Key number
    lsr
    lsr
    lsr
    tax

    ; Check if AltGr is pressed
    lda modifier_justified
    and #MOD_ALTGR
    bne :+
    lda KEYMAP_CAPSREG,x ; No, get regular Caps Lock flags byte
    bra :++
:   lda KEYMAP_CAPSALTGR,x ; Yes, get AltGr Caps Lock flags byte

:   ; Get key number bits 0-2
    pha ; Store flags byte on stack
    tya ; Key number
    and #7
    tax

    ; Keep only current key number bit
    pla ; Restore flags byte
    and bitmask,x

    ; Ignore Caps Lock if bit is clear ...
    beq lookup_char
    
    ; ... else toggle Shift key
    lda modifier_justified
    eor #MOD_SHIFT
    sta modifier_justified

lookup_char:
    ; Get modifier state after possible Caps Lock effect
    lda modifier_justified

    ; Keep only Shift, Control, Alt, and AltGr bits
    and #(MOD_SHIFT | MOD_CTRL | MOD_ALT | MOD_ALTGR)
    sta modifier_justified

    ; Select get char function
    beq regular
    cmp #MOD_SHIFT
    beq shift
    cmp #MOD_CTRL
    beq control
    cmp #MOD_ALT
    beq alt
    cmp #MOD_ALTGR
    beq altgr
    cmp #(MOD_SHIFT | MOD_ALTGR)
    beq shift_altgr

exit2:
    ; Unsupported state, exit
    pla ; Restore stack
    bra restore_ram_bank

regular:
    lda KEYMAP_REGTBL,y
    bra apply_deadkey
shift:
    lda KEYMAP_SHFTTBL,y
    bra apply_deadkey
control:
    lda KEYMAP_CTRLTBL,y
    bra apply_deadkey
alt:
    lda KEYMAP_ALTTBL,y
    bra apply_deadkey
altgr:
    lda KEYMAP_ALTGRTBL,y
    bra apply_deadkey
shift_altgr:
    lda KEYMAP_SHFTALTGRTBL,y

apply_deadkey:
    ; Check if previous key was a dead key
    ldx deadkey_index
    cpx #$ff
    beq lookup_deadkey ; No, continue

    ; It was a dead key, now search the list of key combinations
    ldy KEYMAP_DK_INDEX+1,x ; Start index of next dead key group
    sty deadkey_index
    ldy KEYMAP_DK_INDEX,x ; Start index of this dead key group
    
:   ; Search dead key table for matching 2nd key
    cmp KEYMAP_DK_SECOND,y
    beq apply_deadkey_match
    iny
    cpy deadkey_index
    bne :-

    ; No match, clear deadkey index and exit
    lda #$ff
    sta deadkey_index
    bra exit2

apply_deadkey_match:
    ; Clear deadkey
    lda #$ff
    sta deadkey_index

    ; Get output char from dead key table
    lda KEYMAP_DK_OUT,y
    bra put_char

lookup_deadkey:
    ; Check if the new key is a dead key
    cmp #0
    bne put_char ; No, all dead keys return 0
    
    ldx #0
lookup_deadkey_loop:
    ; Search dead key table
    tya ; Key number
    cmp KEYMAP_DK_NUM,x
    bne lookup_deadkey_next
    lda modifier_justified
    cmp KEYMAP_DK_MOD,x
    beq lookup_deadkey_match

lookup_deadkey_next:
    inx
    cpx KEYMAP_DK_COUNT
    bcc lookup_deadkey_loop
    bra exit2

lookup_deadkey_match:
    stx deadkey_index
    bra exit2

put_char:
    ldx buf_tail ; Get current tail
    sta buf,x ; Store in buffer
    plx ; Get new tail from stack
    stx buf_tail ; And store it

restore_ram_bank:
    KVARS_END
    rts
.endproc

.proc not_implemented
    clc
    rts
.endproc

modifier_keynum:
    .byt KEYCODE_LSHIFT, KEYCODE_RSHIFT, KEYCODE_LCTRL, KEYCODE_RCTRL, KEYCODE_LALT, KEYCODE_RALT
modifier_keybit:
    .byt MOD_SHIFT, MOD_SHIFT, MOD_CTRL, MOD_CTRL, MOD_ALT, MOD_ALTGR
bitmask:
    .byt 1, 2, 4, 8, 16, 32, 64, 128
