; boot/src/legacy/entry.asm
bits 16

section .text
    global stage2_entry_point
    global bios_print_char_asm
    global bios_read_sectors_lba ; Make the disk read function visible to linker

extern stage2_main

stage2_entry_point:
    ; Set up segments for C
    mov ax, data_seg
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0xFFFE ; Stack pointer at top of segment

    ; Retrieve boot drive saved by Stage 1.
    ; We assume Stage 1 code is still at 0x7C00.
    ; boot_drive is at offset 68 (0x44) from 0x7C00.
    ; A simple way: assume DL still holds the boot drive.
    ; For the C function call, the argument goes on the stack.
    push dx ; Push boot drive number (dl) as argument for stage2_main

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
    mov ah, 0x0E    ; BIOS Teletype
    mov al, [bp+4]  ; Get char from stack
    int 0x10
    pop bp
    ret

; --- BIOS Extended Disk Read Function (LBA) ---
; int bios_read_sectors_lba(unsigned char drive_num, void* dap_address)
; Returns 0 on success, 1 on failure (via AX).
bios_read_sectors_lba:
    push bp
    mov bp, sp

    ; Save registers that BIOS might corrupt
    pusha

    mov ah, 0x42         ; BIOS Extended Read function
    mov dl, [bp+4]       ; Arg 1: drive_num
    mov si, [bp+6]       ; Arg 2: dap_address (pointer to Disk Address Packet)
    int 0x13             ; Call BIOS disk services

    jc .error            ; Jump if Carry Flag is set (error)

    ; Success
    popa                 ; Restore registers
    mov ax, 0            ; Return 0 for success
    pop bp
    ret

.error:
    ; Failure
    popa                 ; Restore registers
    mov ax, 1            ; Return 1 for failure
    pop bp
    ret

section .data align=16
data_seg:

section .bss align=16
stack_bottom:
    resb 1024
stack_top: