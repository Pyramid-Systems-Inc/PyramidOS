; ==============================================================================
; PyramidOS Interrupt Service Routines (Assembly Stubs)
; ==============================================================================
bits 32

section .text
    global idt_load
    extern isr_handler

; Load the IDT pointer (LIDT instruction)
; void idt_load(uint32_t idt_ptr);
idt_load:
    mov eax, [esp + 4]  ; Get pointer argument
    lidt [eax]          ; Load IDT
    ret

; ------------------------------------------------------------------------------
; Macros
; ------------------------------------------------------------------------------

; Macro for exceptions with NO error code (Push dummy 0)
%macro ISR_NOERRCODE 1
    global isr%1
    isr%1:
        cli
        push 0          ; Push dummy error code
        push %1         ; Push interrupt number
        jmp isr_common_stub
%endmacro

; Macro for exceptions WITH error code (CPU pushes error code automatically)
%macro ISR_ERRCODE 1
    global isr%1
    isr%1:
        cli
        ; Error code already on stack
        push %1         ; Push interrupt number
        jmp isr_common_stub
%endmacro

; Macro for IRQs (Hardware Interrupts)
; IRQs behave like No-Error-Code exceptions.
; We map IRQ 0 -> Interrupt 32, etc.
%macro IRQ 2
    global irq%1
    irq%1:
        cli
        push 0          ; Push dummy error code
        push %2         ; Push Interrupt Number (32-47)
        jmp isr_common_stub
%endmacro

; ------------------------------------------------------------------------------
; CPU Exceptions (0-31)
; ------------------------------------------------------------------------------
ISR_NOERRCODE 0   ; Divide by Zero
ISR_NOERRCODE 1   ; Debug
ISR_NOERRCODE 2   ; NMI
ISR_NOERRCODE 3   ; Breakpoint
ISR_NOERRCODE 4   ; Overflow
ISR_NOERRCODE 5   ; Bound Range
ISR_NOERRCODE 6   ; Invalid Opcode
ISR_NOERRCODE 7   ; Device Not Available
ISR_ERRCODE   8   ; Double Fault
ISR_NOERRCODE 9   ; Coprocessor Segment Overrun
ISR_ERRCODE   10  ; Invalid TSS
ISR_ERRCODE   11  ; Segment Not Present
ISR_ERRCODE   12  ; Stack-Segment Fault
ISR_ERRCODE   13  ; General Protection Fault (#GP)
ISR_ERRCODE   14  ; Page Fault (#PF)
ISR_NOERRCODE 15  ; Reserved
ISR_NOERRCODE 16  ; x87 FPU Error
ISR_ERRCODE   17  ; Alignment Check
ISR_NOERRCODE 18  ; Machine Check
ISR_NOERRCODE 19  ; SIMD Exception
ISR_NOERRCODE 20  ; Virtualization Exception
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

; ------------------------------------------------------------------------------
; Hardware Interrupts (IRQs) (32-47)
; ------------------------------------------------------------------------------
IRQ 0,  32 ; Timer
IRQ 1,  33 ; Keyboard
IRQ 2,  34 ; Cascade (used internally by 8259)
IRQ 3,  35 ; COM2
IRQ 4,  36 ; COM1
IRQ 5,  37 ; LPT2
IRQ 6,  38 ; Floppy
IRQ 7,  39 ; LPT1
IRQ 8,  40 ; CMOS/RTC
IRQ 9,  41 ; Peripherals / Legacy SCSI / NIC
IRQ 10, 42 ; Peripherals / SCSI / NIC
IRQ 11, 43 ; Peripherals / SCSI / NIC
IRQ 12, 44 ; PS/2 Mouse
IRQ 13, 45 ; FPU / Coprocessor
IRQ 14, 46 ; Primary ATA
IRQ 15, 47 ; Secondary ATA

; ------------------------------------------------------------------------------
; Common ISR Handler
; Saves state, calls C handler, restores state.
; ------------------------------------------------------------------------------
isr_common_stub:
    pusha               ; Pushes edi, esi, ebp, esp, ebx, edx, ecx, eax

    mov ax, ds          ; Save Data Segment
    push eax

    mov ax, 0x10        ; Load Kernel Data Segment (0x10 is the Offset in GDT)
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    call isr_handler    ; Call C function

    pop eax             ; Restore Data Segment
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    popa                ; Pop general registers
    add esp, 8          ; Clean up error code and ISR number
    sti                 ; Re-enable interrupts
    iret                ; Interrupt Return

; ------------------------------------------------------------------------------
; Mark stack as non-executable (silences linker warning)
; ------------------------------------------------------------------------------
section .note.GNU-stack noalloc noexec nowrite progbits