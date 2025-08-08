; =============================================================================
; Pyramid Bootloader - Stage 1 (Minimal)
; =============================================================================
; Loads Stage 2 from disk and jumps to it.
; =============================================================================
org 0x7C00
bits 16

; Constants
STAGE2_LOAD_SEGMENT equ 0x0800  ; Segment where stage 2 will be loaded (0x8000 linear)
STAGE2_LOAD_OFFSET  equ 0x0000  ; Offset within the segment
STAGE2_START_SECTOR equ 2       ; Sector number to start reading Stage 2 from (1-based)
STAGE2_SECTOR_COUNT equ 32      ; Number of sectors to read for Stage 2 (16KB should be enough)

start:
    ; Disable interrupts during setup
    cli
    
    ; Initialize segments
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00      ; Stack grows down from here
    
    ; Enable interrupts
    sti

    ; Save boot drive
    mov [boot_drive], dl

    ; Clear screen
    mov ah, 0x00
    mov al, 0x03        ; 80x25 color text mode
    int 0x10

    ; Print loading message
    mov si, msg_loading
    call print_string

    ; Load Stage 2 using extended read (more reliable)
    mov ah, 0x42        ; Extended Read
    mov dl, [boot_drive]
    mov si, dap
    int 0x13
    jc try_standard_read ; If extended read fails, try standard

    jmp load_success

try_standard_read:
    ; Fallback to standard read
    mov ah, 0x02        ; BIOS Read Sectors function
    mov al, STAGE2_SECTOR_COUNT ; Number of sectors
    mov ch, 0           ; Cylinder 0
    mov cl, STAGE2_START_SECTOR ; Start sector
    mov dh, 0           ; Head 0
    mov dl, [boot_drive]; Boot drive
    mov bx, STAGE2_LOAD_SEGMENT
    mov es, bx          ; ES:BX = Load buffer (0x0800:0x0000)
    mov bx, STAGE2_LOAD_OFFSET
    int 0x13
    jc load_error       ; Jump if disk read error (carry flag set)

load_success:
    ; Print success message
    mov si, msg_success
    call print_string
    
    ; Restore boot drive in DL for Stage 2
    mov dl, [boot_drive]

    ; Jump to Stage 2 entry point
    jmp STAGE2_LOAD_SEGMENT:STAGE2_LOAD_OFFSET

load_error:
    mov si, msg_error
    call print_string
    
    ; Print error code
    mov si, msg_error_code
    call print_string
    mov al, ah          ; Error code is in AH
    call print_hex_byte
    
.hang:
    cli
    hlt
    jmp .hang

; Print a hex byte in AL
print_hex_byte:
    push ax
    push cx
    mov cl, 4
    shr al, cl          ; High nibble
    call print_hex_nibble
    pop cx
    pop ax
    and al, 0x0F        ; Low nibble
    call print_hex_nibble
    ret

; Print a hex nibble in AL (0-F)
print_hex_nibble:
    push ax
    and al, 0x0F
    add al, '0'
    cmp al, '9'
    jle .print
    add al, 7          ; Convert to A-F
.print:
    mov ah, 0x0E
    int 0x10
    pop ax
    ret

; Simple string printing routine
print_string:
    push ax
    push si
.loop:
    lodsb               ; Load byte [DS:SI] into AL, increment SI
    test al, al
    jz .done
    mov ah, 0x0E        ; BIOS Teletype output
    int 0x10            ; Print character
    jmp .loop
.done:
    pop si
    pop ax
    ret

; Data
boot_drive:     db 0

; Disk Address Packet for extended read
dap:
    db 0x10             ; Size of DAP
    db 0                ; Reserved
    dw STAGE2_SECTOR_COUNT ; Number of sectors
    dw STAGE2_LOAD_OFFSET  ; Offset
    dw STAGE2_LOAD_SEGMENT ; Segment
    dq STAGE2_START_SECTOR - 1 ; LBA (0-based)

; Messages
msg_loading:    db 'Pyramid Bootloader v1.0', 0x0D, 0x0A
                db 'Loading Stage 2...', 0x0D, 0x0A, 0
msg_success:    db 'Stage 2 loaded successfully!', 0x0D, 0x0A, 0
msg_error:      db 'ERROR: Failed to load Stage 2!', 0x0D, 0x0A, 0
msg_error_code: db 'Error code: 0x', 0

; Boot sector padding and signature
times 510-($-$$) db 0
dw 0xAA55