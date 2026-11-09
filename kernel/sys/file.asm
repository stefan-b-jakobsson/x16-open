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
.export ft_driver, ft_flags
.export file_init
.export file_open, file_close
.export file_read_byte, file_read_block, stdin_read
.export file_write_byte, file_write_block, stdout_write
.export file_seek, file_position
.export file_ioctl
.export std_get, std_set

; Imports
.import device_call

; *****************************************************************************
; Kernel file table
.segment "K_LRAM"
ft_driver:      .res FILE_COUNT
ft_context:     .res FILE_COUNT
ft_flags:       .res FILE_COUNT
std_streams:    .res STD_COUNT

.CODE

; *****************************************************************************
; Purpose...............: Initializes the kernel's file table and functions
; Input.................: None
; Output................: None
; Preparatory rutines...: device_init
; Errors................: C         Set on error
;                         A         Error code, ENODEV, ENOFILESPC, EFILEOPEN, 
;                                   ENOTFILE, ENOTFOUND, EINVAL, EIO
; Registers affected....: A, X, Y, P
; Credits...............: New implementation
.proc file_init
    ; Disable interrupts
    php
    cli

    ; Clear file table
    lda #0
    ldx #FILE_COUNT
:   sta ft_flags-1,x
    dex
    bne :-

    ; Open STDIN as file #0
    ldx #0
    ldy #DEVICE_KEYBOARD
    lda #FILE_FOR_READING
    jsr file_open
    bcs err
    stx std_streams+STDIN-$80   ; Connect file handle to STDIN

    ; Open STDOUT as file #1
    ldx #1
    ldy #DEVICE_TERMINAL
    lda #FILE_FOR_WRITING
    jsr file_open
    bcs err
    stx std_streams+STDOUT-$80  ; Connect file handle to STDOUT

    ; Open STD_MOUSE as file #2
    ; TODO: Not yet implemented
    lda #$ff
    sta std_streams+STDMOUSE-$80

    ; Open STD_GAME as file #3
    ; TODO: Not yet implemented
    lda #$ff
    sta std_streams+STDGAME-$80

exit:
    plp ; Restore IRQ
    clc
    rts

err:
    plp ; Restore IRQ
    sec
    rts
.endproc

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
;                         A         Error code, ENODEV, ENOFILESPC, EFILEOPEN, 
;                                   ENOTFILE, ENOTFOUND, EINVAL, EIO
; Registers affected....: A, X, Y, P
; Credits...............: New implementation
.proc file_open
    ; Backup flags
    pha

    ; Valid file handle?
    cpx #FILE_COUNT
    bcs search
    lda ft_flags,x
    bpl prepare 
    bra err_open ; File handle already open

search: 
    ; Search next file handle if X = $ff
    cpx #$ff
    bne err_invalid ; Invalid file handle

    ldx #0
    lda ft_flags,x
    bpl prepare ; Bit 7 clear, file handle available
    inx
    cpx #FILE_COUNT
    bcs err_toomany ; Too many files

prepare:
    ; Prepare to call device driver
    tya ; Device ID
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

err_open:
    ; File open
    lda #EFILEOPEN
    bra err

err_invalid:
    ; Invalid file handle
    lda #EINVAL
    bra err

err_toomany:
    ; Too many files
    lda #ENOFILESPC

err:
    plx ; Restore stack
    sec
    rts
.endproc

; *****************************************************************************
; Purpose...............: Closes a file; the file is not marked as closed
;                         if calling the driver's close function returns an
;                         error
; Input.................: X     File handle or standard stream
; Output................: X     Input preserved
; Preparatory rutines...: Call file_open to open a file
; Errors................: C     set on error
;                         A     error code, EINVAL, ENOTOPEN, EIO
; Registers affected....: A, P
; Credits...............: New implementation
.proc file_close
    ; Verify file handle
    cpx #FILE_COUNT
    bcc isopen

    cpx #$80
    bcc err_invalid

    cpx #$80 + STD_COUNT
    bcs err_invalid

    lda std_streams-$80,x
    tax

isopen:
    ; Check if file is open
    lda ft_flags,x
    bpl err_notopen
    
    ; Backup X and Y on stack
    phx
    phy

    ; Call driver's close function
    ldy ft_context,x
    lda ft_driver,x
    tax
    tya
    ldy #DRIVER_CLOSE
    jsr device_call
    bcs err_driver

    ; Restore X and Y from stack
    ply
    plx

    ; Update file table
    lda #0
    sta ft_flags,x

    ; Exit
    rts

err_invalid:
    ; Invalid file handle
    lda #EINVAL
    bra err

err_notopen:
    ; File not open
    lda #ENOTOPEN
    bra err

err_driver:
    ; Restore X and Y from stack
    ply
    plx

err:
    sec
    rts
.endproc

; *****************************************************************************
; Purpose...............: Reads one byte from an open file
; Input.................: X     File handle or standard stream
; Output................: A     Byte value
;                         X     Preserved
;                         Y     Preserved
; Preparatory rutines...: file_open
; Errors................: C     Set on error
;                         A     Error code, ENOTOPEN, EINVAL, EEOF, EIO
; Registers affected....: A, P
; Credits...............: New implementation
.proc file_read_byte
    ; Verify file handle is valid
    cpx #FILE_COUNT
    bcc isopen

    cpx #$80
    bcc err_invalid
    
    cpx #$80+STD_COUNT
    bcs err_invalid
    
    lda std_streams-$80,x
    tax

isopen:
    ; Verify file opened for reading
    lda ft_flags,x
    bpl err_notopen ; Not open
    and #FILE_FOR_READING
    beq err_invalid ; Not open for reading

    ; Backup X and Y on stack
    phx
    phy

    ; Call driver's read_byte function
    ldy ft_context,x
    lda ft_driver,x
    tax
    tya
    ldy #DRIVER_READ_BYTE
    jsr device_call
    bcs err_driver

    ; Restore X and Y from stack
    ply
    plx

    ; Exit
    rts

err_invalid:
    ; Invalid file handle
    lda #EINVAL
    bra err

err_notopen:
    ; File closed or not opened for reading
    lda #ENOTOPEN
    bra err

err_driver:
    ; Restore X and Y from stack
    ply
    plx

err:
    sec
    rts
.endproc

; *****************************************************************************
; Purpose...............: Reads a block from an open file
; Input.................: X         File handle or standard stream
;                         r0-1      Number of bytes requested
;                         r2-3      Buffer address
;                         r4        Buffer bank
; Output................: r5-6      Number of bytes read
; Preparatory rutines...: file_open
; Errors................: C         Set on error
;                         A         Error code, ENOTOPEN, EINVAL, EEOF, EIO
; Registers affected....: A, P, r0-1, r5-6
; Credits...............: New implementation
.proc file_read_block
    ; Verify file handle is valid
    cpx #FILE_COUNT
    bcc isopen

    cpx #$80
    bcc err_invalid

    cpx #$80+STD_COUNT
    bcs err_invalid

    lda std_streams-$80,x
    tax

isopen:
    ; Verify file opened for reading
    lda ft_flags,x
    bpl err_notopen ; Not open
    and #FILE_FOR_READING
    beq err_invalid ; Not open for reading

    ; Backup X and Y on stack
    phx
    phy

    ; Call driver's read_block function
    ldy ft_context,x
    lda ft_driver,x
    tax
    tya
    ldy #DRIVER_READ_BLOCK
    jsr device_call
    bcs err_driver
    
    ; Restore X and Y from stack
    ply
    plx

    ; Exit successfully
    rts

err_invalid:
    ; Invalid file handle
    lda #EINVAL
    bra err

err_notopen:
    ; File closed or not opened for reading
    lda #ENOTOPEN
    bra err

err_driver:
    ; Restore X and Y from stack
    ply
    plx

err:
    sec
    rts  
.endproc

; *****************************************************************************
; Purpose...............: Writes a byte to an open file
; Input.................: X     File handle or standard stream
;                         A     Byte value
; Output................: None
; Preparatory rutines...: file_open
; Errors................: C     Set on error
;                         A     Error code, ENOTOPEN, ENOTFILE, EINVAL, EIO
; Registers affected....: A, P
; Credits...............: New implementation
.proc file_write_byte
    ; Backup X, Y and r0 on stack
    phx
    phy
    ldy r0
    phy

    ; Store byte value in r0
    sta r0
    
    ; Verify file handle
    cpx #FILE_COUNT
    bcc isopen

    cpx #$80
    bcc err_invalid

    cpx #$80+STD_COUNT
    bcs err_invalid

    lda std_streams-$80,x
    tax

isopen:
    ; Verify file opened for writing or appending
    lda ft_flags,x
    bpl err_notopen ; Not open
    and #FILE_FOR_WRITING + FILE_FOR_APPENDING
    beq err_invalid ; Not open for writing/appending

    ; Call driver's write_byte function
    ldy ft_context,x
    lda ft_driver,x
    tax
    tya
    ldy #DRIVER_WRITE_BYTE
    jsr device_call
    bcs err

    ; Restore X, Y and r0 from stack
    ply
    sty r0
    ply
    plx

    ; Exit
    rts

err_invalid:
    ; Invalid file handle
    lda #EINVAL
    bra err

err_notopen:
    ; File closed or not opened for writing or appending
    lda #ENOTOPEN

err:
    ; Restore X, Y and r0 from stack
    ply
    sty r0
    ply
    plx

    ; Exit
    sec
    rts  
.endproc

; *****************************************************************************
; Purpose...............: Writes a block to an open file
; Input.................: X         File handle or standard stream
;                         r0-1      Buffer size
;                         r2-3      Buffer address
;                         r4        Buffer bank
; Output................: r5-6      Number of bytes written
; Preparatory rutines...: file_open
; Errors................: C         Set on error
;                         A         Error code, ENOTOPEN, ENOTFILE, EINVAL, EIO
; Affected registers....: A, P, r5-6
; Credits...............: New implementation
.proc file_write_block
    ; Backup X and Y on stack
    phx
    phy

    ; Verify file handle
    cpx #FILE_COUNT
    bcc isopen

    cpx #$80
    bcc err_invalid
    cpx #$80 + STD_COUNT
    bcs err_invalid

    lda std_streams-$80,x
    tax

isopen:
    ; Verify file opened for writing or appending
    lda ft_flags,x
    bpl err_notopen ; Not open
    and #FILE_FOR_WRITING + FILE_FOR_APPENDING
    beq err_invalid ; Not open for writing/appending

    ; Call driver's write_block function
    ldy ft_context,x
    lda ft_driver,x
    tax
    tya
    ldy #DRIVER_WRITE_BLOCK
    jsr device_call
    bcs err_driver

    ; Restore X and Y from stack
    ply
    plx

    ; Exit
    rts

err_invalid:
    ; Invalid file handle
    lda #EINVAL
    bra err

err_notopen:
    ; File closed or not opened for writing or appending
    lda #ENOTOPEN
    bra err

err_driver:
    ; Restore X and Y from stack
    ply
    plx

err:
    sec
    rts  
.endproc

; *****************************************************************************
; Purpose...............: Connects a file to a standard stream
; Input.................: X         File handle
;                         Y         Standard stream
; Output................: None
; Preparatory rutines...: file_open
; Errors................: C         Set on error
;                         A         Error code, ENOTOPEN, EINVAL
; Registers affected....: A, P
; Credits...............: New implementation
.proc std_set
    ; Verify file handle
    cpx #FILE_COUNT
    bcs err_invalid

    cpy #STD_COUNT
    bcs err_invalid

    lda ft_flags,x
    bpl err_notopen

    ; Update standard stream
    txa
    sta std_streams,y

    ; Exit
    clc
    rts

err_invalid:
    lda #EINVAL
    bra err

err_notopen:
    lda #ENOTOPEN

err:
    sec
    rts
.endproc

; *****************************************************************************
; Purpose...............: Returns file connected to a standard stream
; Input.................: Y         Standard stream
; Output................: X         File handle
; Preparatory rutines...: file_open
; Errors................: C         Set on error
;                         A         Error code, EINVAL
; Registers affected....: A, P
; Credits...............: New implementation
.proc std_get
    ; Check if valid standard stream
    cpy #STD_COUNT
    bcs err_invalid

    ; Get value and exit
    ldx std_streams,y
    clc
    rts

err_invalid:
    lda #EINVAL
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
; Registers affected....: A, P
; Credits...............: New implementation
.proc stdin_read
    ; Preserve X on stack
    phx

    ; Read byte
    ldx #STDIN
    jsr file_read_byte

    ; Restore X and exit
    plx
    rts
.endproc

; *****************************************************************************
; Purpose...............: Writes a byte to STDOUT
; Input.................: A         Byte value
; Output................: None
; Preparatory rutines...: file_open
; Errors................: C         Set on error
;                         A         Error code, ENOTOPEN, EINVAL, EIO
; Registers affected....: A, P
; Credits...............: New implementation
.proc stdout_write
    ; Backup X on stack
    phx

    ; Read byte
    ldx #STDOUT
    jsr file_write_byte

    ; Restore X and exit
    plx
    rts
.endproc

; *****************************************************************************
; Purpose...............: Seeks a position in an open file
; Input.................: X         File handle or standard stream
;                         r0-3      Requested file position
; Output................: r0-3      New file position
; Preparatory rutines...: file_open
; Errors................: C         Set on error
;                         A         Error code, ENOTOPEN, EINVAL, EIO
; Registers affected....: A, P, r0-3
; Credits...............: New implementation
.proc file_seek
    ; Verify file handle
    cpx #FILE_COUNT
    bcc isopen

    cpx #$80
    bcc err_invalid
    cpx #$80+STD_COUNT
    bcs err_invalid
    lda std_streams-$80,x
    tax

isopen:
    ; Verify file open
    lda ft_flags,x
    bpl err_notopen ; Not open

    ; Backup X and Y on stack
    phx
    phy

    ; Call driver's seek function
    ldy ft_context,x
    lda ft_driver,x
    tax
    tya
    ldy #DRIVER_SEEK
    jsr device_call
    bcs err_driver

    ; Restore X and Y from stack
    ply
    plx

    ; Exit
    rts

err_invalid:
    ; Invalid file handle
    lda #EINVAL
    bra err

err_notopen:
    ; File closed or not opened for reading
    lda #ENOTOPEN
    bra err

err_driver:
    ; Restore X and Y from stack
    ply
    plx

err:
    sec
    rts  
.endproc

; *****************************************************************************
; Purpose...............: Returns current file position
; Input.................: X         File handle or standard stream
; Output................: r0-3      File position
; Preparatory rutines...: file_open
; Errors................: C         Set on error
;                         A         Error code, ENOTOPEN, EINVAL, EIO
; Registers affected....: A, P, r0-3
; Credits...............: New implementation
.proc file_position
     ; Verify file handle
    cpx #FILE_COUNT
    bcc isopen

    cpx #$80
    bcc err_invalid
    cpx #$80+STD_COUNT
    bcs err_invalid
    lda std_streams-$80,x
    tax

isopen:
    ; Verify file open
    lda ft_flags,x
    bpl err_notopen ; Not open

    ; Preserve X and Y on stack
    phx
    phy

    ; Call driver's position function
    ldy ft_context,x
    lda ft_driver,x
    tax
    tya
    ldy #DRIVER_POSITION
    jsr device_call
    bcs err_driver

    ; Restore X and Y from stack
    ply
    plx

    ; Exit
    rts

err_invalid:
    ; Invalid file handle
    lda #EINVAL
    bra err

err_notopen:
    ; File not open
    lda #ENOTOPEN
    bra err

err_driver:
    ; Restore X and Y from stack
    ply
    plx

err:
    sec
    rts  
.endproc

; *****************************************************************************
; Purpose...............: Driver-specific control command
; Input.................: X         File handle or standard stream
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
; Registers affected....: A, P
; Credits...............: New implementation
.proc file_ioctl
    ; Backup X and Y
    phx
    phy

    ; Verify file handle
    cpx #FILE_COUNT
    bcc isopen

    cpx #$80
    bcc err_invalid
    cpx #$80+STD_COUNT
    bcs err_invalid
    lda std_streams-$80,x
    tax

isopen:
    ; Verify file open
    lda ft_flags,x
    bpl err_notopen

    ; Call driver's position function
    ldy ft_context,x
    lda ft_driver,x
    tax
    tya
    ldy #DRIVER_IOCTL
    jsr device_call
    bcs err_driver

    ; Restore X and Y
    ply
    plx
    
    ; Exit
    rts

err_invalid:
    ; Invalid file handle
    lda #EINVAL
    bra err

err_notopen:
    ; File not open
    lda #ENOTOPEN
    bra err

err_driver:
    ; Restore X and Y
    ply
    plx

err:
    sec
    rts  
.endproc
