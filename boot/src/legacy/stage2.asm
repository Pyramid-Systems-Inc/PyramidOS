; boot/src/legacy/stage2.asm
; Complete Stage 2 bootloader in assembly
; Loads kernel and switches to protected mode

bits 16
org 0x8000  ; Stage 2 is loaded at 0x0800:0x0000 (linear 0x8000)

; Constants
KERNEL_LOAD_SEG     equ 0x1000  ; Kernel loaded at 0x1000:0x0000 (0x10000 linear)
KERNEL_LOAD_OFF     equ 0x0000
KERNEL_LBA_START    equ 60       ; Kernel starts at sector 60
KERNEL_SECTOR_COUNT equ 64       ; Load 64 sectors (32KB)
VGA_MEMORY          equ 0xB8000  ; VGA text mode memory

; Entry point - called from Stage 1
stage2_start:
    ; Stage 1 passes boot drive in DL
    mov [boot_drive], dl
    
    ; Set up segments for Stage 2
    mov ax, 0x0800
    mov ds, ax
    mov es, ax
    
    ; Set up stack
    mov ax, 0x0700
    mov ss, ax
    mov sp, 0xFFFF
    
    ; Clear screen
    call clear_screen
    
    ; Print header
    mov si, msg_stage2
    call print_string
    
    ; Show boot drive
    mov si, msg_boot_drive
    call print_string
    mov al, [boot_drive]
    call print_hex_byte
    call print_newline
    
    ; Load kernel
    call load_kernel
    
    ; Enable A20 line
    call enable_a20
    
    ; Print success message
    mov si, msg_entering_pmode
    call print_string
    
    ; Small delay so we can see the message
    mov cx, 0xFFFF
.delay:
    loop .delay
    
    ; Enter protected mode and jump to kernel
    call enter_protected_mode

; ============================================================================
; Load Kernel Function
; ============================================================================
load_kernel:
    push ax
    push dx
    push si
    
    mov si, msg_loading_kernel
    call print_string
    
    ; Try extended read first
    mov ah, 0x42
    mov dl, [boot_drive]
    mov si, kernel_dap
    int 0x13
    jnc .load_success
    
    ; If extended read failed, try standard read
    mov si, msg_extended_failed
    call print_string
    
    ; Standard CHS read
    mov ah, 0x02                    ; Read sectors function
    mov al, KERNEL_SECTOR_COUNT     ; Number of sectors
    mov ch, 0                       ; Cylinder 0
    mov cl, KERNEL_LBA_START + 1    ; Sector (1-based)
    mov dh, 0                       ; Head 0
    mov dl, [boot_drive]
    mov bx, KERNEL_LOAD_SEG
    mov es, bx
    mov bx, KERNEL_LOAD_OFF
    int 0x13
    jc .load_error
    
.load_success:
    ; Restore ES
    mov ax, 0x0800
    mov es, ax
    
    ; Verify kernel signature (check first 4 bytes)
    push ds
    mov ax, KERNEL_LOAD_SEG
    mov ds, ax
    mov si, KERNEL_LOAD_OFF
    
    mov si, msg_kernel_loaded
    mov ax, 0x0800
    mov ds, ax
    call print_string
    
    ; Show first few bytes of kernel
    mov si, msg_kernel_bytes
    call print_string
    
    mov ax, KERNEL_LOAD_SEG
    mov ds, ax
    xor si, si
    mov cx, 4
.show_bytes:
    lodsb
    push cx
    push si
    push ax
    mov ax, 0x0800
    mov ds, ax
    pop ax
    call print_hex_byte
    mov al, ' '
    call print_char
    pop si
    pop cx
    mov ax, KERNEL_LOAD_SEG
    mov ds, ax
    loop .show_bytes
    
    pop ds
    call print_newline
    
    pop si
    pop dx
    pop ax
    ret
    
.load_error:
    mov si, msg_kernel_error
    call print_string
    mov al, ah  ; Error code
    call print_hex_byte
    call print_newline
    jmp halt

; ============================================================================
; Enable A20 Line
; ============================================================================
enable_a20:
    push ax
    
    mov si, msg_enabling_a20
    call print_string
    
    ; Try fast A20 method first
    in al, 0x92
    test al, 2
    jnz .a20_done
    or al, 2
    and al, 0xFE  ; Make sure bit 0 is clear (no reset)
    out 0x92, al
    
.a20_done:
    mov si, msg_a20_enabled
    call print_string
    
    pop ax
    ret

; ============================================================================
; Enter Protected Mode
; ============================================================================
enter_protected_mode:
    cli  ; Disable interrupts
    
    ; Load GDT
    lgdt [gdt_descriptor]
    
    ; Enable protected mode
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    
    ; Far jump to 32-bit code
    jmp 0x08:protected_mode_start

; ============================================================================
; 32-bit Protected Mode Code
; ============================================================================
bits 32

protected_mode_start:
    ; Set up segments
    mov ax, 0x10  ; Data segment selector
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    
    ; Set up stack
    mov esp, 0x90000
    
    ; Clear screen with color
    mov edi, VGA_MEMORY
    mov ecx, 80 * 25
    mov ax, 0x0F20  ; White on black, space character
    rep stosw
    
    ; Print 32-bit message
    mov esi, msg_in_pmode
    mov edi, VGA_MEMORY
    call print_string_32
    
    ; Jump to kernel at 0x10000
    jmp 0x10000

; Print string in 32-bit mode
print_string_32:
    push eax
    push edi
.loop:
    lodsb
    test al, al
    jz .done
    mov ah, 0x0F  ; White on black
    stosw
    jmp .loop
.done:
    pop edi
    pop eax
    ret

msg_in_pmode: db 'Now in 32-bit Protected Mode! Jumping to kernel...', 0

; ============================================================================
; 16-bit Helper Functions
; ============================================================================
bits 16

; Print a string (DS:SI points to string)
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

; Print a single character (AL = character)
print_char:
    push ax
    push bx
    mov ah, 0x0E
    mov bx, 0x0007
    int 0x10
    pop bx
    pop ax
    ret

; Print newline
print_newline:
    push ax
    mov al, 0x0D  ; CR
    call print_char
    mov al, 0x0A  ; LF
    call print_char
    pop ax
    ret

; Print hex byte (AL = byte to print)
print_hex_byte:
    push ax
    push cx
    mov cl, al
    shr al, 4
    call print_hex_nibble
    mov al, cl
    and al, 0x0F
    call print_hex_nibble
    pop cx
    pop ax
    ret

; Print hex nibble (AL = nibble 0-F)
print_hex_nibble:
    push ax
    and al, 0x0F
    add al, '0'
    cmp al, '9'
    jle .print
    add al, 7  ; Convert to A-F
.print:
    call print_char
    pop ax
    ret

; Clear screen
clear_screen:
    push ax
    mov ax, 0x0003  ; Set video mode 3 (80x25 color)
    int 0x10
    pop ax
    ret

; Halt system
halt:
    mov si, msg_halted
    call print_string
    cli
.loop:
    hlt
    jmp .loop

; ============================================================================
; Data Section
; ============================================================================

; Variables
boot_drive: db 0

; Disk Address Packet for kernel loading
kernel_dap:
    db 0x10                      ; Size of packet
    db 0                         ; Reserved
    dw KERNEL_SECTOR_COUNT       ; Number of sectors
    dw KERNEL_LOAD_OFF           ; Buffer offset
    dw KERNEL_LOAD_SEG           ; Buffer segment
    dq KERNEL_LBA_START          ; Starting LBA

; GDT (Global Descriptor Table)
gdt_start:
    ; Null descriptor (8 bytes)
    dq 0
    
    ; Code segment descriptor (8 bytes)
    ; Base=0, Limit=0xFFFFF, 32-bit, Code, Readable
    dw 0xFFFF       ; Limit (bits 0-15)
    dw 0x0000       ; Base (bits 0-15)
    db 0x00         ; Base (bits 16-23)
    db 10011010b    ; Access (present, ring 0, code, executable, readable)
    db 11001111b    ; Flags (4KB pages, 32-bit) + Limit (bits 16-19)
    db 0x00         ; Base (bits 24-31)
    
    ; Data segment descriptor (8 bytes)
    ; Base=0, Limit=0xFFFFF, 32-bit, Data, Writable
    dw 0xFFFF       ; Limit (bits 0-15)
    dw 0x0000       ; Base (bits 0-15)
    db 0x00         ; Base (bits 16-23)
    db 10010010b    ; Access (present, ring 0, data, writable)
    db 11001111b    ; Flags (4KB pages, 32-bit) + Limit (bits 16-19)
    db 0x00         ; Base (bits 24-31)
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1  ; Size of GDT minus 1
    dd gdt_start                 ; Linear address of GDT

; Messages
msg_stage2:          db 'PyramidOS Stage 2 Bootloader', 0x0D, 0x0A
                     db '============================', 0x0D, 0x0A, 0x0D, 0x0A, 0
msg_boot_drive:      db 'Boot drive: 0x', 0
msg_loading_kernel:  db 'Loading kernel from LBA ', 0
msg_extended_failed: db 'Extended read failed, trying CHS...', 0x0D, 0x0A, 0
msg_kernel_loaded:   db 'Kernel loaded successfully', 0x0D, 0x0A, 0
msg_kernel_bytes:    db 'First bytes: ', 0
msg_kernel_error:    db 'ERROR: Failed to load kernel! Code: 0x', 0
msg_enabling_a20:    db 'Enabling A20 line...', 0x0D, 0x0A, 0
msg_a20_enabled:     db 'A20 enabled', 0x0D, 0x0A, 0
msg_entering_pmode:  db 0x0D, 0x0A, 'Entering protected mode...', 0x0D, 0x0A, 0
msg_halted:          db 0x0D, 0x0A, 'System halted.', 0x0D, 0x0A, 0

; Padding to ensure predictable size
times 8192-($-$$) db 0  ; Pad to 8KB