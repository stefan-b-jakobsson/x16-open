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

; Exports
.export get_ticks, set_ticks
.export get_errmsg, set_errmsg
.export sys_info

; *****************************************************************************
; Purpose...............: Returns the jiffy clock counter
; Input.................: None
; Output................: r0-2    Tick counter
; Preparatory rutines...: None
; Errors................: None
; Preserved registers...: None
; Credits...............: New implementation
.proc get_ticks
    ; TODO: Fix this
    rts
.endproc

; *****************************************************************************
; Purpose...............: Sets the jiffy clock counter
; Input.................: r0-2    Tick counter
; Output................: None
; Preparatory rutines...: None
; Errors................: None
; Preserved registers...: None
; Credits...............: New implementation
.proc set_ticks
    ; TODO: Fix this
    rts
.endproc

; *****************************************************************************
; Purpose...............: Get last error message
; Input.................: None
; Output................: A         Error number
;                         r0-1      Error message address
;                         r2        Error message bank
; Preparatory rutines...: None
; Errors................: None
; Preserved registers...: None
; Credits...............: New implementation
.proc get_errmsg
    ; TODO: Fix this
    rts
.endproc

; *****************************************************************************
; Purpose...............: Set error message
; Input ................: A         Error number
;                         r0-1      Error message address
;                         r2        Error message bank
; Output................: None
; Preparatory rutines...: None
; Errors................: None
; Preserved registers...: None
; Credits...............: New implementation
.proc set_errmsg
    ; TODO: Fix this
    rts
.endproc

; *****************************************************************************
; Purpose...............: Returns system information
; Input ................: None
; Output................: r0-2      Kernel version (major, minor, patch)
;                         r3-4      String buffer address
;                         r5        String buffer bank
; Preparatory rutines...: None
; Errors................: None
; Preserved registers...: None
; Credits...............: New implementation
.proc sys_info
    ; TODO: Fix this
    rts
.endproc
