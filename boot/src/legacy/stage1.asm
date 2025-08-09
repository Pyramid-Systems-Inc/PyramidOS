; boot/src/legacy/stage1.asm
org 0x7C00
bits 16

STAGE2_LOAD_SEGMENT equ 0x0800
STAGE2_LOAD_OFFSET  equ 0x0000
STAGE2_START_SECTOR equ 2
STAGE2_SECTOR_COUNT equ 8  ; Increase to 8 sectors (4KB) to be safe

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
    
    ; Print "S1"
    mov si, msg_s1
    call print_string
    
    ; Try extended read first
    mov ah, 0x42
    mov dl, [boot_drive]
    mov si, dap
    int 0x13
    jnc .success
    
    ; Extended read failed, try standard read
    mov si, msg_std
    call print_string
    
    ; Standard read
    mov ah, 0x02                    ; Read sectors
    mov al, STAGE2_SECTOR_COUNT     ; Number of sectors
    mov ch, 0                       ; Cylinder 0
    mov cl, STAGE2_START_SECTOR     ; Start at sector 2
    mov dh, 0                       ; Head 0
    mov dl, [boot_drive]            ; Drive
    mov bx, STAGE2_LOAD_SEGMENT
    mov es, bx
    mov bx, STAGE2_LOAD_OFFSET
    int 0x13
    jc .error
    
.success:
    mov si, msg_ok
    call print_string
    
    ; Restore ES and jump to Stage 2
    xor ax, ax
    mov es, ax
    mov dl, [boot_drive]
    jmp STAGE2_LOAD_SEGMENT:STAGE2_LOAD_OFFSET

.error:
    mov si, msg_err
    call print_string
    ; Print error code
    mov al, ah
    call print_hex
    cli
    hlt

; Print string
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

; Print AL as hex
print_hex:
    push ax
    push cx
    mov cl, al
    shr al, 4
    call print_nibble
    mov al, cl
    and al, 0x0F
    call print_nibble
    pop cx
    pop ax
    ret

print_nibble:
    and al, 0x0F
    add al, '0'
    cmp al, '9'
    jle .print
    add al, 7
.print:
    mov ah, 0x0E
    int 0x10
    ret

; Data
boot_drive: db 0

; Messages
msg_s1:  db 'S1 ', 0
msg_std: db 'STD ', 0
msg_ok:  db 'OK ', 0
msg_err: db 'ERR:', 0

; Disk Address Packet
align 4
dap:
    db 0x10                         ; Size of packet (16 bytes)
    db 0                            ; Always 0
    dw STAGE2_SECTOR_COUNT          ; Number of sectors
    dw STAGE2_LOAD_OFFSET           ; Offset
    dw STAGE2_LOAD_SEGMENT          ; Segment  
    dd STAGE2_START_SECTOR - 1      ; LBA low (0-based)
    dd 0                            ; LBA high

times 510-($-$$) db 0
dw 0xAA55