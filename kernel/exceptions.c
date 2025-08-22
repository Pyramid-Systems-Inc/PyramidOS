#include "idt.h"
#include "vga.h"
#include "string.h"
#include "stddef.h"

// Exception names
static const char* exception_messages[] = {
    "Division By Zero",
    "Debug",
    "Non Maskable Interrupt",
    "Breakpoint",
    "Into Detected Overflow",
    "Out of Bounds",
    "Invalid Opcode",
    "No Coprocessor",
    "Double Fault",
    "Coprocessor Segment Overrun",
    "Bad TSS",
    "Segment Not Present",
    "Stack Fault",
    "General Protection Fault",
    "Page Fault",
    "Unknown Interrupt",
    "Coprocessor Fault",
    "Alignment Check",
    "Machine Check",
    "SIMD Floating-Point Exception",
    "Virtualization Exception",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved"
};

void exception_handler(uint32_t interrupt_number, uint32_t error_code) {
    // Set error color
    vga_setcolor(vga_entry_color(VGA_COLOR_WHITE, VGA_COLOR_RED));
    
    vga_writestring("\n\n*** KERNEL PANIC ***\n");
    vga_writestring("Exception: ");
    
    if (interrupt_number < 32) {
        vga_writestring(exception_messages[interrupt_number]);
    } else {
        vga_writestring("Unknown Exception");
    }
    
    vga_writestring("\nInterrupt Number: ");
    // Simple number to string conversion
    char num_str[12];
    itoa(interrupt_number, num_str, 10);
    vga_writestring(num_str);
    
    vga_writestring("\nError Code: ");
    utoa(error_code, num_str, 16);
    vga_writestring("0x");
    vga_writestring(num_str);
    
    vga_writestring("\n\nSystem Halted.\n");
    
    // Halt the system
    __asm__ volatile("cli; hlt");
    
    // Infinite loop as backup
    for (;;) {
        __asm__ volatile("hlt");
    }
}