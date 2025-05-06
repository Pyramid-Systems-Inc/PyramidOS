; =============================================================================
; Pyramid Bootloader - Stage 2 Entry (Minimal)
; =============================================================================
; Sets up environment for C code and calls stage2_main.
; Assumes loaded at STAGE2_LOAD_SEGMENT:STAGE2_LOAD_OFFSET by Stage 1.
; =============================================================================
bits 16

; Define segments (adjust names/attributes if needed for specific linker/compiler)
segment code public align=16 class=CODE use16
segment data public align=16 class=DATA use16 ; Assuming BSS/DATA combined for simplicity

; Declare external C function (adjust name decoration based on compiler, e.g., _stage2_main)
extern stage2_main

segment code
; Entry point called by Stage 1
global stage2_entry_point ; Use a distinct name
stage2_entry_point:
    ; Set up segments for C (e.g., Small/Compact model: DS=ES=SS)
    mov ax, data        ; Get segment address of our data segment
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

; --- Data Segment ---
segment data
; Reserve space for stack/BSS if needed, or manage via linker script.
; Example: Reserve 1KB for stack
stack_bottom:
    resb 1024
stack_top:

; Other data can go here
