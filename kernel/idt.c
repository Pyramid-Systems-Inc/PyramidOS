#include "idt.h"
#include "vga.h"
#include "pic.h"

// IDT table and pointer
static struct idt_entry idt[IDT_ENTRIES];
static struct idt_ptr idt_pointer;

// External assembly function to load IDT
extern void idt_load(uint32_t idt_ptr_address);

void idt_init(void) {
    vga_writestring("[IDT] Initializing Interrupt Descriptor Table...\n");
    
    // Initialize PIC first
    pic_init();
    
    // Set up IDT pointer
    idt_pointer.limit = (sizeof(struct idt_entry) * IDT_ENTRIES) - 1;
    idt_pointer.base = (uint32_t)&idt;
    
    // Clear IDT
    for (int i = 0; i < IDT_ENTRIES; i++) {
        idt[i].offset_low = 0;
        idt[i].selector = 0;
        idt[i].reserved = 0;
        idt[i].type_attr = 0;
        idt[i].offset_high = 0;
    }
    
    // Install exception handlers (ISR 0-31)
    idt_set_gate(0, (uint32_t)isr0, 0x08, IDT_INTERRUPT_GATE);
    idt_set_gate(1, (uint32_t)isr1, 0x08, IDT_INTERRUPT_GATE);
    idt_set_gate(2, (uint32_t)isr2, 0x08, IDT_INTERRUPT_GATE);
    idt_set_gate(3, (uint32_t)isr3, 0x08, IDT_INTERRUPT_GATE);
    idt_set_gate(4, (uint32_t)isr4, 0x08, IDT_INTERRUPT_GATE);
    idt_set_gate(5, (uint32_t)isr5, 0x08, IDT_INTERRUPT_GATE);
    idt_set_gate(6, (uint32_t)isr6, 0x08, IDT_INTERRUPT_GATE);
    idt_set_gate(7, (uint32_t)isr7, 0x08, IDT_INTERRUPT_GATE);
    idt_set_gate(8, (uint32_t)isr8, 0x08, IDT_INTERRUPT_GATE);
    idt_set_gate(9, (uint32_t)isr9, 0x08, IDT_INTERRUPT_GATE);
    idt_set_gate(10, (uint32_t)isr10, 0x08, IDT_INTERRUPT_GATE);
    idt_set_gate(11, (uint32_t)isr11, 0x08, IDT_INTERRUPT_GATE);
    idt_set_gate(12, (uint32_t)isr12, 0x08, IDT_INTERRUPT_GATE);
    idt_set_gate(13, (uint32_t)isr13, 0x08, IDT_INTERRUPT_GATE);
    idt_set_gate(14, (uint32_t)isr14, 0x08, IDT_INTERRUPT_GATE);
    idt_set_gate(15, (uint32_t)isr15, 0x08, IDT_INTERRUPT_GATE);
    idt_set_gate(16, (uint32_t)isr16, 0x08, IDT_INTERRUPT_GATE);
    idt_set_gate(17, (uint32_t)isr17, 0x08, IDT_INTERRUPT_GATE);
    idt_set_gate(18, (uint32_t)isr18, 0x08, IDT_INTERRUPT_GATE);
    idt_set_gate(19, (uint32_t)isr19, 0x08, IDT_INTERRUPT_GATE);
    idt_set_gate(20, (uint32_t)isr20, 0x08, IDT_INTERRUPT_GATE);
    idt_set_gate(21, (uint32_t)isr21, 0x08, IDT_INTERRUPT_GATE);
    idt_set_gate(22, (uint32_t)isr22, 0x08, IDT_INTERRUPT_GATE);
    idt_set_gate(23, (uint32_t)isr23, 0x08, IDT_INTERRUPT_GATE);
    idt_set_gate(24, (uint32_t)isr24, 0x08, IDT_INTERRUPT_GATE);
    idt_set_gate(25, (uint32_t)isr25, 0x08, IDT_INTERRUPT_GATE);
    idt_set_gate(26, (uint32_t)isr26, 0x08, IDT_INTERRUPT_GATE);
    idt_set_gate(27, (uint32_t)isr27, 0x08, IDT_INTERRUPT_GATE);
    idt_set_gate(28, (uint32_t)isr28, 0x08, IDT_INTERRUPT_GATE);
    idt_set_gate(29, (uint32_t)isr29, 0x08, IDT_INTERRUPT_GATE);
    idt_set_gate(30, (uint32_t)isr30, 0x08, IDT_INTERRUPT_GATE);
    idt_set_gate(31, (uint32_t)isr31, 0x08, IDT_INTERRUPT_GATE);
    
    // Install IRQ handlers (IRQ 0-15 -> Interrupts 32-47)
    idt_set_gate(32, (uint32_t)irq0, 0x08, IDT_INTERRUPT_GATE);   // Timer
    idt_set_gate(33, (uint32_t)irq1, 0x08, IDT_INTERRUPT_GATE);   // Keyboard
    idt_set_gate(34, (uint32_t)irq2, 0x08, IDT_INTERRUPT_GATE);   // Cascade
    idt_set_gate(35, (uint32_t)irq3, 0x08, IDT_INTERRUPT_GATE);   // COM2
    idt_set_gate(36, (uint32_t)irq4, 0x08, IDT_INTERRUPT_GATE);   // COM1
    idt_set_gate(37, (uint32_t)irq5, 0x08, IDT_INTERRUPT_GATE);   // LPT2
    idt_set_gate(38, (uint32_t)irq6, 0x08, IDT_INTERRUPT_GATE);   // Floppy
    idt_set_gate(39, (uint32_t)irq7, 0x08, IDT_INTERRUPT_GATE);   // LPT1
    idt_set_gate(40, (uint32_t)irq8, 0x08, IDT_INTERRUPT_GATE);   // CMOS clock
    idt_set_gate(41, (uint32_t)irq9, 0x08, IDT_INTERRUPT_GATE);   // Free
    idt_set_gate(42, (uint32_t)irq10, 0x08, IDT_INTERRUPT_GATE);  // Free
    idt_set_gate(43, (uint32_t)irq11, 0x08, IDT_INTERRUPT_GATE);  // Free
    idt_set_gate(44, (uint32_t)irq12, 0x08, IDT_INTERRUPT_GATE);  // PS/2 mouse
    idt_set_gate(45, (uint32_t)irq13, 0x08, IDT_INTERRUPT_GATE);  // FPU
    idt_set_gate(46, (uint32_t)irq14, 0x08, IDT_INTERRUPT_GATE);  // Primary ATA
    idt_set_gate(47, (uint32_t)irq15, 0x08, IDT_INTERRUPT_GATE);  // Secondary ATA
    
    // Load IDT
    idt_load((uint32_t)&idt_pointer);
    
    // Enable timer and keyboard IRQs
    pic_unmask_irq(0);  // Timer (IRQ 0)
    pic_unmask_irq(1);  // Keyboard (IRQ 1)
    
    vga_writestring("[IDT] Interrupt Descriptor Table loaded\n");
}

void idt_set_gate(uint8_t num, uint32_t handler, uint16_t selector, uint8_t flags) {
    idt[num].offset_low = handler & 0xFFFF;
    idt[num].offset_high = (handler >> 16) & 0xFFFF;
    idt[num].selector = selector;
    idt[num].reserved = 0;
    idt[num].type_attr = flags;
}