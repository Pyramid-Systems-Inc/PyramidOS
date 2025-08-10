#include "idt.h"
#include "vga.h"

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
    itoa(error_code, num_str, 16);
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

// Simple integer to string conversion (add to kernel if not already present)
void itoa(int value, char *str, int base) {
    char *ptr = str;
    char *ptr1 = str;
    char tmp_char;
    int tmp_value;

    do {
        tmp_value = value;
        value /= base;
        *ptr++ = "0123456789abcdef"[tmp_value - value * base];
    } while (value);

    if (tmp_value < 0 && base == 10) {
        *ptr++ = '-';
    }

    *ptr-- = '\0';

    while (ptr1 < ptr) {
        tmp_char = *ptr;
        *ptr-- = *ptr1;
        *ptr1++ = tmp_char;
    }
}