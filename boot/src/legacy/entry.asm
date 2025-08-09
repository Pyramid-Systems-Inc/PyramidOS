; kernel/entry.asm
bits 32

section .text
    ; The bootloader will jump to this _start label
    global _start
    extern k_main
    
_start:
    ; Immediately write something to VGA to show we're here
    mov dword [0xB8000], 0x2F4B2F4F  ; "OK" in white on green
    
    ; Set up the stack pointer
    mov esp, kernel_stack_top
    
    ; Call the C kernel's main function
    call k_main
    
    ; If k_main returns, hang the system
    cli
.hang:
    hlt
    jmp .hang

section .bss
; Reserve space for kernel stack
align 16
kernel_stack_bottom:
    resb 16384 ; 16 KB
kernel_stack_top: