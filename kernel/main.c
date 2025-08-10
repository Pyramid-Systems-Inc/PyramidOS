/*
 * PyramidOS Kernel - Main Entry Point
 *
 * This is the first C function called by the bootloader's
 * 32-bit entry stub.
 */

#include "vga.h"
#include "idt.h"
#include "stddef.h"
#include "timer.h"
#include "keyboard.h"

// Simple strlen implementation
size_t strlen(const char *str)
{
    size_t len = 0;
    while (str[len])
    {
        len++;
    }
    return len;
}

// Simple itoa for converting integers to strings
void itoa(int value, char *str, int base)
{
    char *ptr = str;
    char *ptr1 = str;
    char tmp_char;
    int tmp_value;

    do
    {
        tmp_value = value;
        value /= base;
        *ptr++ = "0123456789abcdef"[tmp_value - value * base];
    } while (value);

    // Add negative sign if needed
    if (tmp_value < 0 && base == 10)
    {
        *ptr++ = '-';
    }

    *ptr-- = '\0';

    // Reverse the string
    while (ptr1 < ptr)
    {
        tmp_char = *ptr;
        *ptr-- = *ptr1;
        *ptr1++ = tmp_char;
    }
}

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

    // Initialize IDT
    idt_init();
    vga_writestring("[OK] Interrupt Descriptor Table initialized\n");

    // Initialize timer
    timer_init();

    // Initialize keyboard
    keyboard_init();

    // Enable interrupts
    __asm__ volatile("sti");
    vga_writestring("[OK] Interrupts enabled\n");

    // Display some system info
    vga_writestring("\nSystem Information:\n");
    vga_writestring("-------------------\n");
    k_printf("Kernel size: ~", 12);
    vga_writestring(" KB\n");
    k_printf("Available memory: ", 640);
    vga_writestring(" KB (estimated)\n");

    vga_setcolor(vga_entry_color(VGA_COLOR_YELLOW, VGA_COLOR_BLACK));
    vga_writestring("\n[INFO] Kernel initialization complete.\n");
    vga_writestring("[INFO] Type 'help' for available commands.\n");

    vga_setcolor(vga_entry_color(VGA_COLOR_LIGHT_GREY, VGA_COLOR_BLACK));
    vga_writestring("PyramidOS> ");

    // Command loop - wait for interrupts
    for (;;) {
        __asm__ volatile("hlt"); // Wait for interrupts
    }
}