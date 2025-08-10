#ifndef IDT_H
#define IDT_H

#include "stdint.h"

// IDT entry structure
struct idt_entry {
    uint16_t offset_low;    // Lower 16 bits of handler function address
    uint16_t selector;      // Kernel segment selector
    uint8_t  reserved;      // Always 0
    uint8_t  type_attr;     // Type and attributes
    uint16_t offset_high;   // Upper 16 bits of handler function address
} __attribute__((packed));

// IDT pointer structure
struct idt_ptr {
    uint16_t limit;         // Size of IDT - 1
    uint32_t base;          // Base address of IDT
} __attribute__((packed));

// IDT constants
#define IDT_ENTRIES 256
#define IDT_INTERRUPT_GATE 0x8E
#define IDT_TRAP_GATE 0x8F

// Interrupt numbers
#define IRQ_TIMER     32    // IRQ 0 -> Interrupt 32
#define IRQ_KEYBOARD  33    // IRQ 1 -> Interrupt 33

// Function declarations
void idt_init(void);
void idt_set_gate(uint8_t num, uint32_t handler, uint16_t selector, uint8_t flags);

// Exception handlers (implemented in exceptions.c)
void exception_handler(uint32_t interrupt_number, uint32_t error_code);

// IRQ handlers (implemented in respective files)
void irq_timer_handler(void);
void irq_keyboard_handler(void);

// Assembly interrupt stubs (implemented in idt_asm.asm)
extern void isr0(void);   // Division by zero
extern void isr1(void);   // Debug
extern void isr2(void);   // NMI
extern void isr3(void);   // Breakpoint
extern void isr4(void);   // Overflow
extern void isr5(void);   // Bound range exceeded
extern void isr6(void);   // Invalid opcode
extern void isr7(void);   // Device not available
extern void isr8(void);   // Double fault
extern void isr9(void);   // Coprocessor segment overrun
extern void isr10(void);  // Invalid TSS
extern void isr11(void);  // Segment not present
extern void isr12(void);  // Stack-segment fault
extern void isr13(void);  // General protection fault
extern void isr14(void);  // Page fault
extern void isr15(void);  // Reserved
extern void isr16(void);  // x87 floating-point exception
extern void isr17(void);  // Alignment check
extern void isr18(void);  // Machine check
extern void isr19(void);  // SIMD floating-point exception
extern void isr20(void);  // Virtualization exception
extern void isr21(void);  // Reserved
extern void isr22(void);  // Reserved
extern void isr23(void);  // Reserved
extern void isr24(void);  // Reserved
extern void isr25(void);  // Reserved
extern void isr26(void);  // Reserved
extern void isr27(void);  // Reserved
extern void isr28(void);  // Reserved
extern void isr29(void);  // Reserved
extern void isr30(void);  // Reserved
extern void isr31(void);  // Reserved

// IRQ handlers
extern void irq0(void);   // Timer
extern void irq1(void);   // Keyboard
extern void irq2(void);   // Cascade
extern void irq3(void);   // COM2
extern void irq4(void);   // COM1
extern void irq5(void);   // LPT2
extern void irq6(void);   // Floppy
extern void irq7(void);   // LPT1
extern void irq8(void);   // CMOS clock
extern void irq9(void);   // Free for peripherals
extern void irq10(void);  // Free for peripherals
extern void irq11(void);  // Free for peripherals
extern void irq12(void);  // PS/2 mouse
extern void irq13(void);  // FPU
extern void irq14(void);  // Primary ATA
extern void irq15(void);  // Secondary ATA

#endif /* IDT_H */