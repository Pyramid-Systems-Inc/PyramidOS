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
STAGE2_SECTOR_COUNT equ 4       ; Number of sectors to read for Stage 2 (adjust as needed)

start:
    ; Initialize segments
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00      ; Stack grows down from here

    ; Save boot drive
    mov [boot_drive], dl

    ; Print loading message
    mov si, msg_loading
    call print_string

    ; Load Stage 2
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
    
    mov dl, [boot_drive] ; Reload the boot drive into DL, as int 0x13 may have changed it.

    ; Jump to Stage 2 entry point
    jmp STAGE2_LOAD_SEGMENT:STAGE2_LOAD_OFFSET

load_error:
    mov si, msg_error
    call print_string
.hang:
    hlt
    jmp .hang

; Simple string printing routine
print_string:
    push ax
    mov ah, 0x0E        ; BIOS Teletype output
.loop:
    lodsb               ; Load byte [DS:SI] into AL, increment SI
    test al, al
    jz .done
    int 0x10            ; Print character
    jmp .loop
.done:
    pop ax
    ret

; Data
boot_drive:     db 0
msg_loading:    db 'Loading Stage 2...', 0x0D, 0x0A, 0
msg_error:      db 'Stage 2 load error!', 0x0D, 0x0A, 0

; Boot sector padding and signature
times 510-($-$$) db 0
dw 0xAA55
