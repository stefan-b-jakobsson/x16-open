.include "regs.inc"

; Exports
.export shell_main

; Imports
.import device_call, stdin_read, stdout_write
.import sys_info

.proc shell_main
    ; Print hello
    jsr sys_info
    ldy #0
:   lda (r3),y
    beq :+
    jsr stdout_write
    iny
    bne :-

loop:
    ; Get key from STDIN
    jsr stdin_read
    cmp #0
    beq :+

    ; Output char to STDOUT
    jsr stdout_write

:   wai
    bra loop
.endproc
