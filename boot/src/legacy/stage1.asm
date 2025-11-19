; ==============================================================================
; PyramidOS Legacy Bootloader - Stage 1 (MBR)
; ==============================================================================
; Responsibility:
; 1. Initialize Segment Registers and Stack.
; 2. Check for INT 13h Extensions (LBA support).
; 3. Load Stage 2 from disk (LBA with CHS Fallback).
; 4. Jump to Stage 2.
; ==============================================================================

bits 16
org 0x7C00

; ------------------------------------------------------------------------------
; Configuration Constants
; ------------------------------------------------------------------------------
STAGE2_LOAD_SEGMENT equ 0x0800      ; Segment 0x0800 * 16 = 0x8000 Physical
STAGE2_LOAD_OFFSET  equ 0x0000
STAGE2_START_SECTOR equ 2           ; Stage 2 starts at Sector 2 (Sector 1 is MBR)
%ifndef STAGE2_SECTOR_COUNT
    STAGE2_SECTOR_COUNT equ 12      ; Default size (overridden by Makefile)
%endif

; ------------------------------------------------------------------------------
; Entry Point
; ------------------------------------------------------------------------------
start:
    jmp short main
    nop

main:
    ; 1. Sanitization: Disable interrupts during setup
    cli
    
    ; 2. Segment Initialization (DS=ES=SS=0)
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    
    ; 3. Stack Setup (Grows down from 0x7C00)
    mov sp, 0x7C00
    
    ; 4. Enable Interrupts
    sti
    
    ; 5. Save Boot Drive Number (passed by BIOS in DL)
    mov [boot_drive], dl
    
    ; 6. UI: Clear Screen and Print Banner
    mov ax, 0x0003  ; AH=00 (Set Video Mode), AL=03 (80x25 Text)
    int 0x10
    
    mov si, msg_stage1
    call print_string

    ; --------------------------------------------------------------------------
    ; Disk Read Strategy: Try LBA (Extended) -> Fallback to CHS (Standard)
    ; --------------------------------------------------------------------------
    
    ; Check for INT 13h Extensions
    mov ah, 0x41
    mov bx, 0x55AA
    mov dl, [boot_drive]
    int 0x13
    jc .use_chs_method          ; CF=1 means extensions not supported
    cmp bx, 0xAA55
    jne .use_chs_method         ; signature mismatch

    ; === LBA Method ===
    ; Reset Disk
    mov ah, 0x00
    mov dl, [boot_drive]
    int 0x13
    
    ; Extended Read
    mov ah, 0x42
    mov dl, [boot_drive]
    mov si, dap                 ; Load Disk Address Packet
    int 0x13
    jnc .boot_success           ; If success, jump to payload

    ; Fall through to CHS if LBA fails
    mov si, msg_lba_fail
    call print_string

.use_chs_method:
    ; === CHS Method ===
    mov si, msg_chs_mode
    call print_string

    ; Reset Disk
    mov ah, 0x00
    mov dl, [boot_drive]
    int 0x13

    ; Standard Read (INT 13h AH=02h)
    mov ah, 0x02
    mov al, STAGE2_SECTOR_COUNT
    mov ch, 0                   ; Cylinder 0
    mov cl, STAGE2_START_SECTOR ; Sector 2
    mov dh, 0                   ; Head 0
    mov dl, [boot_drive]
    
    ; Buffer Address ES:BX
    mov bx, STAGE2_LOAD_SEGMENT
    mov es, bx
    mov bx, STAGE2_LOAD_OFFSET
    
    int 0x13
    jnc .boot_success

    ; --------------------------------------------------------------------------
    ; Error Handling
    ; --------------------------------------------------------------------------
.disk_error:
    mov si, msg_disk_err
    call print_string
    ; Print Error Code (in AH)
    mov al, ah
    call print_hex
    cli
    hlt

    ; --------------------------------------------------------------------------
    ; Handover
    ; --------------------------------------------------------------------------
.boot_success:
    mov si, msg_success
    call print_string
    
    ; Restore Segment Registers (ES was modified)
    xor ax, ax
    mov es, ax
    
    ; Pass Boot Drive in DL to Stage 2
    mov dl, [boot_drive]
    
    ; Far Jump to Stage 2
    jmp STAGE2_LOAD_SEGMENT:STAGE2_LOAD_OFFSET

; ------------------------------------------------------------------------------
; Utility Functions
; ------------------------------------------------------------------------------

; Function: print_string
; Input: SI = pointer to null-terminated string
print_string:
    push ax
    push si
.loop:
    lodsb               ; Load byte at SI into AL, increment SI
    test al, al
    jz .done
    mov ah, 0x0E        ; BIOS Teletype Output
    int 0x10
    jmp .loop
.done:
    pop si
    pop ax
    ret

; Function: print_hex
; Input: AL = byte to print
print_hex:
    push ax
    push cx
    mov ah, 0x0E
    
    ; High Nibble
    mov cl, al
    shr al, 4
    call .print_nibble
    
    ; Low Nibble
    mov al, cl
    and al, 0x0F
    call .print_nibble
    
    pop cx
    pop ax
    ret

.print_nibble:
    add al, '0'
    cmp al, '9'
    jle .emit
    add al, 7           ; Adjust for A-F
.emit:
    int 0x10
    ret

; ------------------------------------------------------------------------------
; Data Section
; ------------------------------------------------------------------------------
boot_drive:   db 0
msg_stage1:   db 'PyramidOS S1...', 13, 10, 0
msg_chs_mode: db 'CHS..', 0
msg_lba_fail: db 'LBA Fail..', 0
msg_success:  db ' OK', 13, 10, 0
msg_disk_err: db 'ERR:', 0

; Disk Address Packet (DAP) for LBA Reading
align 4
dap:
    db 0x10                     ; Size of packet (16 bytes)
    db 0                        ; Reserved
    dw STAGE2_SECTOR_COUNT      ; Number of sectors
    dw STAGE2_LOAD_OFFSET       ; Buffer Offset
    dw STAGE2_LOAD_SEGMENT      ; Buffer Segment
    dd STAGE2_START_SECTOR - 1  ; LBA Low (0-based, so Sector 2 is LBA 1)
    dd 0                        ; LBA High

; ------------------------------------------------------------------------------
; Boot Signature
; ------------------------------------------------------------------------------
times 510-($-$$) db 0
dw 0xAA55