; kernel/entry.asm
bits 32

section .text
    global _start
    extern k_main
    
_start:
    ; Immediately write "OK" to VGA to show kernel is running
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
align 16
kernel_stack_bottom:
    resb 16384 ; 16 KB
kernel_stack_top: