/* =============================================================================
   PyramidOS Kernel - Main Entry Point
   ============================================================================= */

#include <stdint.h>
#include "bootinfo.h"
#include "pmm.h"
#include "idt.h"
#include "vmm.h"
#include "pic.h"
#include "io.h"
#include "keyboard.h"
#include "shell.h"

// VGA Text Mode Buffer Address (0xB8000)
volatile uint16_t *vga_buffer = (uint16_t *)0xB8000;

// VGA Constants
const int VGA_COLS = 80;
const int VGA_ROWS = 25;
const uint8_t COLOR_GREEN = 0x0A;
const uint8_t COLOR_WHITE = 0x0F;
const uint8_t COLOR_RED = 0x0C;

// Global cursor position
int cursor_x = 0;
int cursor_y = 0;

void term_clear(void)
{
    for (int i = 0; i < VGA_COLS * VGA_ROWS; i++)
    {
        vga_buffer[i] = ((uint16_t)0x0F << 8) | ' ';
    }
    cursor_x = 0;
    cursor_y = 0;
}

void term_print(const char *str, uint8_t color)
{
    for (int i = 0; str[i] != '\0'; i++)
    {
        // Handle Newline
        if (str[i] == '\n')
        {
            cursor_x = 0;
            cursor_y++;
        }
        // Handle Backspace
        else if (str[i] == '\b')
        {
            if (cursor_x > 0)
            {
                cursor_x--; // Move back
                int index = (cursor_y * VGA_COLS) + cursor_x;
                vga_buffer[index] = ((uint16_t)0x0F << 8) | ' '; // Erase char
            }
        }
        // Normal Character
        else
        {
            int index = (cursor_y * VGA_COLS) + cursor_x;
            vga_buffer[index] = ((uint16_t)color << 8) | str[i];
            cursor_x++;
        }

        // Wrap Line
        if (cursor_x >= VGA_COLS)
        {
            cursor_x = 0;
            cursor_y++;
        }

        // Simple Scrolling (move to top if full)
        if (cursor_y >= VGA_ROWS)
        {
            cursor_y = 0; // Basic wrap for now
            term_clear();
        }
    }
}

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

void k_main(void)
{
    term_clear();
    term_print("PyramidOS Kernel v0.5 - IRQ Test\n", COLOR_GREEN);
    term_print("--------------------------------\n", COLOR_WHITE);

    // 1. Initialize PMM
    BootInfo *info = (BootInfo *)BOOT_INFO_ADDRESS;
    pmm_init(info);
    term_print("PMM Initialized.\n", COLOR_WHITE);

    // 2. Initialize IDT
    idt_init();

    // 3. Remap PIC
    pic_remap();
    term_print("PIC Remapped.\n", COLOR_WHITE);

    // 4. Initialize VMM
    vmm_init();

    // 5. Enable Hardware Interrupts
    // Unmask IRQ1 (Keyboard) manually because pic_remap masked everything
    outb(0x21, 0xFD); // Unmask Keyboard
    asm volatile("sti");

    // HANDOFF TO SHELL
    shell_init();
    shell_run();

    // Should never reach here
    while (1)
        asm volatile("hlt");
}