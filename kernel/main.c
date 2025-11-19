/* =============================================================================
   PyramidOS Kernel - Minimal Entry (Phase 1)
   ============================================================================= */

#include <stdint.h>

// VGA Text Mode Buffer Address (0xB8000)
volatile uint16_t *vga_buffer = (uint16_t *)0xB8000;

// VGA Constants
const int VGA_COLS = 80;
const int VGA_ROWS = 25;

// Colors (Foreground | Background << 4)
// Light Green (0xA) on Black (0x0) = 0x0A
const uint8_t TERM_COLOR = 0x0A;

/**
 * Clears the screen to black.
 */
void term_clear(void)
{
    for (int col = 0; col < VGA_COLS; col++)
    {
        for (int row = 0; row < VGA_ROWS; row++)
        {
            // Calculate linear index: y * width + x
            const int index = (row * VGA_COLS) + col;
            // Write Space character (' ') with default color
            vga_buffer[index] = ((uint16_t)TERM_COLOR << 8) | ' ';
        }
    }
}

/**
 * Simple string printer.
 * Does not handle newlines/scrolling yet (Phase 2 feature).
 * @param x Column (0-79)
 * @param y Row (0-24)
 * @param str Null-terminated string
 */
void term_print(int x, int y, const char *str)
{
    int index = (y * VGA_COLS) + x;

    for (int i = 0; str[i] != '\0'; i++)
    {
        vga_buffer[index] = ((uint16_t)TERM_COLOR << 8) | str[i];
        index++;

        // Simple wrap-around safety
        if (index >= VGA_COLS * VGA_ROWS)
            break;
    }
}

/**
 * Kernel Entry Point.
 * Called by entry.asm
 */
void k_main(void)
{
    // 1. Clear the screen (removes BIOS/Bootloader text)
    term_clear();

    // 2. Print confirmation message
    term_print(0, 0, "PyramidOS Kernel Initialized (C Environment Active)");
    term_print(0, 1, "-------------------------------------------------");
    term_print(0, 2, "Stage 2 Loaded -> Protected Mode -> C Kernel");

    // 3. Halt loop (Keep CPU busy but doing nothing)
    while (1)
    {
        __asm__ volatile("hlt");
    }
}