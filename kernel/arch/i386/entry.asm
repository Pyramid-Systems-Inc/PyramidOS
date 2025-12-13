; ==============================================================================
; PyramidOS Kernel Entry Point
; ==============================================================================
; Responsibility:
; 1. Setup Stack (16KB).
; 2. Visual Debug (Confirm bootloader handoff).
; 3. Jump to High-Level Kernel (k_main).
; ==============================================================================
bits 32

section .text
    global _start
    extern k_main

_start:
    ; 1. Safety First: Disable Interrupts
    cli
    
    ; 2. Visual Debug: Write "KK" (White on Blue) to VGA
    mov dword [0xB8000], 0x1F4B1F4B 
    
    ; 3. Setup Stack
    mov esp, kernel_stack_top
    
    ; 4. Environment cleanup
    ; Clear EFLAGS (Ensures Direction Flag is clear for C compiler)
    push 0
    popfd           
    
    ; 5. Enter C Kernel
    call k_main
    
    ; 6. Catch Hang
    cli
.hang:
    hlt
    jmp .hang

; ==============================================================================
; BSS Section
; ==============================================================================
section .bss
align 16
kernel_stack_bottom:
    resb 16384          ; Reserve 16KB for Kernel Stack
kernel_stack_top: