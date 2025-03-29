; =============================================================================
; Pyramid Bootloader - Minimal Version
; =============================================================================
; A simplified bootloader that fits within 512 bytes
; =============================================================================

org 0x7C00            ; BIOS loads bootloader at this memory address
bits 16               ; Specify 16-bit code (Real Mode)

; =============================================================================
; Program Entry Point
; =============================================================================
start:
    ; Initialize segment registers
    xor ax, ax         ; Zero out ax
    mov ds, ax         ; Set data segment to 0
    mov es, ax         ; Set extra segment to 0
    mov ss, ax         ; Set stack segment to 0
    mov sp, 0x7C00     ; Set stack pointer just below bootloader

    ; Clear screen
    mov ah, 0x00       ; Set video mode function
    mov al, 0x03       ; Mode 3 = 80x25 text mode, 16 colors
    int 0x10

    ; Print welcome message
    mov si, msg_welcome
    call print_string

    ; Print ready message
    mov si, msg_ready
    call print_string

    ; Wait for keypress
    mov ah, 0x00
    int 0x16

    ; Print disk message
    mov si, msg_disk
    call print_string

    ; Attempt disk read
    mov ah, 0x02       ; BIOS read sector function
    mov al, 1          ; Read 1 sector
    mov ch, 0          ; Cylinder 0
    mov cl, 2          ; Sector 2 (1-based, sector after boot sector)
    mov dh, 0          ; Head 0
    mov dl, 0x80       ; Drive 0 (first hard disk)
    mov bx, 0x8000     ; Load to ES:BX (0:8000)
    int 0x13
    jc disk_error

    ; Disk read successful
    mov si, msg_disk_ok
    call print_string

    ; Halt system
halt:
    cli                ; Disable interrupts
    hlt                ; Halt CPU
    jmp halt           ; In case of interrupt, jump back to halt

disk_error:
    mov si, msg_disk_error
    call print_string
    jmp halt

; =============================================================================
; Function: print_string
; Purpose: Print a null-terminated string
; Input: DS:SI - Pointer to string
; =============================================================================
print_string:
    push ax
    push bx
    mov ah, 0x0E       ; BIOS teletype function
    mov bh, 0          ; Page number
    mov bl, 0x07       ; Light gray text on black

.loop:
    lodsb              ; Load byte at DS:SI into AL and increment SI
    test al, al        ; Check if character is null (0)
    jz .done           ; If null, we're done
    int 0x10           ; Print character
    jmp .loop          ; Continue with next character

.done:
    pop bx
    pop ax
    ret

; =============================================================================
; Data Section
; =============================================================================
msg_welcome:   db 'Pyramid Bootloader', 0x0D, 0x0A, 0
msg_ready:     db 'System ready', 0x0D, 0x0A, 0
msg_disk:      db 'Attempting disk read...', 0x0D, 0x0A, 0
msg_disk_error: db 'Disk read failed!', 0x0D, 0x0A, 0
msg_disk_ok:   db 'Disk read successful!', 0x0D, 0x0A, 0

; =============================================================================
; Boot Sector Padding and Signature
; =============================================================================
times 510-($-$$) db 0   ; Pad with zeros until 510 bytes
dw 0xAA55               ; Boot signature