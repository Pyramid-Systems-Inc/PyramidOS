/* =============================================================================
   PyramidOS Kernel - Main Entry Point
   ============================================================================= */

#include <stdint.h>
#include "bootinfo.h"
#include "pmm.h"
#include "idt.h"
#include "vmm.h"

// VGA Text Mode Buffer Address (0xB8000)
volatile uint16_t *vga_buffer = (uint16_t *)0xB8000;

// VGA Constants
const int VGA_COLS = 80;
const int VGA_ROWS = 25;
const uint8_t COLOR_GREEN = 0x0A;
const uint8_t COLOR_WHITE = 0x0F;
const uint8_t COLOR_RED = 0x0C;

// Global cursor position (simple)
int cursor_x = 0;
int cursor_y = 0;

/**
 * Helper: Clear Screen
 */
void term_clear(void)
{
    for (int i = 0; i < VGA_COLS * VGA_ROWS; i++)
    {
        vga_buffer[i] = ((uint16_t)0x0F << 8) | ' ';
    }
    cursor_x = 0;
    cursor_y = 0;
}

/**
 * Helper: Print String
 */
void term_print(const char *str, uint8_t color)
{
    for (int i = 0; str[i] != '\0'; i++)
    {
        // Handle newline
        if (str[i] == '\n')
        {
            cursor_x = 0;
            cursor_y++;
        }
        else
        {
            int index = (cursor_y * VGA_COLS) + cursor_x;
            vga_buffer[index] = ((uint16_t)color << 8) | str[i];
            cursor_x++;
        }

        // Wrap
        if (cursor_x >= VGA_COLS)
        {
            cursor_x = 0;
            cursor_y++;
        }
    }
}

/**
 * Helper: Print Hex (32-bit)
 */
void term_print_hex(uint32_t n, uint8_t color)
{
    term_print("0x", color);
    char hex_chars[] = "0123456789ABCDEF";
    for (int i = 28; i >= 0; i -= 4)
    {
        char c = hex_chars[(n >> i) & 0xF];
        char str[2] = {c, '\0'};
        term_print(str, color);
    }
}

/**
 * Kernel Entry Point
 */
void k_main(void) {
    term_clear();
    term_print("PyramidOS Kernel v0.4 - VMM Test\n", 0x0A);
    term_print("--------------------------------\n", 0x0F);

    // 1. PMM
    BootInfo* info = (BootInfo*)BOOT_INFO_ADDRESS;
    pmm_init(info);
    term_print("PMM OK.\n", 0x0F);

    // 2. IDT
    idt_init(); // Prints "IDT Loaded..."

    // 3. VMM (Enable Paging)
    term_print("Initializing VMM...\n", 0x0F);
    vmm_init(); // Should print "VMM Initialized. Paging ENABLED."

    // 4. Test Continued Execution
    // If paging failed, the CPU would have double-faulted or rebooted immediately 
    // after setting the CR0 bit. If we see this message, identity mapping worked.
    term_print("System is now running in Virtual Memory mode.\n", 0x0A);

    while(1) {
        __asm__ volatile("hlt");
    }
}