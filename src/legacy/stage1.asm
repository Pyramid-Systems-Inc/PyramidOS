; =============================================================================
; Pyramid Bootloader - Stage 1
; =============================================================================
; First stage bootloader that fits within 512 bytes
; =============================================================================

org 0x7C00            ; BIOS loads bootloader at this memory address
bits 16               ; Specify 16-bit code (Real Mode)

; =============================================================================
; Constants
; =============================================================================
%define STAGE2_SEGMENT 0x0800     ; Segment where stage 2 will be loaded (0x8000)
%define STAGE2_OFFSET  0x0000     ; Offset where stage 2 will be loaded
%define STAGE2_SECTORS 12         ; Number of sectors for stage 2 (Increased from 8)
%define BOOT_DELAY     5          ; Countdown time in seconds

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

    ; Save boot drive number
    mov [boot_drive], dl   ; Store the boot drive number provided by BIOS

    ; Print welcome message
    mov si, msg_welcome
    call print_string

    ; Load stage 2 (now contains C code + helpers)
    call load_stage2
    
    ; Prompt user to press F1 to continue
    mov si, msg_prompt
    call print_string
    
    ; Set up countdown timer
    mov byte [countdown], BOOT_DELAY + 1
    
    ; Start countdown
    call countdown_timer
    
    ; Check if user wants to proceed
    call check_user_input
    
    ; If we get here, continue to Stage 2
    mov si, msg_launching
    call print_string
    
    ; Small delay to show message
    mov cx, 0xFFFF
.delay:
    loop .delay

    ; Jump to stage 2 entry point (which will be defined in stage2_entry.asm)
    ; The linker will place stage2_entry.asm at STAGE2_SEGMENT:STAGE2_OFFSET
    jmp STAGE2_SEGMENT:STAGE2_OFFSET

; =============================================================================
; Function: countdown_timer
; Purpose: Display countdown and update timer
; =============================================================================
countdown_timer:
    push ax
    push cx
    
.countdown_loop:
    ; Decrement countdown
    dec byte [countdown]
    jz .countdown_done  ; If zero, we're done
    
    ; Print current countdown value
    mov si, msg_countdown_prefix
    call print_string
    
    mov al, [countdown]
    add al, '0'         ; Convert to ASCII
    mov ah, 0x0E        ; BIOS teletype function
    mov bh, 0           ; Page number
    mov bl, 0x07        ; Light gray text on black
    int 0x10            ; Print character
    
    mov si, msg_countdown_suffix
    call print_string
    
    ; Delay for approximately 1 second
    mov cx, 0
    mov dx, 0xFFFF
.delay_loop:
    ; Check for keypress during delay
    mov ah, 0x01        ; BIOS check keyboard status
    int 0x16
    jnz .key_pressed    ; If key pressed, exit countdown
    
    ; Continue delay
    dec dx
    jnz .delay_loop
    dec cx
    jnz .delay_loop
    
    ; Continue countdown
    jmp .countdown_loop
    
.key_pressed:
    ; Consume the key press
    mov ah, 0x00
    int 0x16
    
.countdown_done:
    pop cx
    pop ax
    ret

; =============================================================================
; Function: check_user_input
; Purpose: Check if user pressed F1 to continue
; Waits until timeout or F1 is pressed
; =============================================================================
check_user_input:
    push ax
    
    ; Check if countdown already reached zero
    cmp byte [countdown], 0
    je .continue        ; If zero, continue to Stage 2
    
    ; Main input loop
.input_loop:
    ; Check for keypress
    mov ah, 0x01        ; BIOS check keyboard status
    int 0x16
    jz .no_key          ; If no key, check countdown
    
    ; Key pressed, get the key
    mov ah, 0x00
    int 0x16
    
    ; Check if F1 was pressed (scan code 0x3B)
    cmp ah, 0x3B
    je .continue        ; If F1, proceed to Stage 2
    
    ; Check if Escape was pressed (scan code 0x01)
    cmp ah, 0x01
    je .reboot          ; If Escape, reboot system
    
    ; Other key, ignore and continue loop
    jmp .input_loop
    
.no_key:
    ; Check if countdown reached zero
    cmp byte [countdown], 0
    jne .input_loop     ; If not zero, continue looping
    
.continue:
    ; User wants to continue to Stage 2 or timeout occurred
    pop ax
    ret
    
.reboot:
    ; User pressed Escape, reboot system
    int 0x19            ; BIOS reboot function

; =============================================================================
; Function: load_stage2
; Purpose: Load the second stage bootloader (C + helpers) from disk
; =============================================================================
load_stage2:
    mov si, msg_disk
    call print_string

    ; Set up disk read
    mov ah, 0x02       ; BIOS read sector function
    mov al, STAGE2_SECTORS ; Number of sectors to read
    mov ch, 0          ; Cylinder 0
    mov cl, 2          ; Sector 2 (1-based, sector after boot sector)
    mov dh, 0          ; Head 0
    mov dl, [boot_drive] ; Use the saved boot drive number
    
    ; Set buffer address to ES:BX
    mov bx, STAGE2_SEGMENT
    mov es, bx
    mov bx, STAGE2_OFFSET
    
    ; Read from disk
    int 0x13
    jc disk_error

    ; Success
    mov si, msg_disk_ok
    call print_string
    ret

disk_error:
    mov si, msg_disk_error
    call print_string
    
    ; Wait for keypress before reboot
    mov ah, 0x00
    int 0x16
    
    ; Reboot
    int 0x19

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
; Data Section (Stage 1)
; =============================================================================
boot_drive:     db 0    ; Storage for boot drive number
countdown:      db BOOT_DELAY     ; Countdown timer
msg_welcome:   db 'Pyramid Bootloader', 0x0D, 0x0A, 0
msg_loading:   db 'Loading stage 2...', 0x0D, 0x0A, 0
msg_disk:      db 'Reading from disk...', 0x0D, 0x0A, 0
msg_disk_error: db 'Disk read failed! Press any key to reboot.', 0x0D, 0x0A, 0
msg_disk_ok:   db 'Stage 2 loaded successfully!', 0x0D, 0x0A, 0
msg_prompt:    db 0x0D, 0x0A, 'Press F1 to continue to Stage 2, or ESC to reboot', 0x0D, 0x0A, 0
msg_countdown_prefix: db 'Continuing in ', 0
msg_countdown_suffix: db ' seconds...', 0x0D, 0x0A, 0
msg_launching: db 0x0D, 0x0A, 'Launching Stage 2...', 0x0D, 0x0A, 0

; =============================================================================
; Boot Sector Padding and Signature
; =============================================================================
times 510-($-$$) db 0   ; Pad with zeros until 510 bytes
dw 0xAA55               ; Boot signature
