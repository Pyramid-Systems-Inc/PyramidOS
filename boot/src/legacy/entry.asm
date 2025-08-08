; =============================================================================
; Pyramid Bootloader - Stage 2 Entry (Minimal)
; =============================================================================
; Sets up environment for C code and calls stage2_main.
; Assumes loaded at STAGE2_LOAD_SEGMENT:STAGE2_LOAD_OFFSET by Stage 1.
; =============================================================================
bits 16

; Use standard NASM sections for ELF output
section .text
    bits 16
    global stage2_entry_point ; Use a distinct name
    global bios_print_char_asm ; Make the print function visible to linker

; Declare external C function (adjust name decoration based on compiler, e.g., _stage2_main)
extern stage2_main

; Entry point called by Stage 1
stage2_entry_point:
    ; Set up segments for C (e.g., Small/Compact model: DS=ES=SS)
    mov ax, data_seg    ; Get segment address of our data segment (using label)
    mov ds, ax
    mov es, ax
    mov ss, ax          ; Stack segment = data segment

    ; Set up stack pointer (e.g., at the top of the data segment or a dedicated stack area)
    ; Make sure this doesn't collide with code/data loaded by Stage 1.
    ; Assuming Stage 2 code/data fits below 0xFFFF in the segment.
    mov sp, 0xFFFE      ; Point to top of segment (adjust as needed)

    ; Retrieve boot drive saved by Stage 1 (optional, if needed by C)
    ; Stage 1 saved it at [0x7C00 + offset_of_boot_drive]. We need Stage 1's layout.
    ; Simpler: Assume Stage 1 passed it in DL and it's still there.
    ; Or, Stage 1 could push it before jumping.
    ; For now, assume C code doesn't need it immediately or gets it another way.

    ; Call the main C function
    call stage2_main

    ; If stage2_main returns, hang the system
.hang:
    cli
    hlt
    jmp .hang

; --- BIOS Print Character Function ---
; Called from C: void bios_print_char_asm(char c)
; Expects character argument on the stack [bp+4] for 16-bit C calling convention
bios_print_char_asm:
    push bp         ; Save base pointer
    mov bp, sp      ; Set up stack frame

    mov ah, 0x0E    ; BIOS Teletype output function
    mov al, [bp+4]  ; Get character argument from stack
    mov bh, 0       ; Page number 0
    mov bl, 0x07    ; Light grey text on black background (optional)
    int 0x10        ; Call BIOS video service

    pop bp          ; Restore base pointer
    ret             ; Return to C caller

; --- Data Segment ---
section .data align=16
data_seg: ; Label to get the segment address

; Other initialized data can go here

; --- BSS Segment (Uninitialized Data) ---
section .bss align=16
stack_bottom:
    resb 1024 ; Reserve 1KB for stack
stack_top:
