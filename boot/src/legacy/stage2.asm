; boot/src/legacy/stage2.asm
bits 16
org 0x8000

;Constants
KERNEL_LOAD_SEG     equ 0x1000
KERNEL_LOAD_OFF     equ 0x0000
KERNEL_LBA          equ 60      ; LBA 60
KERNEL_SECTOR_COUNT equ 16      ; *** CHANGE THIS FROM 8 to 16 ***

; For standard floppy: 18 sectors/track, 2 heads, 80 cylinders
; LBA 60 = C:1, H:1, S:7
KERNEL_CYLINDER     equ 1
KERNEL_HEAD         equ 1  
KERNEL_SECTOR       equ 7       ; CHS sectors are 1-based

; Entry point
stage2_start:
    ; Save boot drive
    mov [boot_drive], dl
    
    ; Setup segments
    mov ax, 0x0800
    mov ds, ax
    mov es, ax
    
    ; Setup stack
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
    ; Restore ES
    mov ax, 0x0800
    mov es, ax
    
    ; Success
    mov si, msg_kernel_ok
    call print_string
    
    ; Add debug: Show kernel size loaded
    mov si, msg_debug1
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
    
    ; Add debug: About to load GDT
    mov si, msg_debug2
    call print_string
    
    ; Small delay
    mov cx, 0x8000
.delay:
    loop .delay
    
    cli
    lgdt [gdt_descriptor]
    
    ; Add debug: GDT loaded
    mov si, msg_debug3
    call print_string
    
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
    
    ; Jump directly to kernel - let kernel clear screen
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
msg_pmode:      db 'PM ', 0
msg_debug1:     db 'KLD ', 0    ; Kernel loaded
msg_debug2:     db 'GDT ', 0    ; About to load GDT
msg_debug3:     db 'PGDT ', 0   ; GDT loaded

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
    dd gdt_start + 0x8000  ; Add base address

times 2048-($-$$) db 0