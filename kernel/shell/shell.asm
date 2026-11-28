.include "regs.inc"
.include "device.inc"

; Exports
.export shell_main

; Imports
.import device_call, stdin_read, stdout_write, file_read_byte
.import sys_info

.proc shell_main
    ; Print hello
    jsr sys_info
    ldy #0
:   lda (r3),y
    beq loop
    jsr stdout_write
    iny
    bne :-

    ldx #0
loop:
    phx
    jsr stdin_read
    plx
    stz $00
    sta $b000,x
    inx
    cmp #0
    bne loop
    
    .byt $db
    ldx #0
    bra loop
.endproc
