; kernel/entry.asm
bits 32

section .text
    global _start
    extern k_main
    
_start:
    ; Debug: Write "ENTRY" to VGA to show we reached kernel
    mov dword [0xB8000], 0x2F4E2F45  ; "EN" in white on green
    mov dword [0xB8004], 0x2F52     ; "TR"
    mov dword [0xB8008], 0x2F59     ; "Y"
    
    ; Set up the stack pointer
    mov esp, kernel_stack_top
    
    ; Debug: Write "STACK" to show stack is set up
    mov dword [0xB800A], 0x2F542F53  ; "ST" 
    mov dword [0xB800E], 0x2F432F41  ; "AC"
    mov dword [0xB8012], 0x2F4B     ; "K"
    
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