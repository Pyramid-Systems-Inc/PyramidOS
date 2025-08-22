; kernel/idt_asm.asm
bits 32
section .text

; External C functions
extern exception_handler
extern irq_timer_handler
extern irq_keyboard_handler
extern pic_send_eoi

; Function to load IDT
global idt_load
idt_load:
    mov eax, [esp + 4]  ; Get IDT pointer address
    lidt [eax]          ; Load IDT
    ret

; Macro for ISRs without error code
%macro ISR_NOERRCODE 1
global isr%1
isr%1:
    cli                 ; Disable interrupts
    push dword 0        ; Push dummy error code
    push dword %1       ; Push interrupt number
    jmp isr_common_stub
%endmacro

; Macro for ISRs with error code
%macro ISR_ERRCODE 1
global isr%1
isr%1:
    cli                 ; Disable interrupts
    push dword %1       ; Push interrupt number
    jmp isr_common_stub
%endmacro

; Macro for IRQs
%macro IRQ 2
global irq%1
irq%1:
    cli
    push dword 0        ; Dummy error code
    push dword %2       ; IRQ number + 32
    jmp irq_common_stub
%endmacro

; CPU Exception handlers (0-31)
ISR_NOERRCODE 0   ; Division by zero
ISR_NOERRCODE 1   ; Debug
ISR_NOERRCODE 2   ; NMI
ISR_NOERRCODE 3   ; Breakpoint
ISR_NOERRCODE 4   ; Overflow
ISR_NOERRCODE 5   ; Bound range exceeded
ISR_NOERRCODE 6   ; Invalid opcode
ISR_NOERRCODE 7   ; Device not available
ISR_ERRCODE   8   ; Double fault
ISR_NOERRCODE 9   ; Coprocessor segment overrun
ISR_ERRCODE   10  ; Invalid TSS
ISR_ERRCODE   11  ; Segment not present
ISR_ERRCODE   12  ; Stack-segment fault
ISR_ERRCODE   13  ; General protection fault
ISR_ERRCODE   14  ; Page fault
ISR_NOERRCODE 15  ; Reserved
ISR_NOERRCODE 16  ; x87 floating-point exception
ISR_ERRCODE   17  ; Alignment check
ISR_NOERRCODE 18  ; Machine check
ISR_NOERRCODE 19  ; SIMD floating-point exception
ISR_NOERRCODE 20  ; Virtualization exception
ISR_NOERRCODE 21  ; Reserved
ISR_NOERRCODE 22  ; Reserved
ISR_NOERRCODE 23  ; Reserved
ISR_NOERRCODE 24  ; Reserved
ISR_NOERRCODE 25  ; Reserved
ISR_NOERRCODE 26  ; Reserved
ISR_NOERRCODE 27  ; Reserved
ISR_NOERRCODE 28  ; Reserved
ISR_NOERRCODE 29  ; Reserved
ISR_NOERRCODE 30  ; Reserved
ISR_NOERRCODE 31  ; Reserved

; IRQ handlers (32-47)
IRQ 0, 32    ; Timer
IRQ 1, 33    ; Keyboard
IRQ 2, 34    ; Cascade
IRQ 3, 35    ; COM2
IRQ 4, 36    ; COM1
IRQ 5, 37    ; LPT2
IRQ 6, 38    ; Floppy
IRQ 7, 39    ; LPT1
IRQ 8, 40    ; CMOS clock
IRQ 9, 41    ; Free
IRQ 10, 42   ; Free
IRQ 11, 43   ; Free
IRQ 12, 44   ; PS/2 mouse
IRQ 13, 45   ; FPU
IRQ 14, 46   ; Primary ATA
IRQ 15, 47   ; Secondary ATA

; Common ISR stub for exceptions
isr_common_stub:
    pusha               ; Push all general purpose registers
    
    mov ax, ds          ; Save data segment
    push eax
    
    mov ax, 0x10        ; Load kernel data segment
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    
    call exception_handler
    
    pop eax             ; Restore original data segment
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    
    popa                ; Restore all general purpose registers
    add esp, 8          ; Clean up error code and interrupt number
    sti                 ; Re-enable interrupts
    iret                ; Return from interrupt

; Common IRQ stub
irq_common_stub:
    pusha               ; Push all general purpose registers
    
    mov ax, ds          ; Save data segment
    push eax
    
    mov ax, 0x10        ; Load kernel data segment
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    
    ; Check which IRQ and call appropriate handler
    mov eax, [esp + 36] ; Get interrupt number (after pusha + push eax + error code + int num)
    cmp eax, 32
    je .timer
    cmp eax, 33
    je .keyboard
    jmp .end
    
.timer:
    call irq_timer_handler
    jmp .end
    
.keyboard:
    call irq_keyboard_handler
    jmp .end
    
.end:
    ; Send EOI using PIC driver
    mov eax, [esp + 36] ; Get interrupt number
    sub eax, 32         ; Convert to IRQ number (IRQ = interrupt - 32)
    push eax
    call pic_send_eoi
    add esp, 4          ; Clean up stack
    
.restore:
    pop eax             ; Restore original data segment
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    
    popa                ; Restore all general purpose registers
    add esp, 8          ; Clean up error code and interrupt number
    sti                 ; Re-enable interrupts
    iret                ; Return from interrupt