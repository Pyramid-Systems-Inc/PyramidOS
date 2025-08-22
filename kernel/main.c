/*
 * PyramidOS Kernel - Main Entry Point
 */

#include "vga.h"
#include "idt.h"
#include "timer.h"
#include "keyboard.h"
#include "string.h"
#include "stddef.h"

// Print a formatted message (simple version)
void k_printf(const char *format, int value)
{
    char buffer[32];
    vga_write(format);
    itoa(value, buffer, 10);
    vga_write(buffer);
}

// Kernel's main function
void k_main(void)
{
    // Write early debug message directly to VGA memory
    volatile uint16_t *vga = (volatile uint16_t*)0xB8000;
    vga[12] = 0x2F4D;  // 'M' in white on green
    vga[13] = 0x2F41;  // 'A' 
    vga[14] = 0x2F49;  // 'I'
    vga[15] = 0x2F4E;  // 'N'
    
    // Initialize VGA text mode
    vga_initialize();

    // Set a nice color scheme
    vga_setcolor(vga_entry_color(VGA_COLOR_LIGHT_GREEN, VGA_COLOR_BLACK));
    vga_writestring("================================================================================\n");
    vga_writestring("                           PyramidOS Kernel v0.1.0                             \n");
    vga_writestring("================================================================================\n\n");

    // Reset to normal colors
    vga_setcolor(vga_entry_color(VGA_COLOR_LIGHT_GREY, VGA_COLOR_BLACK));

    vga_writestring("[OK] VGA driver initialized\n");
    vga_writestring("[OK] Kernel loaded at 0x10000\n");

    // Initialize interrupt system
    idt_init();
    vga_writestring("[OK] Interrupt Descriptor Table initialized\n");
    
    // Initialize drivers
    timer_init();
    keyboard_init();
    
    // Enable interrupts
    __asm__ volatile("sti");
    vga_writestring("[OK] Interrupts enabled\n");

    // Display some system info
    vga_writestring("\nSystem Information:\n");
    vga_writestring("-------------------\n");
    vga_writestring("Kernel size: ~8 KB\n");
    vga_writestring("Available memory: 640 KB (estimated)\n");

    vga_setcolor(vga_entry_color(VGA_COLOR_YELLOW, VGA_COLOR_BLACK));
    vga_writestring("\n[INFO] Kernel initialization complete.\n");
    vga_writestring("[INFO] Full kernel running with interrupts enabled.\n");

    vga_setcolor(vga_entry_color(VGA_COLOR_LIGHT_GREY, VGA_COLOR_BLACK));
    vga_writestring("\nPyramidOS Shell - Type 'help' for commands.\n");
    vga_writestring("PyramidOS> ");

    // Main kernel loop - interrupts will handle input and timer
    for (;;) {
        __asm__ volatile("hlt");  // Halt until interrupt
    }
}