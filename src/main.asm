; =============================================================================
; Bootloader with Color Support
; =============================================================================
; This bootloader demonstrates text output with color support in 16-bit real mode
; using BIOS video services (INT 10h). It displays text in different colors.
;
; Color format: bl register holds color attribute
; - Bits 0-3: Foreground color (text color)
; - Bits 4-7: Background color
; Example: 0x1E = Blue background (1) + Yellow text (E)
; =============================================================================

org 0x7C00            ; BIOS loads bootloader at this memory address
bits 16               ; Specify 16-bit code (Real Mode)

; =============================================================================
; Color Constants
; =============================================================================
%define BLACK       0x0    ; Available for both foreground and background
%define BLUE        0x1
%define GREEN       0x2
%define CYAN        0x3
%define RED         0x4
%define MAGENTA     0x5
%define BROWN       0x6
%define LGRAY       0x7    ; Light Gray
%define DGRAY       0x8    ; Dark Gray
%define LBLUE       0x9    ; Light Blue
%define LGREEN      0xA    ; Light Green
%define LCYAN       0xB    ; Light Cyan
%define LRED        0xC    ; Light Red
%define LMAGENTA    0xD    ; Light Magenta
%define YELLOW      0xE
%define WHITE       0xF

; =============================================================================
; Program Entry Point
; =============================================================================
start:
    jmp main             ; Skip over functions to main entry point

; =============================================================================
; Function Definitions
; =============================================================================

; Function: check_bios_error
; Purpose: Check if BIOS call resulted in error (CF set)
; Input: None (checks carry flag)
; Output: Jumps to error handler if CF is set
check_bios_error:
    jc .error
    ret
.error:
    mov si, msg_bios_error
    call puts_color
    jmp $               ; Hang system on error

; Function: puts_color
; Purpose: Print a string with specified color using BIOS services
; Input: ds:si - Pointer to string
;        bl - Color attribute
; Modifies: ax, bx, cx, dx (preserved via stack)
puts_color:
    push si             ; Preserve registers
    push ax
    push bx
    push cx
    push dx

.loop:
    lodsb               ; Load next character in al
    or al, al           ; Check for null terminator
    jz .done

    mov ah, 0x09        ; BIOS write character with attribute
    mov cx, 1           ; Print character once
    mov bh, 0           ; Page number
    int 0x10            ; Call BIOS video service
    call check_bios_error

    ; Move cursor forward
    mov ah, 0x03        ; Get cursor position
    mov bh, 0           ; Page number
    int 0x10
    call check_bios_error

    inc dl              ; Move cursor right
    mov ah, 0x02        ; Set cursor position
    int 0x10
    call check_bios_error

    jmp .loop

.done:
    ; Move to next line after string
    mov ah, 0x03        ; Get cursor position
    mov bh, 0           ; Page number
    int 0x10
    call check_bios_error

    mov dl, 0           ; Back to start of line
    inc dh              ; Next line
    mov ah, 0x02        ; Set cursor position
    int 0x10
    call check_bios_error

    pop dx              ; Restore registers
    pop cx
    pop bx
    pop ax
    pop si
    ret

; Function: get_key
; Purpose: Wait for and read a key from keyboard
; Input: None
; Output: al - ASCII character (0 if special key)
;         ah - BIOS scan code
; Modifies: ax
get_key:
    mov ah, 0x00        ; BIOS keyboard read function
    int 0x16            ; Call BIOS keyboard service
    ret

; Function: read_sector
; Purpose: Read a sector from disk using BIOS services
; Input: ax - LBA sector number
;        cl - Number of sectors to read (1-127)
;        es:bx - Buffer address
; Output: CF set on error
; Modifies: ax, bx, cx, dx
read_sector:
    push dx
    push si
    push di
    
    ; Convert LBA to CHS
    mov dx, 0
    mov si, ax          ; Save LBA in si
    
    ; Calculate cylinder/head/sector
    mov ax, si
    mov di, 18          ; Sectors per track
    div di              ; ax = LBA / 18, dx = LBA % 18
    mov ch, al          ; Cylinder
    mov dh, ah          ; Head
    inc dx              ; Sector (1-based)
    mov cl, dl          ; Sector number
    
    ; Set up disk read
    mov ah, 0x02        ; BIOS read sector function
    mov al, cl          ; Number of sectors to read
    mov dl, 0x80        ; Drive number (0x80 = first hard disk)
    
    ; Call BIOS disk service
    int 0x13
    
    pop di
    pop si
    pop dx
    ret

; =============================================================================
; Main Program
; =============================================================================
main:
    ; Initialize segment registers
    mov ax, 0           ; Can't write to segment registers directly
    mov ds, ax          ; Set data segment to 0
    mov es, ax          ; Set extra segment to 0

    ; Initialize stack
    mov ss, ax          ; Set stack segment to 0
    mov sp, 0x7000      ; Set stack pointer (safely below bootloader)

    ; Clear screen and set video mode
    mov ah, 0x00        ; Set video mode function
    mov al, 0x03        ; Mode 3 = 80x25 text mode, 16 colors
    int 0x10
    call check_bios_error

    ; Print hello message in light green
    mov bl, 0x0A        ; Light green on black background
    mov si, msg_hello
    call puts_color

    ; Print colored message (yellow on blue)
    mov bl, 0x1E        ; Yellow text (E) on blue background (1)
    mov si, msg_colored
    call puts_color

    ; Print normal message in default color
    mov bl, 0x07        ; Light gray on black (standard color)
    mov si, msg_normal
    call puts_color

    ; Demonstrate keyboard input
    mov bl, 0x0E        ; Yellow text
    mov si, msg_prompt
    call puts_color

    ; Wait for key press
    call get_key
    
    ; Print pressed key info
    mov bl, 0x07        ; Light gray
    mov si, msg_key
    call puts_color
    
    ; Print scan code
    mov bl, 0x0A        ; Light green
    mov si, msg_scan
    call puts_color
    
    ; Demonstrate disk read
    mov bl, 0x0B        ; Light cyan
    mov si, msg_disk
    call puts_color
    
    ; Read sector 0 (boot sector) into memory at 0x8000
    mov ax, 0x8000
    mov es, ax
    xor bx, bx
    mov ax, 0           ; LBA sector 0
    mov cl, 1           ; Read 1 sector
    call read_sector
    jnc .success
    
    ; Disk read failed
    mov bl, 0x0C        ; Light red
    mov si, msg_disk_error
    call puts_color
    jmp .halt
    
.success:
    mov bl, 0x0A        ; Light green
    mov si, msg_disk_ok
    call puts_color

.halt:
    jmp .halt           ; Infinite loop

; =============================================================================
; Data Section
; =============================================================================
msg_hello:      db 'Hello World in green!', 0
msg_colored:    db 'Yellow on blue background!', 0
msg_normal:     db 'Back to normal white text.', 0
msg_bios_error: db 'BIOS Error Occurred!', 0

; =============================================================================
; Boot Sector Padding and Signature
; =============================================================================
times 510-($-$$) db 0   ; Pad with zeros until 510 bytes
dw 0AA55H               ; Boot signature (0xAA55)