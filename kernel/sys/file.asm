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
.include "device.inc"
.include "file.inc"
.include "error.inc"

; Exports
.export file_open, file_dup, file_close
.export file_read_byte, file_read_block, stdin_read
.export file_write_byte, file_write_block, stdout_write
.export file_seek, file_position
.export file_ioctl
.export ft_driver, ft_context, ft_flags

; Imports
.import device_call

; *****************************************************************************
; Kernel file table
.segment "K_LRAM"
ft_driver:      .res FILE_HANDLES_COUNT
ft_context:     .res FILE_HANDLES_COUNT
ft_flags:       .res FILE_HANDLES_COUNT

.CODE
; *****************************************************************************
; Purpose...............: Opens a file
; Input.................: X         File handle or $ff to request next available
;                         Y         Device driver ID
;                         A         Flags
;                         r0-1      Path address
;                         r2        Path bank
; Output................: X         File handle
;                         Y         Context ID
;                         A         Flags
; Preparatory rutines...: device_register
; Errors................: C         Set on error
;                         A         Error code,  ENODEV, ENOFILESPC, EFILEOPEN, 
;                                   ENOTFILE, ENOTFOUND, EINVAL, EIO
; Preserved registers...: None
; Credits...............: New implementation
.proc file_open
    ; Backup flags
    pha

@0: ; Valid file handle?
    cpx #FILE_HANDLES_COUNT
    bcs @1
    lda ft_flags,x
    bpl @2 
    bra err1 ; File handle already open

@1: ; Find next file handle if X = $ff
    cpx #$ff
    bne err2 ; Invalid file handle

    ldx #0
    lda ft_flags,x
    bpl @2 ; Bit 7 clear, file handle available
    inx
    cpx #FILE_HANDLES_COUNT
    bcs err3 ; Too many files

@2: ; Prepare to call device driver
    tya
    sta ft_driver,x ; Store device ID in file table
    pla ; Get flags from stack
    phx ; Backup file handle
    phy ; Move device ID to X
    plx

    ; Call driver's open function
    ldy #DRIVER_OPEN
    jsr device_call
    bcs err

    ; Update file table
    plx ; Get file handle from stack
    ora #FILE_IS_OPEN ; Ensure file is marked as open
    sta ft_flags,x
    tya
    sta ft_context,x
    lda ft_flags,x

    ; Exit successfully
    clc
    rts

err1:
    ; File open
    lda #ENOTOPEN
    bra err

err2:
    ; Invalid file handle
    lda #EINVAL
    bra err

err3:
    ; Too many files
    lda #ENOFILESPC

err:
    plx ; Restore stack
    sec
    rts
.endproc

; *****************************************************************************
; Purpose...............: Duplicates a file
; Input.................: X         Source file handle
;                         Y         Destination file handle
; Output................: Y         Destination file handle
; Preparatory rutines...: file_open
; Errors................: C         Set on error
;                         A         Error code, ENOFILESPC, ENOTOPEN, EFILEOPEN, 
;                                   EINVAL, EIO
; Preserved registers...: None
; Credits...............: New implementation
.proc file_dup
    ; Save destination file handle on stack
    phy

    ; Check if source file handle is valid
    cpx #FILE_HANDLES_COUNT
    bcs err0

    ; Check if destination file is valid
    cpy #FILE_HANDLES_COUNT
    bcs err0

    ; Check if source file is open
    lda ft_flags,x
    bpl err1 ; Source file not open

    ; Check if destination file is closed
    lda ft_flags,y
    bmi err2 ; Destination file is already open

    ; Copy file table entry
    lda ft_flags,x
    sta ft_flags,y
    lda ft_driver,x
    sta ft_driver,y
    lda ft_context,x
    sta ft_context,y

    ; Call device driver's dup function
    ldx ft_driver,y
    ldy #DRIVER_DUP
    jsr device_call
    bcs err

    ; Exit
    ply ; Get destination file handle from stack
    clc
    rts

err0:
    ; Invalid file handle
    lda #EINVAL
    bra err

err1:
    ; Source file not open
    lda #ENOTOPEN
    bra err

err2:
    ; Destination file is open
    lda #EFILEOPEN
    bra err

err:
    ply
    sec
    rts
.endproc

; *****************************************************************************
; Purpose...............: Closes a file
; Input.................: X file handle
; Output................: None
; Preparatory rutines...: Call file_open to open a file
; Errors................: C     set on error
;                         A     error code, EINVAL, ENOTOPEN, EIO
; Preserved registers...: None
; Credits...............: New implementation
.proc file_close
    ; Check if file handle is valid
    cpx #FILE_HANDLES_COUNT
    bcs err0

    ; Check if file is open
    lda ft_flags,x
    bpl err1

    ; Update file table
    lda #0
    sta ft_flags,x
    
    ; Call driver's close function
    ldy ft_context,x
    lda ft_driver,x
    tax
    tya
    ldy #DRIVER_CLOSE 
    jsr device_call
    bcs err

    ; Exit sucessfully
    clc
    rts

err0:
    ; Invalid file handle
    lda #EINVAL
    bra err

err1:
    ; File not open
    lda #ENOTOPEN

err:
    sec
    rts
.endproc

; *****************************************************************************
; Purpose...............: Reads one byte from an open file
; Input.................: X     File handle
; Output................: A     Byte value
; Preparatory rutines...: file_open
; Errors................: C     Set on error
;                         A     Error code, ENOTOPEN, EINVAL, EEOF, EIO
; Preserved registers...: None
; Credits...............: New implementation
.proc file_read_byte
    ; Verify file handle is valid
    cpx #FILE_HANDLES_COUNT
    bcs err0

    ; Verify file opened for reading
    lda ft_flags,x
    bpl err1 ; Not open
    and #FILE_FOR_READING
    beq err1 ; Not open for reading

    ; Call driver's read_byte function
    ldy ft_context,x
    lda ft_driver,x
    tax
    tya
    ldy #DRIVER_READ_BYTE
    jsr device_call
    bcs err

    ; Exit successfully
    clc
    rts

err0:
    ; Invalid file handle
    lda #EINVAL
    bra err

err1:
    ; File closed or not opened for reading
    lda #ENOTOPEN
    bra err

err:
    sec
    rts
.endproc

; *****************************************************************************
; Purpose...............: Reads a block from an open file
; Input.................: X         File handle
;                         r0-1      Number of bytes requested
;                         r2-3      Buffer address
;                         r4        Buffer bank
; Output................: r5-6      Number of bytes read
; Preparatory rutines...: file_open
; Errors................: C         Set on error
;                         A         Error code, ENOTOPEN, EINVAL, EEOF, EIO
; Preserved registers...: None
; Credits...............: New implementation
.proc file_read_block
    ; Verify file handle is valid
    cpx #FILE_HANDLES_COUNT
    bcs err0

    ; Verify file opened for reading
    lda ft_flags,x
    bpl err1 ; Not open
    and #FILE_FOR_READING
    beq err1 ; Not open for reading

    ; Call driver's read_block function
    ldy ft_context,x
    lda ft_driver,x
    tax
    tya
    ldy #DRIVER_READ_BLOCK
    jsr device_call
    bcs err
    
    ; Exit successfully
    clc
    rts

err0:
    ; Invalid file handle
    lda #EINVAL
    bra err

err1:
    ; File closed or not opened for reading
    lda #ENOTOPEN
    bra err

err:
    sec
    rts  

.endproc

; *****************************************************************************
; Purpose...............: Writes a byte to an open file
; Input.................: X     File handle
;                         A     Byte value
; Output................: None
; Preparatory rutines...: file_open
; Errors................: C     Set on error
;                         A     Error code, ENOTOPEN, ENOTFILE, EINVAL, EIO
; Preserved registers...: None
; Credits...............: New implementation
.proc file_write_byte
    ; Store byte value in r0
    sta r0
    
    ; Verify file handle is valid
    cpx #FILE_HANDLES_COUNT
    bcs err0

    ; Verify file opened for writing or appending
    lda ft_flags,x
    bpl err1 ; Not open
    and #FILE_FOR_WRITING + FILE_FOR_APPENDING
    beq err1 ; Not open for writing/appending

    ; Call driver's write_byte function
    ldy ft_context,x
    lda ft_driver,x
    tax
    tya
    ldy #DRIVER_WRITE_BYTE
    jsr device_call
    bcs err

    ; Exit successfully
    clc
    rts

err0:
    ; Invalid file handle
    lda #EINVAL
    bra err

err1:
    ; File closed or not opened for writing or appending
    lda #ENOTOPEN

err:
    sec
    rts  
    
.endproc

; *****************************************************************************
; Purpose...............: Writes a block to an open file
; Input.................: X         File handle
;                         r0-1      Buffer size
;                         r2-3      Buffer address
;                         r4        Buffer bank
; Output................: r5-6      Number of bytes written
; Preparatory rutines...: file_open
; Errors................: C         Set on error
;                         A         Error code, ENOTOPEN, ENOTFILE, EINVAL, EIO
; Preserved registers...: None
; Credits...............: New implementation
.proc file_write_block    
    ; Verify file handle is valid
    cpx #FILE_HANDLES_COUNT
    bcs err0

    ; Verify file opened for writing or appending
    lda ft_flags,x
    bpl err1 ; Not open
    and #FILE_FOR_WRITING + FILE_FOR_APPENDING
    beq err1 ; Not open for writing/appending

    ; Call driver's write_block function
    ldy ft_context,x
    lda ft_driver,x
    tax
    tya
    ldy #DRIVER_WRITE_BLOCK
    jsr device_call
    bcs err

    ; Exit successfully
    clc
    rts

err0:
    ; Invalid file handle
    lda #EINVAL
    bra err

err1:
    ; File closed or not opened for writing or appending
    lda #ENOTOPEN
    bra err

err:
    sec
    rts  
.endproc

; *****************************************************************************
; Purpose...............: Reads a byte from STDIN
; Input.................: None
; Output................: A         Byte value
; Preparatory rutines...: file_open
; Errors................: C         Set on error
;                         A         Error code, ENOTOPEN, EINVAL, EEOF, EIO
; Preserved registers...: None
; Credits...............: New implementation
.proc stdin_read
    ldx #0
    jmp file_read_byte
.endproc

; *****************************************************************************
; Purpose...............: Writes a byte to STDOUT
; Input.................: A         Byte value
; Output................: None
; Preparatory rutines...: file_open
; Errors................: C         Set on error
;                         A         Error code, ENOTOPEN, EINVAL, EIO
; Preserved registers...: None
; Credits...............: New implementation
.proc stdout_write
    ldx #1
    jmp file_write_byte
.endproc

; *****************************************************************************
; Purpose...............: Seeks a position in an open file
; Input.................: X         File handle
;                         r0-3      Requested file position
; Output................: r0-3      New file position
; Preparatory rutines...: file_open
; Errors................: C         Set on error
;                         A         Error code, ENOTOPEN, EINVAL, EIO
; Preserved registers...: None
; Credits...............: New implementation
.proc file_seek
    ; Verify file handle is valid
    cpx #FILE_HANDLES_COUNT
    bcs err0

    ; Verify file opened for reading
    lda ft_flags,x
    bpl err1 ; Not open
    and #FILE_FOR_READING
    beq err1 ; Not open for reading

    ; Call driver's seek function
    ldy ft_context,x
    lda ft_driver,x
    tax
    tya
    ldy #DRIVER_SEEK
    jsr device_call
    bcs err

    ; Exit successfully
    clc
    rts

err0:
    ; Invalid file handle
    lda #EINVAL
    bra err

err1:
    ; File closed or not opened for reading
    lda #ENOTOPEN
    bra err

err:
    sec
    rts  
.endproc

; *****************************************************************************
; Purpose...............: Returns current file position
; Input.................: X         File handle
; Output................: r0-3      File position
; Preparatory rutines...: file_open
; Errors................: C         Set on error
;                         A         Error code, ENOTOPEN, EINVAL, EIO
; Preserved registers...: None
; Credits...............: New implementation
.proc file_position
    ; Verify file handle is valid
    cpx #FILE_HANDLES_COUNT
    bcs err0

    ; Verify file open
    lda ft_flags,x
    bpl err1 ; Not open

    ; Call driver's position function
    ldy ft_context,x
    lda ft_driver,x
    tax
    tya
    ldy #DRIVER_POSITION
    jsr device_call
    bcs err

    ; Exit successfully
    clc
    rts

err0:
    ; Invalid file handle
    lda #EINVAL
    bra err

err1:
    ; File not open
    lda #ENOTOPEN

err:
    sec
    rts  
.endproc

; *****************************************************************************
; Purpose...............: Driver-specific control command
; Input.................: X         File handle
;                         r0        Device type
;                         r1        Command
;                         r2        Input length
;                         r3-4      Input buffer address
;                         r5        Input buffer bank
;                         r6-7      Output buffer address
;                         r8        Output buffer bank
;                         r9        Output buffer max length
; Output................: A         Output length
; Preparatory rutines...: file_open
; Errors................: C         Set on error
;                         A         Error code, ENOTOPEN, EINVAL, EIO
; Preserved registers...: None
; Credits...............: New implementation
.proc file_ioctl
    ; Verify file handle is valid
    cpx #FILE_HANDLES_COUNT
    bcs err0

    ; Verify file open
    lda ft_flags,x
    bpl err1 ; Not open

    ; Call driver's position function
    ldy ft_context,x
    lda ft_driver,x
    tax
    tya
    ldy #DRIVER_IOCTL
    jsr device_call
    bcs err

    ; Exit successfully
    clc
    rts

err0:
    ; Invalid file handle
    lda #EINVAL
    bra err

err1:
    ; File not open
    lda #ENOTOPEN

err:
    sec
    rts  
.endproc
