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
    ; 1. Safety First: Disable Interrupts (Should be off, but be sure)
    cli
    
    ; 2. Visual Debug: Write "K" (White on Blue) to VGA (0xB8000)
    ; 0x1F4B -> 0x1F (Blue Background, White Text), 0x4B ('K')
    mov dword [0xB8000], 0x1F4B1F4B ; Write 'KK' to confirm entry
    
    ; 3. Setup Stack
    ; The stack grows downwards. We set ESP to the TOP of the reserved block.
    mov esp, kernel_stack_top
    
    ; 4. Environment cleanup
    ; Clear EFLAGS (Direction flag must be clear for C compilers)
    push 0
    pop fd
    
    ; 5. Enter C Kernel
    call k_main
    
    ; 6. Catch Hang
    ; If k_main returns, we disable interrupts and halt forever.
    cli
.hang:
    hlt
    jmp .hang

; ==============================================================================
; BSS Section (Uninitialized Data)
; ==============================================================================
section .bss
align 16
kernel_stack_bottom:
    resb 16384          ; Reserve 16KB for Kernel Stack
kernel_stack_top: