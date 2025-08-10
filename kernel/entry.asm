; kernel/entry.asm
bits 32

section .text
    global _start
    extern k_main
    
_start:
    ; CRITICAL: Disable interrupts immediately (no IDT set up yet)
    cli
    
    ; Debug: Write "KERN" to VGA to show we reached kernel
    mov dword [0xB8014], 0x2F452F4B  ; "KE" 
    mov dword [0xB8018], 0x2F4E2F52  ; "RN"
    
    ; Set up the stack pointer
    mov esp, kernel_stack_top
    
    ; Debug: Write "STK" to show stack is set up
    mov dword [0xB801C], 0x2F542F53  ; "ST"
    mov dword [0xB8020], 0x2F004B   ; "K "
    
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