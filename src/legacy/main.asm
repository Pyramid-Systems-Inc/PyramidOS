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

    ; Load stage 2 in the background while waiting for user input
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

    ; Jump to stage 2
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
; Purpose: Load the second stage bootloader from disk
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
; Data Section
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

; =============================================================================
; Stage 2 Bootloader
; =============================================================================
stage2_start:
; Stage 2 variables and constants
%define COLOR_TITLE     0x1F    ; Blue background, white text
%define COLOR_NORMAL    0x07    ; Black background, light gray text
%define COLOR_SUCCESS   0x0A    ; Black background, light green text
%define COLOR_ERROR     0x0C    ; Black background, light red text
%define COLOR_PROMPT    0x0B    ; Black background, light cyan text

%define BUFFER_SIZE     64      ; Command buffer size
%define NEWLINE         0x0D, 0x0A

; A20 Line related constants
%define KBC_DATA_PORT   0x60    ; Keyboard controller data port
%define KBC_CMD_PORT    0x64    ; Keyboard controller command port
%define KBC_STATUS_PORT 0x64    ; Keyboard controller status port
%define KBC_WRITE_CMD   0xD1    ; Write next byte to controller output port
%define KBC_READ_STATUS 0xE0    ; Read controller status
%define KBC_OUTPUT_PORT 0xDF    ; Enable A20 line bit (bit 1)
%define FAST_A20_PORT   0x92    ; Fast A20 System Control Port A
%define FAST_A20_ENABLE 0x02    ; Bit 1 enables A20

%define KBC_STATUS_OUTPUT_FULL 0x01 ; Output buffer full
%define KBC_STATUS_INPUT_FULL  0x02 ; Input buffer full
%define KBC_STATUS_TIMEOUT     0x40 ; Timeout flag
%define KBC_MAX_ATTEMPTS        10  ; Maximum attempts for keyboard controller

; Protected Mode related constants
%define CODE_SEG        0x08    ; Code segment selector in GDT (8 bytes offset)
%define DATA_SEG        0x10    ; Data segment selector in GDT (16 bytes offset)

; =============================================================================
; Stage 2 Entry Point
; =============================================================================
    ; === Original Stage 2 Initialization ===
    ; Initialize segment registers
    mov ax, STAGE2_SEGMENT
    mov ds, ax         ; Set data segment to stage 2 segment
    mov es, ax         ; Set extra segment to stage 2 segment

    ; Save boot drive number passed from Stage 1
    mov [s2_boot_drive], dl

    ; Clear screen
    call clear_screen

    ; Set cursor position to top-left after clearing
    mov ah, 0x02       ; BIOS set cursor position function
    mov bh, 0          ; Page number 0
    mov dh, 0          ; Row 0
    mov dl, 0          ; Column 0
    int 0x10

    ; Print stage 2 welcome
    mov bl, COLOR_TITLE
    mov si, s2_msg_title
    call print_colored_string

    ; Print version info
    mov bl, COLOR_NORMAL
    mov si, s2_msg_welcome
    call print_colored_string

    ; Print ready message
    mov bl, COLOR_SUCCESS
    mov si, s2_msg_ready
    call print_colored_string

    ; Enter command loop
    jmp command_loop

; === Debugging Code Removed ===
;    ; === Simple Test: Print 'S' and Hang ===
;    mov ah, 0x0E       ; BIOS Teletype
;    mov al, 'S'        ; Character to print
;    mov bl, 0x0F       ; Bright White on Black
;    mov bh, 0          ; Page 0
;    int 0x10           ; Print character
;
;    ; === Restore Segment Register Initialization ===
;    mov ax, STAGE2_SEGMENT
;    mov ds, ax         ; Set data segment to stage 2 segment
;    mov es, ax         ; Set extra segment to stage 2 segment
;
;    ; === Restore Screen Clear ===
;    ; call clear_screen  ; <-- Keep this commented out for now
;
;    ; === Print 'X' to test execution flow ===
;    mov ah, 0x0E       ; BIOS Teletype
;    mov al, 'X'        ; Character to print
;    mov bl, 0x0F       ; Bright White on Black
;    mov bh, 0          ; Page 0
;    int 0x10           ; Print character
;
; .hang:
;    jmp .hang          ; Loop indefinitely

; -----------------------------------------------------------------------------
; Command Line Interface
; -----------------------------------------------------------------------------
command_loop:
    ; Print prompt
    mov bl, COLOR_PROMPT
    mov si, prompt
    call print_colored_string

    ; Clear command buffer before reading new command
    mov di, command_buffer
    mov cx, BUFFER_SIZE
    xor al, al
    rep stosb
    
    ; Read command
    mov di, command_buffer
    call read_line

    ; Check if command is empty
    mov si, command_buffer
    cmp byte [si], 0
    je command_loop    ; If empty, print prompt again

    ; Process commands
    call parse_command

    ; Continue command loop
    jmp command_loop

; -----------------------------------------------------------------------------
; Read a line of input
; Input: DI points to buffer
; -----------------------------------------------------------------------------
read_line:
    push ax
    push cx
    push di
    mov cx, 0          ; Character counter

.loop:
    ; Use INT 16h to wait for keystroke
    xor ax, ax         ; AH = 0x00, wait for keystroke
    int 0x16           ; Result in AL = ASCII character

    ; Handle special keys
    cmp al, 0x08       ; Backspace?
    je .backspace

    cmp al, 0x0D       ; Enter?
    je .done

    ; Check for buffer overflow
    cmp cx, BUFFER_SIZE-2 ; Leave room for null terminator
    jae .loop

    ; Echo character to screen
    mov ah, 0x0E       ; BIOS teletype function
    mov bh, 0          ; Page number
    int 0x10

    ; Store character in buffer
    stosb              ; Store character and increment DI
    inc cx
    jmp .loop

.backspace:
    cmp cx, 0          ; Beginning of line?
    je .loop           ; If at beginning, ignore backspace

    dec di             ; Move buffer pointer back
    dec cx             ; Decrement character counter
    
    ; Echo backspace (move cursor back, print space, move cursor back again)
    mov ah, 0x0E       ; BIOS teletype function
    mov bh, 0          ; Page number
    
    mov al, 0x08       ; Backspace
    int 0x10
    
    mov al, ' '        ; Space (to erase character)
    int 0x10
    
    mov al, 0x08       ; Backspace again (to move cursor back)
    int 0x10
    
    jmp .loop

.done:
    ; Print newline
    mov ah, 0x0E       ; BIOS teletype function
    mov bh, 0          ; Page number
    
    mov al, 0x0D       ; Carriage return
    int 0x10
    
    mov al, 0x0A       ; Line feed
    int 0x10

    ; Null-terminate the string
    mov byte [di], 0

    pop di
    pop cx
    pop ax
    ret

; -----------------------------------------------------------------------------
; Parse and execute command
; -----------------------------------------------------------------------------
parse_command:
    push si
    push di
    push ax
    
    ; Debug: Display received command
    mov bl, COLOR_NORMAL
    mov si, dbg_cmd_received
    call print_colored_string
    
    mov si, command_buffer
    mov bl, COLOR_NORMAL
    call print_colored_string
    call print_newline

    ; Parse command
    mov si, command_buffer
    mov di, cmd_help
    call string_compare
    je do_help

    mov si, command_buffer
    mov di, cmd_clear
    call string_compare
    je do_clear

    mov si, command_buffer
    mov di, cmd_info
    call string_compare
    je do_info

    mov si, command_buffer
    mov di, cmd_reboot
    call string_compare
    je do_reboot
    
    mov si, command_buffer
    mov di, cmd_a20
    call string_compare
    je do_a20
    
    mov si, command_buffer
    mov di, cmd_pmode
    call string_compare
    je do_pmode

    mov si, command_buffer
    mov di, cmd_fsinfo
    call string_compare
    je do_fsinfo

    ; Command not recognized
    mov bl, COLOR_ERROR
    mov si, msg_unknown
    call print_colored_string
    
    pop ax
    pop di
    pop si
    ret

; -----------------------------------------------------------------------------
; Command handlers
; -----------------------------------------------------------------------------
do_help:
    mov bl, COLOR_NORMAL
    mov si, help_text
    call print_colored_string
    ret

do_clear:
    call clear_screen
    ; Print title again
    mov bl, COLOR_TITLE
    mov si, s2_msg_title
    call print_colored_string
    ret

do_info:
    mov bl, COLOR_NORMAL
    mov si, info_text
    call print_colored_string
    
    ; Display boot drive information
    mov bl, COLOR_NORMAL
    mov si, info_boot_drive
    call print_colored_string
    
    ; Convert drive number to hex
    mov al, [s2_boot_drive]
    xor ah, ah
    call print_hex_word
    call print_newline

    ; Get memory size
    call get_memory_size
    ret

do_reboot:
    ; Reboot system via keyboard controller
    mov bl, COLOR_NORMAL
    mov si, msg_rebooting
    call print_colored_string
    
    ; Small delay to show message
    mov cx, 0xFFFF
.delay:
    loop .delay
    
    ; Reset via keyboard controller
    mov al, 0xFE
    out 0x64, al
    
    ; If that fails, jump to reset vector
    jmp 0xFFFF:0x0000

do_a20:
    mov bl, COLOR_NORMAL
    mov si, msg_a20_start
    call print_colored_string
    
    ; First check if A20 is already enabled
    call check_a20
    cmp ax, 1
    je .already_enabled
    
    ; Try to enable A20 using keyboard controller
    call enable_a20_kbc
    
    ; Verify that A20 is now enabled
    call check_a20
    cmp ax, 1
    je .success
    
    ; If KBC method failed, try Fast A20 method
    mov bl, COLOR_NORMAL
    mov si, msg_a20_fast
    call print_colored_string
    
    call enable_a20_fast
    
    ; Check A20 status again
    call check_a20
    cmp ax, 1
    je .success
    
    ; If both methods failed
    mov bl, COLOR_ERROR
    mov si, msg_a20_failed
    call print_colored_string
    ret
    
.already_enabled:
    mov bl, COLOR_SUCCESS
    mov si, msg_a20_already
    call print_colored_string
    ret
    
.success:
    mov bl, COLOR_SUCCESS
    mov si, msg_a20_success
    call print_colored_string
    ret

do_pmode:
    mov bl, COLOR_NORMAL
    mov si, msg_pmode_start
    call print_colored_string
    
    ; First enable A20 line if it's not already enabled
    call check_a20
    cmp ax, 1
    je .a20_enabled
    
    ; Try to enable A20
    call enable_a20_kbc
    call check_a20
    cmp ax, 1
    jne .try_fast_a20
    jmp .a20_enabled
    
.try_fast_a20:
    call enable_a20_fast
    call check_a20
    cmp ax, 1
    jne .a20_failed
    
.a20_enabled:
    mov bl, COLOR_SUCCESS
    mov si, msg_a20_success
    call print_colored_string
    
    ; Continue with protected mode transition
    mov bl, COLOR_NORMAL
    mov si, msg_pmode_gdt
    call print_colored_string
    
    ; Set up IDT
    mov bl, COLOR_NORMAL
    mov si, msg_pmode_idt
    call print_colored_string
    
    ; Load GDT and switch to protected mode
    call enter_protected_mode
    
    ; Note: If successful, we should never return here
    ; This code will only execute if protected mode transition fails
    mov bl, COLOR_ERROR
    mov si, msg_pmode_failed
    call print_colored_string
    ret
    
.a20_failed:
    mov bl, COLOR_ERROR
    mov si, msg_a20_failed
    call print_colored_string
    
    mov bl, COLOR_ERROR
    mov si, msg_pmode_requires_a20
    call print_colored_string
    ret

do_fsinfo:
    mov bl, COLOR_NORMAL
    mov si, fs_msg_parsing
    call print_colored_string

    call parse_bpb

    ; Check if parsing was successful (simple check for now)
    cmp byte [fs_info_parsed], 1
    jne .fs_fail

    mov bl, COLOR_SUCCESS
    mov si, fs_msg_ok
    call print_colored_string

    ; Print extracted values
    mov bl, COLOR_NORMAL
    mov si, fs_msg_bytes_per_sector
    call print_colored_string
    mov ax, [bpb_bytes_per_sector]
    call print_hex_word
    call print_newline

    mov si, fs_msg_sectors_per_cluster
    call print_colored_string
    mov al, [bpb_sectors_per_cluster]
    xor ah, ah
    call print_hex_word
    call print_newline

    mov si, fs_msg_reserved_sectors
    call print_colored_string
    mov ax, [bpb_reserved_sectors]
    call print_hex_word
    call print_newline

    mov si, fs_msg_num_fats
    call print_colored_string
    mov al, [bpb_num_fats]
    xor ah, ah
    call print_hex_word
    call print_newline

    mov si, fs_msg_root_entries
    call print_colored_string
    mov ax, [bpb_root_entries]
    call print_hex_word
    call print_newline

    mov si, fs_msg_sectors_per_fat
    call print_colored_string
    mov ax, [bpb_sectors_per_fat16]
    call print_hex_word
    call print_newline

    ret

.fs_fail:
    mov bl, COLOR_ERROR
    mov si, fs_msg_fail
    call print_colored_string
    ret

; -----------------------------------------------------------------------------
; Get and display memory size
; -----------------------------------------------------------------------------
get_memory_size:
    ; Use INT 15h, AH=88h to get extended memory size
    mov ah, 0x88
    int 0x15
    jc .error
    
    ; AX = KB of contiguous memory starting at 1MB
    push ax
    
    ; Print memory size
    mov bl, COLOR_SUCCESS
    mov si, mem_info
    call print_colored_string
    
    ; Convert AX to decimal
    pop ax
    add ax, 1024  ; Add 1MB (1024KB) for conventional memory
    
    ; Convert to MB (divide by 1024)
    mov cx, 10
    mov dx, 0
    div cx
    
    ; Print the hundreds digit
    push dx
    add al, '0'
    mov ah, 0x0E
    mov bh, 0
    int 0x10
    
    ; Print decimal point
    mov al, '.'
    int 0x10
    
    ; Print the tenths digit
    pop ax
    add al, '0'
    int 0x10
    
    ; Print "MB"
    mov si, mb_text
    mov bl, COLOR_SUCCESS
    call print_colored_string
    
    ret

.error:
    mov bl, COLOR_ERROR
    mov si, mem_error
    call print_colored_string
    ret

; =============================================================================
; Utility Functions
; =============================================================================

; -----------------------------------------------------------------------------
; Clear the screen (Using Scroll Method Again)
; -----------------------------------------------------------------------------
clear_screen:
    push ax
    push bx
    push cx
    push dx

    mov ah, 0x06       ; Scroll window up function
    mov al, 0          ; Scroll all lines (0 = clear entire window)
    mov bh, 0x07       ; Attribute: Light gray on black (normal)
    mov cx, 0          ; Start row/col = 0,0
    mov dh, 24         ; End row = 24 (0-based)
    mov dl, 79         ; End col = 79 (0-based)
    int 0x10

    ; NOTE: Cursor position is set explicitly after this call in stage2_start

    pop dx
    pop cx
    pop bx
    pop ax
    ret

; -----------------------------------------------------------------------------
; Compare two strings
; Input: SI, DI point to strings
; Output: ZF set if strings are equal
; -----------------------------------------------------------------------------
string_compare:
    push ax
    push si
    push di

.loop:
    mov al, [si]
    mov ah, [di]
    
    ; If both characters are zero, strings are equal
    cmp al, 0
    jne .not_end
    cmp ah, 0
    je .equal
    jmp .not_equal

.not_end:
    ; Compare characters
    cmp al, ah
    jne .not_equal
    
    ; Move to next character
    inc si
    inc di
    jmp .loop

.not_equal:
    ; Clear ZF
    or al, 1
    jmp .done

.equal:
    ; Set ZF
    xor al, al

.done:
    pop di
    pop si
    pop ax
    ret

; =============================================================================
; Function: print_colored_string
; Purpose: Print a null-terminated string with color
; Input: DS:SI - Pointer to string, BL - Color attribute
; =============================================================================
print_colored_string:
    push ax
    push bx
    push si
    
    mov ah, 0x0E       ; BIOS teletype function
    mov bh, 0          ; Page number
    ; BL contains color (passed as parameter)

.loop:
    lodsb              ; Load byte at DS:SI into AL and increment SI
    test al, al        ; Check if character is null (0)
    jz .done           ; If null, we're done
    int 0x10           ; Print character
    jmp .loop          ; Continue with next character

.done:
    pop si
    pop bx
    pop ax
    ret

; =============================================================================
; Stage 2 Data Section
; =============================================================================
s2_boot_drive:   db 0              ; Storage for boot drive number in stage 2
s2_msg_title:   db 'Pyramid Bootloader - Stage 2', NEWLINE, 0
s2_msg_welcome: db 'Version 0.4 - Multi-stage Bootloader', NEWLINE, 0
s2_msg_ready:   db 'System ready', NEWLINE, NEWLINE, 0
msg_unknown:    db 'Unknown command. Type "help" for available commands.', NEWLINE, 0
msg_rebooting:  db 'Rebooting system...', NEWLINE, 0
mem_info:       db 'System memory: ', 0
mem_error:      db 'Unable to detect memory size.', NEWLINE, 0
mb_text:        db ' MB', NEWLINE, 0
msg_a20_start:   db 'Enabling A20 line...', NEWLINE, 0
msg_a20_fast:    db 'Trying Fast A20 method...', NEWLINE, 0
msg_a20_success: db 'A20 line enabled successfully', NEWLINE, 0
msg_a20_failed:  db 'Failed to enable A20 line!', NEWLINE, 0
msg_a20_already: db 'A20 line is already enabled', NEWLINE, 0
msg_pmode_start:        db 'Preparing to enter protected mode...', NEWLINE, 0
msg_pmode_gdt:          db 'Setting up GDT...', NEWLINE, 0
msg_pmode_idt:          db 'Setting up IDT...', NEWLINE, 0
msg_pmode_failed:       db 'Failed to enter protected mode!', NEWLINE, 0
msg_pmode_requires_a20: db 'Protected mode requires A20 line to be enabled!', NEWLINE, 0
info_boot_drive:        db 'Boot drive: 0x', 0
dbg_cmd_received:       db 'Command received: ', 0

prompt:        db '> ', 0

; Available commands
cmd_help:      db 'help', 0
cmd_clear:     db 'clear', 0
cmd_info:      db 'info', 0
cmd_reboot:    db 'reboot', 0
cmd_a20:       db 'a20', 0
cmd_pmode:     db 'pmode', 0
cmd_fsinfo:    db 'fsinfo', 0

; Help text
help_text:     db 'Available commands:', NEWLINE
               db '  help   - Display this help text', NEWLINE
               db '  clear  - Clear the screen', NEWLINE
               db '  info   - Display system information', NEWLINE
               db '  a20    - Enable A20 line', NEWLINE
               db '  pmode  - Enter 32-bit protected mode', NEWLINE
               db '  reboot - Reboot the system', NEWLINE
               db '  fsinfo - Show FAT filesystem info', NEWLINE, 0

; Info text
info_text:     db 'Pyramid Bootloader System Information', NEWLINE
               db '---------------------------------', NEWLINE
               db 'Boot drive: 80h (First hard disk)', NEWLINE, 0

; File System Info Storage
bpb_bytes_per_sector:   dw 0
bpb_sectors_per_cluster: db 0
bpb_reserved_sectors:   dw 0
bpb_num_fats:           db 0
bpb_root_entries:       dw 0
bpb_total_sectors16:    dw 0
bpb_sectors_per_fat16:  dw 0
fs_info_parsed:         db 0 ; Flag to check if BPB was parsed

fs_msg_parsing: db 'Parsing FAT BPB...', NEWLINE, 0
fs_msg_ok:      db 'FAT BPB parsed successfully.', NEWLINE, 0
fs_msg_fail:    db 'FAT BPB parsing failed (invalid signature?).', NEWLINE, 0
fs_msg_bytes_per_sector: db '  Bytes/Sector: 0x', 0
fs_msg_sectors_per_cluster: db '  Sectors/Cluster: 0x', 0
fs_msg_reserved_sectors: db '  Reserved Sectors: 0x', 0
fs_msg_num_fats:         db '  Num FATs: 0x', 0
fs_msg_root_entries:     db '  Root Entries: 0x', 0
fs_msg_sectors_per_fat:  db '  Sectors/FAT: 0x', 0

; Command buffer
command_buffer: times BUFFER_SIZE db 0

; -----------------------------------------------------------------------------
; Function: check_a20
; Purpose: Check if A20 line is enabled
; Returns: AX = 1 if A20 is enabled, 0 if disabled
;-----------------------------------------------------------------------------
check_a20:
    pushf
    push ds
    push es
    push di
    push si
    
    ; Set ES:DI to 0000:0500 and DS:SI to FFFF:0510
    xor ax, ax          ; AX = 0
    mov es, ax          ; ES = 0
    mov di, 0x0500      ; ES:DI = 0000:0500
    
    mov ax, 0xFFFF      ; AX = FFFF
    mov ds, ax          ; DS = FFFF
    mov si, 0x0510      ; DS:SI = FFFF:0510 
                        ; This wraps to 0000:0500 if A20 is disabled
    
    ; Save original values
    mov ax, [es:di]
    push ax             ; Save value at 0000:0500
    mov ax, [ds:si]
    push ax             ; Save value at FFFF:0510
    
    ; Write different values to test
    mov byte [es:di], 0x00
    mov byte [ds:si], 0xFF
    
    ; Add small delay to settle
    mov cx, 0x100
.delay:
    loop .delay
    
    ; Check if values stayed different
    mov al, [es:di]
    cmp al, 0x00        ; Should still be 0x00
    jne .different      ; If not, A20 is on
    
    mov al, [ds:si]
    cmp al, 0xFF        ; Should still be 0xFF
    jne .different      ; If not, something is wrong
    
    ; If we got here, they're the same, A20 is off
    mov ax, 0
    jmp .restore
    
.different:
    mov ax, 1           ; A20 is enabled
    
.restore:
    ; Restore original values
    pop bx              ; Get saved value for FFFF:0510
    mov [ds:si], bx
    pop bx              ; Get saved value for 0000:0500
    mov [es:di], bx
    
    pop si
    pop di
    pop es
    pop ds
    popf
    ret

;-----------------------------------------------------------------------------
; Function: enable_a20_kbc
; Purpose: Enable A20 line using keyboard controller with improved error handling
;-----------------------------------------------------------------------------
enable_a20_kbc:
    pushf
    push ax
    push cx
    cli                 ; Disable interrupts
    
    ; Initialize attempt counter
    mov cx, KBC_MAX_ATTEMPTS
    
    ; Wait for keyboard controller to be ready for commands
.wait_ready:
    call kbc_wait_ready
    jc .kbc_timeout     ; If timeout, try other methods
    
    ; Send command: Write to output port
    mov al, KBC_WRITE_CMD
    out KBC_CMD_PORT, al
    
    ; Wait again to ensure controller processed command
    call kbc_wait_ready
    jc .kbc_timeout
    
    ; Send data: Enable A20 line
    mov al, KBC_OUTPUT_PORT
    out KBC_DATA_PORT, al
    
    ; Wait for command to complete
    call kbc_wait_ready
    jc .kbc_timeout
    
    sti                 ; Re-enable interrupts
    pop cx
    pop ax
    popf
    ret
    
.kbc_timeout:
    dec cx
    jz .kbc_failed      ; If we've tried multiple times, give up
    jmp .wait_ready     ; Otherwise try again
    
.kbc_failed:
    sti                 ; Make sure interrupts are re-enabled
    pop cx
    pop ax
    popf
    stc                 ; Set carry flag to indicate failure
    ret

;-----------------------------------------------------------------------------
; Function: enable_a20_fast
; Purpose: Enable A20 line using System Control Port A (Fast A20)
;-----------------------------------------------------------------------------
enable_a20_fast:
    pushf
    push ax
    cli                 ; Disable interrupts
    
    ; Read current value
    in al, FAST_A20_PORT
    
    ; Set A20 enable bit (bit 1) and preserve other bits
    or al, FAST_A20_ENABLE
    
    ; Write the new value back
    out FAST_A20_PORT, al
    
    sti                 ; Re-enable interrupts
    pop ax
    popf
    ret

;-----------------------------------------------------------------------------
; Function: kbc_wait_ready
; Purpose: Wait for keyboard controller to be ready with timeout
; Returns: Carry flag set if timeout occurred
;-----------------------------------------------------------------------------
kbc_wait_ready:
    push ax
    push cx
    
    ; Set timeout counter
    mov cx, 0xFFFF
    
.wait_input_ready:
    ; Get keyboard controller status
    in al, KBC_STATUS_PORT
    
    ; Check if bit 1 (input buffer status) is clear
    test al, 2
    jz .wait_output     ; If input buffer empty, check output buffer
    
    ; Still busy, decrement counter and try again
    loop .wait_input_ready
    
    ; Timeout occurred
    stc                 ; Set carry flag
    jmp .done
    
.wait_output:
    ; Check output buffer status if needed (for reading operations)
    test al, KBC_STATUS_OUTPUT_FULL
    jz .success         ; If output buffer empty, we're good
    
    ; Clear output buffer by reading from it
    in al, KBC_DATA_PORT
    
.success:
    clc                 ; Clear carry flag - operation successful
    
.done:
    pop cx
    pop ax
    ret

; -----------------------------------------------------------------------------
; Function: enter_protected_mode
; Purpose: Switch CPU to 32-bit protected mode
;-----------------------------------------------------------------------------
enter_protected_mode:
    cli                     ; Disable interrupts
    
    ; Load GDT register
    lgdt [gdt_descriptor]
    
    ; Load empty IDT to prevent spurious interrupts in protected mode
    lidt [idt_descriptor]
    
    ; Set Protection Enable (PE) bit in CR0
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    
    ; Far jump to 32-bit code segment to load CS register
    ; This must be a far jump to flush the instruction pipeline
    jmp CODE_SEG:protected_mode_entry

; =============================================================================
; 32-bit Protected Mode Code
; =============================================================================
bits 32                     ; Subsequent code is 32-bit

protected_mode_entry:
    ; Set up segment registers
    mov ax, DATA_SEG
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    
    ; Set up a stack for protected mode
    mov esp, 0x90000
    
    ; Display success message in protected mode
    call pm_clear_screen
    mov esi, pm_msg_welcome
    call pm_print_string
    
    ; Setup is complete, sit in an infinite loop
    jmp pm_halt

; -----------------------------------------------------------------------------
; Function: pm_clear_screen
; Purpose: Clear the screen in protected mode using direct video memory access
;-----------------------------------------------------------------------------
pm_clear_screen:
    push eax
    push ecx
    push edi
    
    ; Video memory starts at 0xB8000
    mov edi, 0xB8000
    
    ; Clear the entire screen (80*25 = 2000 characters)
    ; Each character takes 2 bytes (char + attribute)
    mov ecx, 2000
    
    ; Black background, light gray foreground (0x07)
    ; Space character (0x20)
    mov ax, 0x0720
    
    ; Clear screen by filling with spaces
    rep stosw
    
    ; Reset cursor position
    mov edi, 0xB8000
    
    pop edi
    pop ecx
    pop eax
    ret

; -----------------------------------------------------------------------------
; Function: pm_print_string
; Purpose: Print a null-terminated string in protected mode
; Input: ESI - Pointer to string
;-----------------------------------------------------------------------------
pm_print_string:
    push eax
    push edi
    
    ; Video memory starts at 0xB8000
    mov edi, 0xB8000
    
    ; White text on blue background
    mov ah, 0x1F

.loop:
    ; Load character
    lodsb
    
    ; Check for end of string
    test al, al
    jz .done
    
    ; Store character and attribute
    stosw
    
    jmp .loop
    
.done:
    pop edi
    pop eax
    ret

; -----------------------------------------------------------------------------
; Function: pm_halt
; Purpose: Halt processor in protected mode
;-----------------------------------------------------------------------------
pm_halt:
    ; Infinite loop
    jmp pm_halt

; =============================================================================
; Global Descriptor Table (GDT)
; =============================================================================
align 8
gdt_start:
    ; Null Descriptor (required)
    dq 0

    ; Code Segment Descriptor
    dw 0xFFFF       ; Limit (bits 0-15)
    dw 0            ; Base (bits 0-15)
    db 0            ; Base (bits 16-23)
    db 10011010b    ; Access Byte (Present, Ring 0, Code, Executable, Direction 0, Readable)
    db 11001111b    ; Flags + Limit (bits 16-19) (Granularity, 32-bit, Limit bits 16-19)
    db 0            ; Base (bits 24-31)

    ; Data Segment Descriptor
    dw 0xFFFF       ; Limit (bits 0-15)
    dw 0            ; Base (bits 0-15)
    db 0            ; Base (bits 16-23)
    db 10010010b    ; Access Byte (Present, Ring 0, Data, Direction 0, Writable)
    db 11001111b    ; Flags + Limit (bits 16-19) (Granularity, 32-bit, Limit bits 16-19)
    db 0            ; Base (bits 24-31)
gdt_end:

; GDT Descriptor
gdt_descriptor:
    dw gdt_end - gdt_start - 1    ; Size of GDT minus 1
    dd gdt_start                  ; Start address of GDT

; Empty IDT descriptor (for protected mode)
idt_descriptor:
    dw 0                          ; Limit: 0 size
    dd 0                          ; Base: 0 address

; Protected mode messages
bits 32
pm_msg_welcome: db 'Pyramid Bootloader - Protected Mode', 0

; Return to 16-bit code assembly
bits 16

; =============================================================================
; Function: parse_bpb
; Purpose: Parse FAT BIOS Parameter Block (BPB)
; Reads BPB from boot sector loaded at 0x7C00
; Stores values into Stage 2 variables
; =============================================================================
parse_bpb:
    push ds
    push ax
    push si

    ; BPB is located relative to 0x7C00. Set DS = 0 to access it.
    xor ax, ax
    mov ds, ax
    mov si, 0x7C00

    ; Optional: Verify boot signature at 0x7CFE (offset 510) first
    cmp word [si + 510], 0xAA55
    jne .bpb_fail ; Jump if signature doesn't match

    ; Read BPB fields
    mov ax, [si + 0x0B] ; Bytes Per Sector
    mov [bpb_bytes_per_sector], ax

    mov al, [si + 0x0D] ; Sectors Per Cluster
    mov [bpb_sectors_per_cluster], al

    mov ax, [si + 0x0E] ; Reserved Sectors
    mov [bpb_reserved_sectors], ax

    mov al, [si + 0x10] ; Number of FATs
    mov [bpb_num_fats], al

    mov ax, [si + 0x11] ; Max Root Directory Entries
    mov [bpb_root_entries], ax

    mov ax, [si + 0x13] ; Total Sectors (16-bit)
    mov [bpb_total_sectors16], ax

    mov ax, [si + 0x16] ; Sectors Per FAT (FAT12/16)
    mov [bpb_sectors_per_fat16], ax

    ; Mark as parsed successfully
    mov byte [fs_info_parsed], 1
    jmp .bpb_done

.bpb_fail:
    mov byte [fs_info_parsed], 0

.bpb_done:
    pop si
    pop ax
    ; Restore original DS (Stage 2 segment)
    mov ax, STAGE2_SEGMENT
    mov ds, ax
    pop ds ; Restore original caller's DS
    ret

; =============================================================================
; Function: print_hex_word
; Purpose: Print a 16-bit value in Hexadecimal
; Input: AX = value to print
;        BL = color attribute
; Destroys: AX, BX, CX, DX, SI
; =============================================================================
print_hex_word:
    push ax ; Save original value
    push bx
    push cx
    push dx

    mov cx, 4 ; Number of hex digits to print

.print_digit_loop:
    rol ax, 4 ; Rotate highest nibble into lowest position
    mov dx, ax ; Copy AX to DX
    and dl, 0x0F ; Mask to get the lowest nibble

    ; Convert nibble to ASCII hex character
    cmp dl, 9
    jle .digit
    add dl, 'A' - 10 ; Convert 10-15 to 'A'-'F'
    jmp .print_char
.digit:
    add dl, '0' ; Convert 0-9 to '0'-'9'

.print_char:
    ; Print the character using BIOS teletype
    push ax ; Save AX across int call
    mov ah, 0x0E
    mov al, dl
    ; BH = 0 (page number), BL = color attribute (passed in)
    int 0x10
    pop ax

    loop .print_digit_loop

    pop dx
    pop cx
    pop bx
    pop ax
    ret

; =============================================================================
; Function: print_newline
; Purpose: Print a newline character sequence (CR LF)
; Input: BL = color attribute
; =============================================================================
print_newline:
    push ax
    push bx

    mov ah, 0x0E
    ; BH=0, BL=color (passed in)
    mov al, 0x0D ; Carriage Return
    int 0x10
    mov al, 0x0A ; Line Feed
    int 0x10

    pop bx
    pop ax
    ret

; =============================================================================
; Stage 2 Signature (for verification)
; =============================================================================
times 4096-($-$$) db 0   ; Pad stage 2 to have enough space (8 sectors × 512 bytes)
stage2_end: