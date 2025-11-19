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
; Exception Macros
; Some exceptions push an error code, some don't. We normalize this.
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
; ... 21-31 Reserved
ISR_NOERRCODE 32  ; Reserved (Will use for Timer later)

; ------------------------------------------------------------------------------
; Common ISR Handler
; Saves state, calls C handler, restores state.
; ------------------------------------------------------------------------------
isr_common_stub:
    pusha               ; Pushes edi, esi, ebp, esp, ebx, edx, ecx, eax

    mov ax, ds          ; Save Data Segment
    push eax

    mov ax, 0x10        ; Load Kernel Data Segment
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