; kernel/entry.asm
bits 32

section .text
    ; We need to declare k_main as an external function
    extern k_main

    ; The bootloader will jump to this _start label
    global _start
_start:
    ; Set up the stack pointer. We define the stack in the .bss section.
    mov esp, kernel_stack_top

    ; Call the C kernel's main function
    call k_main

    ; If k_main returns, hang the system
    cli
.hang:
    hlt
    jmp .hang

section .bss
; This section reserves space for our kernel's stack.
; We'll reserve 16KB for it.
kernel_stack_bottom:
    resb 16384 ; 16 KB
kernel_stack_top: