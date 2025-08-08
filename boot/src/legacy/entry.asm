; boot/src/legacy/entry.asm
; Stage 2 entry point and BIOS service wrappers
bits 16

section .text
    global stage2_entry_point
    global bios_print_char_asm
    global bios_read_sectors_lba
    global bios_print_string_asm

extern stage2_main

stage2_entry_point:
    ; We're entered at 0x0800:0x0000 (physical 0x8000)
    ; DL contains boot drive number
    
    ; Save boot drive
    push dx
    
    ; Print Stage 2 entry message for debugging
    mov si, stage2_msg
    call print_string_local
    
    ; Set up segments
    mov ax, 0x0800
    mov ds, ax
    mov es, ax
    
    ; Set up stack in safe location (below bootloader)
    xor ax, ax
    mov ss, ax
    mov sp, 0x7C00      ; Stack from 0x0000:0x7C00 downward
    
    ; Restore boot drive and prepare for C call
    pop dx
    xor dh, dh          ; Clear DH to make DX = 0x00XX where XX is the drive number
    push dx             ; Push as a word parameter for C function
    
    ; Call the main C function
    call stage2_main
    
    ; Clean up the stack after the call (cdecl convention)
    add sp, 2           ; Remove the parameter we pushed
    
    ; If stage2_main returns, print error and hang
    mov si, main_returned_msg
    call print_string_local

.hang:
    cli
    hlt
    jmp .hang

; Local print string for Stage 2 initialization
print_string_local:
    push ax
    push si
.loop:
    lodsb
    test al, al
    jz .done
    mov ah, 0x0E
    xor bh, bh
    int 0x10
    jmp .loop
.done:
    pop si
    pop ax
    ret

; void bios_print_char_asm(char c)
bios_print_char_asm:
    push bp
    mov bp, sp
    push bx             ; Preserve BX
    mov ah, 0x0E        ; BIOS teletype output
    mov al, [bp+4]      ; Get character parameter
    xor bh, bh          ; Page 0
    mov bl, 0x07        ; Light gray on black
    int 0x10
    pop bx
    pop bp
    ret

; void bios_print_string_asm(const char* str)
bios_print_string_asm:
    push bp
    mov bp, sp
    push si
    push bx
    mov si, [bp+4]      ; Get string pointer
.loop:
    lodsb               ; Load byte at [SI] into AL
    test al, al         ; Check for null terminator
    jz .done
    mov ah, 0x0E
    xor bh, bh
    mov bl, 0x07
    int 0x10
    jmp .loop
.done:
    pop bx
    pop si
    pop bp
    ret

; int bios_read_sectors_lba(unsigned char drive_num, void* dap_address)
bios_read_sectors_lba:
    push bp
    mov bp, sp
    pusha
    
    ; Use extended read
    mov ah, 0x42        ; Extended read
    mov dl, [bp+4]      ; Drive number
    mov si, [bp+6]      ; DAP address
    int 0x13
    jc .error
    
    popa
    xor ax, ax          ; Return 0 for success
    pop bp
    ret
    
.error:
    popa
    movzx ax, ah        ; Return error code
    pop bp
    ret

; Data section
section .data
stage2_msg:         db 'Stage 2 entry point reached!', 0x0D, 0x0A, 0
main_returned_msg:  db 0x0D, 0x0A, 'ERROR: stage2_main returned!', 0x0D, 0x0A, 0