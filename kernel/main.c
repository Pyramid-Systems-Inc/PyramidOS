/* =============================================================================
   PyramidOS Kernel - Main Entry Point
   ============================================================================= */

#include <stdint.h>
#include "bootinfo.h"
#include "pmm.h"
#include "idt.h"

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
void k_main(void)
{
    term_clear();
    term_print("PyramidOS Kernel v0.3 - IDT Test\n", COLOR_GREEN);
    term_print("--------------------------------\n", COLOR_WHITE);

    // 1. Initialize PMM
    BootInfo *info = (BootInfo *)BOOT_INFO_ADDRESS;
    pmm_init(info);
    term_print("PMM Initialized.\n", COLOR_WHITE);

    // 2. Initialize IDT
    idt_init();
    // Note: idt_init prints "IDT Loaded..." itself

    // 3. Trigger Crash (Divide by Zero)
    term_print("Testing Exception Handling...\n", COLOR_WHITE);
    term_print("Dividing by Zero in 3... 2... 1...\n", COLOR_WHITE);

    // Volatile forces the compiler to actually generate the DIV instruction
    // instead of optimizing it away at compile time.
    volatile int a = 0;
    volatile int b = 100 / a;

    // We should never reach here
    term_print("SURVIVED CRASH? (Error!)\n", COLOR_RED);

    while (1)
    {
        __asm__ volatile("hlt");
    }
}