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

; Imports
.import on_reset
.import alloc, free
.import device_register, device_unregister
.import file_open, file_read_byte, file_read_block, file_write_byte, file_write_block
.import file_seek, file_position, file_close, file_ioctl
.import std_set, std_get, stdin_read, stdout_write
.import get_ticks, set_ticks, get_errmsg, set_errmsg, sys_info

.segment "K_JMPTBL"

.assert *= $c003, error, "Kernel jump table must start at $c003"

jmp on_reset            ; $c003
jmp alloc               ; $c006
jmp free                ; $c009
jmp device_register     ; $c00c
jmp device_unregister   ; $c00f
jmp file_open           ; $c012
jmp file_read_byte      ; $c015
jmp file_read_block     ; $c018
jmp file_write_byte     ; $c01b
jmp file_write_block    ; $c01e
jmp file_seek           ; $c021
jmp file_position       ; $c024
jmp file_close          ; $c027
jmp file_ioctl          ; $c02a
jmp std_set             ; $c02d
jmp std_get             ; $c030
jmp stdin_read          ; $c033
jmp stdout_write        ; $c036
jmp get_ticks           ; $c039
jmp set_ticks           ; $c03c
jmp get_errmsg          ; $c03f
jmp set_errmsg          ; $c042
jmp sys_info            ; $c045

