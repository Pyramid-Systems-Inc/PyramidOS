; =============================================================================
; Stage 2 Assembly Entry Point and Helpers for Watcom C (NASM Syntax for OMF)
; =============================================================================
bits 16

; Watcom C Compact Model: CS != DS = ES = SS
; We assume Stage 1 loaded us at STAGE2_SEGMENT:STAGE2_OFFSET (0x0800:0x0000)
; Linker needs to place code and data correctly.

; Define segments (use standard names if possible, or Watcom convention)
; NASM OMF output might require specific segment naming/attributes for wlink.
; Let's try standard names first. WLINK might map them based on class (CODE/DATA).
segment code public align=16 class=CODE use16 ; Or _TEXT
segment data public align=16 class=DATA use16 ; Or _DATA

; Declare external C function (Watcom -zc means no underscore)
extern stage2_main

; --- Code Segment ---
segment code
; Public entry point for Stage 1 to jump to
global _stage2_entry ; Keep underscore for assembly entry? Or match C? Let's try matching C.
stage2_entry:
    ; Set up segments for Compact Model
    mov ax, data        ; Get the segment address of data segment
    mov ds, ax
    mov es, ax
    mov ss, ax          ; Stack segment is same as data segment

    ; Set up stack pointer below our code/data
    mov sp, 0xFFFF      ; Top of segment (adjust if needed)

    ; DL should still contain the boot drive number passed by BIOS and preserved by Stage 1.
    ; Push boot drive argument for _stage2_main (Watcom C pushes args right-to-left)
    xor dh, dh          ; Zero extend dl into dx (boot drive)
    push dx             ; Push boot_drive (as a word)

    ; Call the main C function (near call within the same code segment)
    call stage2_main

    ; If stage2_main returns (it shouldn't in this case), hang
.hang:
    cli
    hlt
    jmp .hang

; =============================================================================
; Assembly Helper Functions Callable from C
; =============================================================================
; Watcom C calling convention for 16-bit DOS/Compact model:
; - Arguments pushed right-to-left.
; - Caller cleans up stack.
; - Return value in AX (for 16-bit) or DX:AX (for 32-bit).
; - Registers AX, BX, CX, DX are caller-saved (can be modified by callee).
; - Registers SI, DI, BP, DS, ES are callee-saved (must be preserved).
; - Function names match C names directly (-zc).

; void bios_print_char(char c, unsigned char color, unsigned short page);
global bios_print_char
bios_print_char:
    push bp
    mov bp, sp
    pusha               ; Save all general registers (simpler than picking)

    mov ah, 0x0E        ; BIOS teletype function
    mov al, [bp+4]      ; Get char c (first arg)
    mov bl, [bp+6]      ; Get color (second arg)
    mov bh, [bp+8]      ; Get page (third arg, low byte)

    int 0x10

    popa                ; Restore all general registers
    mov sp, bp          ; Clean up local stack frame (redundant with pop bp)
    pop bp
    retf 6              ; Return far and pop 3 word args (2+2+2 = 6 bytes)

; void bios_set_cursor(unsigned char row, unsigned char col, unsigned short page);
global bios_set_cursor
bios_set_cursor:
    push bp
    mov bp, sp
    pusha

    mov ah, 0x02        ; BIOS set cursor position function
    mov dh, [bp+4]      ; Get row
    mov dl, [bp+6]      ; Get col
    mov bh, [bp+8]      ; Get page (low byte)

    int 0x10

    popa
    mov sp, bp
    pop bp
    retf 6              ; Return far and pop args (2+2+2 = 6 bytes)

; unsigned short bios_read_key(void); Returns AH=scan code, AL=ASCII
global bios_read_key
bios_read_key:
    push bp
    mov bp, sp
    push bx             ; Preserve BX, CX, DX, SI, DI, ES if needed (AX is return value)
    push cx
    push dx

    mov ah, 0x00        ; BIOS wait for keystroke function
    int 0x16            ; Returns scan code in AH, ASCII in AL

    ; AX already contains the return value (AH=scan, AL=ASCII)

    pop dx
    pop cx
    pop bx
    mov sp, bp
    pop bp
    retf                ; Return far, no args to pop

; void bios_scroll_up(unsigned char lines, unsigned char attr, unsigned char r1, unsigned char c1, unsigned char r2, unsigned char c2);
global bios_scroll_up
bios_scroll_up:
    push bp
    mov bp, sp
    pusha

    mov ah, 0x06        ; BIOS scroll window up function
    mov al, [bp+4]      ; Get number of lines to scroll (0 = clear)
    mov bh, [bp+6]      ; Get attribute for blank lines
    mov ch, [bp+8]      ; Get top row (r1)
    mov cl, [bp+10]     ; Get left col (c1)
    mov dh, [bp+12]     ; Get bottom row (r2)
    mov dl, [bp+14]     ; Get right col (c2)

    int 0x10

    popa
    mov sp, bp
    pop bp
    retf 12             ; Return far and pop 6 word args


; unsigned short bios_get_memory_size(void); Returns KB extended memory or 0xFFFF on error
global bios_get_memory_size
bios_get_memory_size:
    push bp
    mov bp, sp
    push bx             ; Preserve registers
    push cx
    push dx

    mov ah, 0x88        ; BIOS get extended memory size
    int 0x15
    jc .error           ; Jump if carry flag set (error)

    ; AX contains KB of contiguous memory starting at 1MB
    ; Return AX directly
    jmp .done

.error:
    mov ax, 0xFFFF      ; Return error code

.done:
    pop dx
    pop cx
    pop bx
    mov sp, bp
    pop bp
    retf                ; Return far, no args

; void reboot_system(void);
global reboot_system
reboot_system:
    ; Try keyboard controller reset first
    mov al, 0xFE
    out 0x64, al        ; Command port 0x64, command 0xFE (pulse reset line)

    ; Short delay
    mov cx, 0xFFFF
.delay_loop:
    loop .delay_loop

    ; If that didn't work, try INT 19h
    int 0x19

    ; If still here, hang
.reboot_hang:
    cli
    hlt
    jmp .reboot_hang
    ; No retf needed as it shouldn't return

; A20 Line related constants
%define KBC_DATA_PORT   0x60
%define KBC_CMD_PORT    0x64
%define KBC_STATUS_PORT 0x64
%define KBC_WRITE_CMD   0xD1
%define KBC_OUTPUT_PORT 0xDF
%define FAST_A20_PORT   0x92
%define FAST_A20_ENABLE 0x02
%define KBC_STATUS_INPUT_FULL  0x02
%define KBC_MAX_ATTEMPTS        10

; int check_a20_asm(void); Returns 1 if enabled, 0 if disabled
global check_a20_asm
check_a20_asm:
    push bp
    mov bp, sp
    pushf               ; Preserve flags and registers used
    push ds
    push es
    push di
    push si
    push cx
    push bx

    ; Set ES:DI to 0000:0500 and DS:SI to FFFF:0510
    xor ax, ax
    mov es, ax
    mov di, 0x0500
    mov ax, 0xFFFF
    mov ds, ax
    mov si, 0x0510

    ; Save original values
    mov ax, es:[di]     ; Use segment override for clarity
    push ax
    mov ax, ds:[si]
    push ax

    ; Write different values
    mov byte es:[di], 0x00
    mov byte ds:[si], 0xFF

    ; Small delay
    mov cx, 0x100
.delay_a20:
    loop .delay_a20

    ; Check if values stayed different
    mov al, es:[di]
    cmp al, 0x00
    jne .different
    mov al, ds:[si]
    cmp al, 0xFF
    jne .different

    ; Values are the same -> A20 is OFF
    mov ax, 0
    jmp .restore

.different:
    ; Values are different -> A20 is ON
    mov ax, 1

.restore:
    ; Restore original values
    pop bx
    mov ds:[si], bx
    pop bx
    mov es:[di], bx

    pop bx
    pop cx
    pop si
    pop di
    pop es
    pop ds
    popf
    mov sp, bp
    pop bp
    retf                ; Return AX (0 or 1)

; int enable_a20_kbc_asm(void); Returns 0 on success, 1 on failure (carry flag logic inverted for C)
global enable_a20_kbc_asm
enable_a20_kbc_asm:
    push bp
    mov bp, sp
    pushf
    push cx
    push ax             ; Preserve AX as it's used internally

    cli                 ; Disable interrupts

    mov cx, KBC_MAX_ATTEMPTS
.wait_loop:
    call kbc_wait_ready_input ; Wait for input buffer empty
    jc .kbc_failed      ; Timeout or error

    mov al, KBC_WRITE_CMD ; Command to write to output port
    out KBC_CMD_PORT, al

    call kbc_wait_ready_input ; Wait again
    jc .kbc_failed

    mov al, KBC_OUTPUT_PORT ; Data to enable A20 (and maybe reset?)
    out KBC_DATA_PORT, al

    call kbc_wait_ready_input ; Wait for completion
    jc .kbc_failed

    ; Success
    mov ax, 0           ; Return 0 for success
    jmp .kbc_done

.kbc_failed:
    mov ax, 1           ; Return 1 for failure

.kbc_done:
    sti                 ; Re-enable interrupts
    pop ax
    pop cx
    popf
    mov sp, bp
    pop bp
    retf                ; Return AX (0 or 1)

; Helper: Wait for KBC input buffer to be empty
kbc_wait_ready_input:
    push dx             ; Use dx for timeout counter
    mov dx, 0xFFFF      ; Timeout counter
.wait:
    in al, KBC_STATUS_PORT
    test al, KBC_STATUS_INPUT_FULL ; Check input buffer full bit
    jnz .loop_wait      ; If set, loop
    clc                 ; Success, clear carry
    jmp .kbc_wait_done
.loop_wait:
    dec dx
    jnz .wait
    stc                 ; Timeout, set carry
.kbc_wait_done:
    pop dx
    ret

; void enable_a20_fast_asm(void);
global enable_a20_fast_asm
enable_a20_fast_asm:
    push bp
    mov bp, sp
    pushf
    push ax

    cli
    in al, FAST_A20_PORT
    or al, FAST_A20_ENABLE
    out FAST_A20_PORT, al
    sti

    pop ax
    popf
    mov sp, bp
    pop bp
    retf                ; No return value, no args

; int copy_bpb_to(void *buffer); Copies BPB from 0x7C00 to buffer. Returns 1 on success, 0 on fail.
; Watcom passes far pointers as Seg:Off on stack. Seg=[bp+6], Off=[bp+4]
global copy_bpb_to
copy_bpb_to:
    push bp
    mov bp, sp
    push ds
    push es
    push si
    push di
    push cx

    ; Get destination buffer address (passed as first arg)
    mov di, [bp+4]      ; Offset
    mov ax, [bp+6]      ; Segment
    mov es, ax          ; ES:DI = destination buffer

    ; Set source address
    xor ax, ax
    mov ds, ax          ; DS = 0
    mov si, 0x7C00      ; DS:SI = source (Stage 1 load address)

    ; Check boot signature first
    cmp word [si + 510], 0xAA55
    jne .fail

    ; Copy the relevant part of the BPB (e.g., first 62 bytes)
    mov cx, 62          ; Number of bytes to copy (adjust as needed for BPB struct)
    rep movsb           ; Copy CX bytes from DS:SI to ES:DI

    mov ax, 1           ; Return success
    jmp .copy_done

.fail:
    mov ax, 0           ; Return failure

.copy_done:
    pop cx
    pop di
    pop si
    pop es
    pop ds
    mov sp, bp
    pop bp
    retf 4              ; Pop far pointer argument (seg + off = 4 bytes)


; TODO: Implement protected mode helpers
; - _enter_pmode_asm (loads GDT/IDT, sets PE bit, far jumps to 32-bit code)
;   This will need the GDT definition moved here or included.

; --- Data Segment ---
segment data
; Add any data needed by assembly helpers here, if any.
