.include "regs.inc"
.include "device.inc"
.include "io.inc"

; Exports
.export shell_main

; Imports
.import device_call, stdin_read, stdout_write, file_read_byte
.import sys_info

; *****************************************************************************
; Purpose...............: Shell main function
; Input.................: None
; Output................: None
; Preparatory routines..: None
; Errors................: None
; Preserved registers...: None
; Credits...............: New implementation
.proc shell_main
    ; Print welcome message
    jsr sys_info
    ldy #0
:   lda (r3),y
    beq init
    jsr stdout_write
    iny
    bne :-

init:
    stz ram_bank
    stz buf_index
loop:
    jsr stdin_read
    cmp #0
    beq eol
    ldx buf_index
    sta linebuf,x
    inc buf_index
    bra loop
    
eol:
    jsr line_parser
    stz buf_index
    bra loop
.endproc

; *****************************************************************************
; Purpose...............: Line parser
; Input.................: None
; Output................: A     Command index, or $ff if unknown command
; Preparatory routines..: None
; Errors................: None
; Preserved registers...: None
; Credits...............: New implementation
.proc line_parser
    stz temp    ; Command index
    ldx #0
    ldy #0
loop:
    lda cmdlist,x
    beq possible_match
    cmp linebuf,y
    bne nextcmd
    inx
    iny
    bra loop

possible_match:
    lda linebuf,y
    beq match_verified
    cmp #32
    bne nextcmd2

match_verified:
    iny
    lda temp
    asl
    tax
    jmp (jmptable,x)

command_return:
    lda temp
    rts

nextcmd:
    inc temp
:   inx
    lda cmdlist,x
    bne :-
nextcmd2:
    ldy #0
    inx
    lda cmdlist,x
    bne loop
    
nomatch:
    lda #$ff
    rts

cmdlist:
    .byt "basic", 0
    .byt "cd", 0
    .byt "echo", 0
    .byt "ls", 0
    .byt "mkdir", 0
    .byt "mount", 0
    .byt "mv", 0
    .byt "rm", 0
    .byt "rmdir", 0
    .byt "umount", 0
    .byt 0

jmptable:
    .word cmd_basic
    .word cmd_cd
    .word cmd_echo
    .word cmd_ls
    .word cmd_mkdir
    .word cmd_mount
    .word cmd_mv
    .word cmd_rm
    .word cmd_rmdir
    .word cmd_umount

.endproc

.proc cmd_basic
    ldx #0
:   lda msg,x
    beq getresponse
    jsr stdout_write
    inx
    bra :-

getresponse:
    ldx #21
:   jsr stdin_read
    dex
    bne :-
    cmp #'Y'
    bne exit

    ldx #0
:   lda msg2,x
    beq exit
    jsr stdout_write
    inx
    bra :-

exit:
    jmp line_parser::command_return

msg:
    .byt "Are you sure (Y/N)? ",0

msg2:
    .byt 13, "Starting BASIC", 13, 0
.endproc

.proc cmd_cd
    jsr nyi
    jmp line_parser::command_return
.endproc

.proc cmd_echo
    lda linebuf,y
    beq exit
    jsr stdout_write
    iny
    cpy #80
    bne cmd_echo

exit:
    lda #13
    jsr stdout_write
    jmp line_parser::command_return
.endproc

.proc cmd_ls
    jsr nyi
    jmp line_parser::command_return
.endproc

.proc cmd_mkdir
    jsr nyi
    jmp line_parser::command_return
.endproc

.proc cmd_mount
    jsr nyi
    jmp line_parser::command_return
.endproc

.proc cmd_mv
    jsr nyi
    jmp line_parser::command_return
.endproc

.proc cmd_rm
    jsr nyi
    jmp line_parser::command_return
.endproc

.proc cmd_rmdir
    jsr nyi
    jmp line_parser::command_return
.endproc

.proc cmd_umount
    jsr nyi
    jmp line_parser::command_return
.endproc

.proc nyi
    ldx #0
:   lda msg,x
    beq exit
    jsr stdout_write
    inx
    bra :-
exit:
    rts

msg:
    .byt "Command not yet implemented", 13, 0
.endproc

.segment "K_BRAM"
    linebuf: .res 81
    buf_index: .res 1
    temp: .res 2
