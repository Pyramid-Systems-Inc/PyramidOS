; boot/src/legacy/stage1.asm
org 0x7C00
bits 16

STAGE2_LOAD_SEGMENT equ 0x0800
STAGE2_LOAD_OFFSET  equ 0x0000
STAGE2_START_SECTOR equ 2
STAGE2_SECTOR_COUNT equ 4  ; 2KB for Stage 2

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti
    
    ; Save boot drive
    mov [boot_drive], dl
    
    ; Clear screen and show Stage 1 is running
    mov ax, 0x0003
    int 0x10
    
    ; Print "S1" to show Stage 1 is running
    mov ax, 0x0E53  ; 'S'
    int 0x10
    mov ax, 0x0E31  ; '1'
    int 0x10
    mov ax, 0x0E20  ; space
    int 0x10
    
    ; Load Stage 2
    mov ah, 0x42
    mov dl, [boot_drive]
    mov si, dap
    int 0x13
    jnc .success
    
    ; If extended read failed, show 'E'
    mov ax, 0x0E45  ; 'E'
    int 0x10
    cli
    hlt
    
.success:
    ; Show success with '>'
    mov ax, 0x0E3E  ; '>'
    int 0x10
    mov ax, 0x0E20  ; space
    int 0x10
    
    ; Jump to Stage 2
    mov dl, [boot_drive]
    jmp STAGE2_LOAD_SEGMENT:STAGE2_LOAD_OFFSET

; Data
boot_drive: db 0

dap:
    db 0x10
    db 0
    dw STAGE2_SECTOR_COUNT
    dw STAGE2_LOAD_OFFSET
    dw STAGE2_LOAD_SEGMENT
    dq STAGE2_START_SECTOR - 1

times 510-($-$$) db 0
dw 0xAA55