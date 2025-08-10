; boot/src/legacy/stage2.asm
bits 16
org 0x8000

; Constants
KERNEL_LOAD_SEG     equ 0x1000
KERNEL_LOAD_OFF     equ 0x0000
KERNEL_LBA          equ 60      
KERNEL_SECTOR_COUNT equ 16      ; Load 16 sectors (8KB)

; For standard floppy: 18 sectors/track, 2 heads, 80 cylinders
KERNEL_CYLINDER     equ 1
KERNEL_HEAD         equ 1  
KERNEL_SECTOR       equ 7       

; Entry point
stage2_start:
    ; Save boot drive
    mov [boot_drive], dl
    
    ; Setup segments - FIX: Use flat addressing to match org 0x8000
    xor ax, ax          ; Set segments to 0x0000 for flat addressing
    mov ds, ax
    mov es, ax
    
    ; Setup stack in a safe area
    mov ax, 0x0700
    mov ss, ax
    mov sp, 0xFFFF
    
    ; Print "S2 "
    mov si, msg_s2
    call print_string
    
    ; Try Method 1: LBA read using INT 13h extensions
    mov ah, 0x41        ; Check for extensions
    mov bx, 0x55AA
    mov dl, [boot_drive]
    int 0x13
    jc .use_chs         ; Extensions not supported
    cmp bx, 0xAA55
    jne .use_chs
    
    ; Use LBA read
    mov si, msg_lba
    call print_string
    
    mov ah, 0x42
    mov dl, [boot_drive]
    mov si, kernel_dap
    int 0x13
    jnc .kernel_loaded
    
.use_chs:
    ; Use CHS read
    mov si, msg_chs
    call print_string
    
    ; Setup for kernel load
    mov ax, KERNEL_LOAD_SEG
    mov es, ax
    mov bx, KERNEL_LOAD_OFF
    
    mov ah, 0x02                    ; Read sectors
    mov al, KERNEL_SECTOR_COUNT     ; Number of sectors
    mov ch, KERNEL_CYLINDER         ; Cylinder 1
    mov cl, KERNEL_SECTOR           ; Sector 7
    mov dh, KERNEL_HEAD             ; Head 1
    mov dl, [boot_drive]            ; Drive
    int 0x13
    jc .kernel_error
    
.kernel_loaded:
    ; Restore ES to 0 for flat addressing
    xor ax, ax
    mov es, ax
    
    ; Success
    mov si, msg_kernel_ok
    call print_string
    
    ; Enable A20
    in al, 0x92
    or al, 2
    out 0x92, al
    
    mov si, msg_a20
    call print_string
    
    ; Enter protected mode
    mov si, msg_pmode
    call print_string
    
    ; Small delay
    mov cx, 0x8000
.delay:
    loop .delay
    
    cli
    lgdt [gdt_descriptor]
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    jmp 0x08:protected_mode_start

.kernel_error:
    mov si, msg_kernel_err
    call print_string
    ; Show error code
    call print_hex_byte
    cli
    hlt

bits 32
protected_mode_start:
    ; Setup segments
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x90000
    
    ; Jump directly to kernel
    jmp 0x10000

bits 16

; Print string
print_string:
    push ax
    push si
.loop:
    lodsb
    test al, al
    jz .done
    call print_char
    jmp .loop
.done:
    pop si
    pop ax
    ret

; Print character
print_char:
    push ax
    push bx
    mov ah, 0x0E
    mov bx, 0x0007
    int 0x10
    pop bx
    pop ax
    ret

; Print AL as hex byte
print_hex_byte:
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
    call print_char
    ret

; Data
boot_drive: db 0

; Disk Address Packet for LBA read
kernel_dap:
    db 0x10                 ; Size
    db 0                    ; Reserved
    dw KERNEL_SECTOR_COUNT  ; Sectors to read
    dw KERNEL_LOAD_OFF      ; Buffer offset
    dw KERNEL_LOAD_SEG      ; Buffer segment
    dq KERNEL_LBA           ; LBA

; Messages
msg_s2:         db 'S2 ', 0
msg_lba:        db 'LBA ', 0
msg_chs:        db 'CHS ', 0
msg_kernel_ok:  db 'K-OK ', 0
msg_kernel_err: db 'K-ERR:', 0
msg_a20:        db 'A20 ', 0
msg_pmode:      db 'PM', 0

; GDT
align 8
gdt_start:
    dq 0  ; Null descriptor
    ; Code segment
    dw 0xFFFF, 0x0000
    db 0x00, 10011010b, 11001111b, 0x00
    ; Data segment
    dw 0xFFFF, 0x0000
    db 0x00, 10010010b, 11001111b, 0x00
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start + 0x8000  ; Absolute address since we're using flat addressing

times 2048-($-$$) db 0