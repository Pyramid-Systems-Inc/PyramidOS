; boot/src/legacy/stage1.asm
; Minimal Stage 1 that loads assembly Stage 2

org 0x7C00
bits 16

STAGE2_LOAD_SEGMENT equ 0x0800
STAGE2_LOAD_OFFSET  equ 0x0000
STAGE2_START_SECTOR equ 2
STAGE2_SECTOR_COUNT equ 16  ; 8KB Stage 2

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
    
    ; Clear screen
    mov ax, 0x0003
    int 0x10
    
    ; Print loading message
    mov si, msg_loading
    call print_string
    
    ; Load Stage 2 using extended read
    mov ah, 0x42
    mov dl, [boot_drive]
    mov si, dap
    int 0x13
    jnc .success
    
    ; Try standard read as fallback
    mov ah, 0x02
    mov al, STAGE2_SECTOR_COUNT
    mov ch, 0
    mov cl, STAGE2_START_SECTOR
    mov dh, 0
    mov dl, [boot_drive]
    mov bx, STAGE2_LOAD_SEGMENT
    mov es, bx
    mov bx, STAGE2_LOAD_OFFSET
    int 0x13
    jc .error
    
.success:
    mov si, msg_success
    call print_string
    
    ; Jump to Stage 2 with boot drive in DL
    mov dl, [boot_drive]
    jmp STAGE2_LOAD_SEGMENT:STAGE2_LOAD_OFFSET

.error:
    mov si, msg_error
    call print_string
    cli
    hlt

print_string:
    push ax
    push si
.loop:
    lodsb
    test al, al
    jz .done
    mov ah, 0x0E
    int 0x10
    jmp .loop
.done:
    pop si
    pop ax
    ret

; Data
boot_drive: db 0

dap:
    db 0x10
    db 0
    dw STAGE2_SECTOR_COUNT
    dw STAGE2_LOAD_OFFSET
    dw STAGE2_LOAD_SEGMENT
    dq STAGE2_START_SECTOR - 1

msg_loading: db 'Loading Stage 2...', 0
msg_success: db ' OK', 0x0D, 0x0A, 0
msg_error:   db ' FAILED!', 0x0D, 0x0A, 0

times 510-($-$$) db 0
dw 0xAA55