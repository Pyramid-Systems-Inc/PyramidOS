; boot/src/legacy/stage2.asm
bits 16
org 0x8000

; Constants
KERNEL_LOAD_SEG     equ 0x1000
KERNEL_LOAD_OFF     equ 0x0000
KERNEL_LBA_START    equ 60
KERNEL_SECTOR_COUNT equ 8

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
    
    ; Print "S2" to show Stage 2 is running
    mov ax, 0x0E53  ; 'S'
    int 0x10
    mov ax, 0x0E32  ; '2'
    int 0x10
    mov ax, 0x0E20  ; space
    int 0x10
    
    ; Load kernel
    mov ah, 0x42
    mov dl, [boot_drive]
    mov si, kernel_dap
    int 0x13
    jnc .kernel_loaded
    
    ; Show error 'K!'
    mov ax, 0x0E4B  ; 'K'
    int 0x10
    mov ax, 0x0E21  ; '!'
    int 0x10
    cli
    hlt
    
.kernel_loaded:
    ; Show kernel loaded 'K>'
    mov ax, 0x0E4B  ; 'K'
    int 0x10
    mov ax, 0x0E3E  ; '>'
    int 0x10
    mov ax, 0x0E20  ; space
    int 0x10
    
    ; Enable A20
    in al, 0x92
    or al, 2
    out 0x92, al
    
    ; Show A20 enabled 'A>'
    mov ax, 0x0E41  ; 'A'
    int 0x10
    mov ax, 0x0E3E  ; '>'
    int 0x10
    mov ax, 0x0E20  ; space
    int 0x10
    
    ; Show entering protected mode 'P'
    mov ax, 0x0E50  ; 'P'
    int 0x10
    
    ; Small delay
    mov cx, 0xFFFF
.delay:
    loop .delay
    
    ; Enter protected mode
    cli
    lgdt [gdt_descriptor]
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    jmp 0x08:protected_mode_start

bits 32
protected_mode_start:
    ; Setup 32-bit segments
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x90000
    
    ; Clear screen and show we're in protected mode
    mov edi, 0xB8000
    mov ecx, 80 * 25
    mov ax, 0x0720  ; Black background, white text, space
    rep stosw
    
    ; Write "32" at top-left to show we're in 32-bit mode
    mov dword [0xB8000], 0x07330732  ; "32" in white
    
    ; Jump to kernel
    jmp 0x10000

bits 16
; Data
boot_drive: db 0

kernel_dap:
    db 0x10, 0
    dw KERNEL_SECTOR_COUNT
    dw KERNEL_LOAD_OFF
    dw KERNEL_LOAD_SEG
    dq KERNEL_LBA_START

; GDT
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
    dd gdt_start

times 2048-($-$$) db 0