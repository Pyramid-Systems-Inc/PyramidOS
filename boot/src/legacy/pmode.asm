; boot/src/legacy/pmode.asm
; Protected mode transition code
bits 16

section .text
    global enter_protected_mode_and_jump

; GDT structure
align 8
gdt_start:
    ; Null descriptor (8 bytes)
    dq 0x0
    
    ; Code segment descriptor (8 bytes)
    ; Base=0, Limit=0xFFFFF, 32-bit, Code, Readable
    dw 0xFFFF       ; Limit (bits 0-15)
    dw 0x0          ; Base (bits 0-15)
    db 0x0          ; Base (bits 16-23)
    db 10011010b    ; Access byte (present, ring 0, code segment, executable, readable)
    db 11001111b    ; Flags (4KB pages, 32-bit) + Limit (bits 16-19)
    db 0x0          ; Base (bits 24-31)
    
    ; Data segment descriptor (8 bytes)
    ; Base=0, Limit=0xFFFFF, 32-bit, Data, Writable
    dw 0xFFFF       ; Limit (bits 0-15)
    dw 0x0          ; Base (bits 0-15)
    db 0x0          ; Base (bits 16-23)
    db 10010010b    ; Access byte (present, ring 0, data segment, writable)
    db 11001111b    ; Flags (4KB pages, 32-bit) + Limit (bits 16-19)
    db 0x0          ; Base (bits 24-31)
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1  ; Size of GDT minus 1
    dd gdt_start                 ; Linear address of GDT

enter_protected_mode_and_jump:
    ; Function expects kernel address in stack
    ; We're in real mode, so we need to be careful with addressing
    
    ; Disable interrupts
    cli
    
    ; Enable A20 line (using fast A20 method)
    in al, 0x92
    or al, 2
    out 0x92, al
    
    ; Load GDT
    lgdt [gdt_descriptor]
    
    ; Enable protected mode by setting PE bit in CR0
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    
    ; Far jump to flush CPU pipeline and enter 32-bit code
    jmp 0x08:protected_mode_start
    
bits 32
protected_mode_start:
    ; We're now in 32-bit protected mode!
    
    ; Set up all segment registers
    mov ax, 0x10        ; Data segment selector (GDT entry 2)
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    
    ; Set up stack pointer
    mov esp, 0x90000    ; Stack at a safe location
    
    ; Jump to kernel at 0x10000 (the address where we loaded it)
    mov eax, 0x10000
    jmp eax