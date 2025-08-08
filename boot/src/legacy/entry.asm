; boot/src/legacy/entry.asm (Corrected)
bits 16

section .text
    global stage2_entry_point
    global bios_print_char_asm
    global bios_read_sectors_lba

extern stage2_main

stage2_entry_point:
    ; When Stage 1 jumps here, CS is 0x0800. We must set DS, ES, and SS to match CS
    ; to create a "flat" 16-bit memory model for our C code.
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax

    ; Set up the stack pointer. The 'stack_top' label is defined in the .bss
    ; section by the linker, pointing to a safe area for the stack.
    mov sp, stack_top

    ; Pass the boot drive number (now correctly in DL) to stage2_main.
    ; The 16-bit C calling convention passes arguments on the stack.
    push dx

    ; Call the main C function
    call stage2_main

.hang:
    cli
    hlt
    jmp .hang

; --- BIOS Print Character Function ---
; void bios_print_char_asm(char c)
bios_print_char_asm:
    push bp
    mov bp, sp
    mov ah, 0x0E
    mov al, [bp+4]
    int 0x10
    pop bp
    ret

; --- BIOS Extended Disk Read Function (LBA) ---
; int bios_read_sectors_lba(unsigned char drive_num, void* dap_address)
; Returns 0 on success, 1 on failure (via AX).
bios_read_sectors_lba:
    push bp
    mov bp, sp
    pusha
    mov ah, 0x42
    mov dl, [bp+4]
    mov si, [bp+6]
    int 0x13
    jc .error
    popa
    mov ax, 0
    pop bp
    ret
.error:
    popa
    mov ax, 1
    pop bp
    ret

; Uninitialized data section
section .bss
    ; Reserve 1KB for the stack. The 'stack_top' label will be at the very end.
    stack_bottom:
        resb 1024
    stack_top: