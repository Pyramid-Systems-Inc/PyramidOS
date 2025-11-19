#include "idt.h"
#include "stdint.h"

// Access the print functions from main.c (External for now)
extern void term_print(const char* str, uint8_t color);
extern void term_print_hex(uint32_t n, uint8_t color);

// Define IDT array (256 entries)
__attribute__((aligned(0x10))) 
static IdtEntry idt[256];
static IdtPtr idt_ptr;

// Assembly helpers
extern void idt_load(uint32_t idt_ptr);

// ISR Prototypes from Assembly
extern void isr0(); extern void isr1(); extern void isr2(); extern void isr3();
extern void isr4(); extern void isr5(); extern void isr6(); extern void isr7();
extern void isr8(); extern void isr9(); extern void isr10(); extern void isr11();
extern void isr12(); extern void isr13(); extern void isr14(); extern void isr15();
extern void isr16(); extern void isr17(); extern void isr18(); extern void isr19();
extern void isr20();

void idt_set_gate(int n, uint32_t handler, uint16_t selector, uint8_t type) {
    idt[n].offset_low = handler & 0xFFFF;
    idt[n].selector = selector;
    idt[n].zero = 0;
    idt[n].type_attr = type;
    idt[n].offset_high = (handler >> 16) & 0xFFFF;
}

void idt_init(void) {
    idt_ptr.limit = sizeof(IdtEntry) * 256 - 1;
    idt_ptr.base  = (uint32_t)&idt;

    // Clear IDT
    for (int i=0; i<256; i++) {
        idt_set_gate(i, 0, 0x08, 0);
    }

    // Install Exception Handlers
    // 0x8E = Present | Ring0 | Interrupt Gate (32-bit)
    idt_set_gate(0, (uint32_t)isr0, 0x08, 0x8E);
    idt_set_gate(1, (uint32_t)isr1, 0x08, 0x8E);
    idt_set_gate(2, (uint32_t)isr2, 0x08, 0x8E);
    idt_set_gate(3, (uint32_t)isr3, 0x08, 0x8E);
    idt_set_gate(4, (uint32_t)isr4, 0x08, 0x8E);
    idt_set_gate(5, (uint32_t)isr5, 0x08, 0x8E);
    idt_set_gate(6, (uint32_t)isr6, 0x08, 0x8E);
    idt_set_gate(7, (uint32_t)isr7, 0x08, 0x8E);
    idt_set_gate(8, (uint32_t)isr8, 0x08, 0x8E);
    idt_set_gate(9, (uint32_t)isr9, 0x08, 0x8E);
    idt_set_gate(10, (uint32_t)isr10, 0x08, 0x8E);
    idt_set_gate(11, (uint32_t)isr11, 0x08, 0x8E);
    idt_set_gate(12, (uint32_t)isr12, 0x08, 0x8E);
    idt_set_gate(13, (uint32_t)isr13, 0x08, 0x8E);
    idt_set_gate(14, (uint32_t)isr14, 0x08, 0x8E);
    idt_set_gate(15, (uint32_t)isr15, 0x08, 0x8E);
    idt_set_gate(16, (uint32_t)isr16, 0x08, 0x8E);
    idt_set_gate(17, (uint32_t)isr17, 0x08, 0x8E);
    idt_set_gate(18, (uint32_t)isr18, 0x08, 0x8E);
    idt_set_gate(19, (uint32_t)isr19, 0x08, 0x8E);
    idt_set_gate(20, (uint32_t)isr20, 0x08, 0x8E);

    // Load
    idt_load((uint32_t)&idt_ptr);
    
    term_print("IDT Loaded. CPU Exceptions enabled.\n", 0x0F);
}

// Structure of the stack passed by isr_common_stub
typedef struct {
    uint32_t ds;                                     // Data segment pushed manually
    uint32_t edi, esi, ebp, esp, ebx, edx, ecx, eax; // Pushed by pusha
    uint32_t int_no, err_code;                       // Pushed by ISR stub
    uint32_t eip, cs, eflags, useresp, ss;           // Pushed by CPU
} Registers;

// The central C handler for all interrupts
void isr_handler(Registers regs) {
    term_print("\n*** INTERRUPT RECEIVED ***\n", 0x0C); // Red
    term_print("INT Number: ", 0x0F);
    term_print_hex(regs.int_no, 0x0F);
    term_print("\nError Code: ", 0x0F);
    term_print_hex(regs.err_code, 0x0F);
    term_print("\n", 0x0F);

    if (regs.int_no == 0) {
        term_print("EXCEPTION: DIVIDE BY ZERO\n", 0x0C);
    } else if (regs.int_no == 13) {
        term_print("EXCEPTION: GENERAL PROTECTION FAULT\n", 0x0C);
    } else if (regs.int_no == 14) {
        term_print("EXCEPTION: PAGE FAULT\n", 0x0C);
    }

    term_print("System Halted.\n", 0x0C);
    while(1) __asm__ volatile("cli; hlt");
}