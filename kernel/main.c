/* =============================================================================
   PyramidOS Kernel - Main Entry Point (v0.6 Shell)
   ============================================================================= */

#include <stdint.h>
#include "bootinfo.h"
#include "pmm.h"
#include "idt.h"
#include "vmm.h"
#include "pic.h"
#include "io.h"
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

// Move the Blinking Hardware Cursor
void update_cursor(int x, int y)
{
    uint16_t pos = y * VGA_COLS + x;

    // Send Low Byte
    outb(0x3D4, 0x0F);
    outb(0x3D5, (uint8_t)(pos & 0xFF));

    // Send High Byte
    outb(0x3D4, 0x0E);
    outb(0x3D5, (uint8_t)((pos >> 8) & 0xFF));
}

void term_clear(void)
{
    for (int i = 0; i < VGA_COLS * VGA_ROWS; i++)
    {
        vga_buffer[i] = ((uint16_t)0x0F << 8) | ' ';
    }
    cursor_x = 0;
    cursor_y = 0;
    update_cursor(0, 0); // Reset hardware cursor
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
                cursor_x--;
                int index = (cursor_y * VGA_COLS) + cursor_x;
                vga_buffer[index] = ((uint16_t)0x0F << 8) | ' ';
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

        // Simple Scrolling (Move to top if full)
        if (cursor_y >= VGA_ROWS)
        {
            cursor_y = 0; // Basic wrap
            term_clear(); // Usually you'd scroll up, but clear is safer for now
        }
    }

    // Update the blinking cursor position after printing
    update_cursor(cursor_x, cursor_y);
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
    term_print("PyramidOS Kernel v0.6 - Interactive Shell\n", COLOR_GREEN);
    term_print("-----------------------------------------\n", COLOR_WHITE);

    // 1. Initialize PMM
    BootInfo *info = (BootInfo *)BOOT_INFO_ADDRESS;
    pmm_init(info);

    // 2. Initialize IDT
    idt_init();

    // 3. Remap PIC
    pic_remap();

    // 4. Initialize VMM
    vmm_init();

    // 5. Enable Hardware Interrupts
    outb(0x21, 0xFD); // Unmask Keyboard
    asm volatile("sti");

    // 6. Handoff to Shell
    shell_init();
    shell_run();

    while (1)
    {
        asm volatile("hlt");
    }
}