#include "vga.h"

// Terminal state
static size_t terminal_row;
static size_t terminal_column;
static uint8_t terminal_color;
static uint16_t *terminal_buffer;

void vga_initialize(void)
{
    terminal_row = 0;
    terminal_column = 0;
    terminal_color = vga_entry_color(VGA_COLOR_LIGHT_GREY, VGA_COLOR_BLACK);
    terminal_buffer = (uint16_t *)VGA_MEMORY;

    // Clear the screen
    vga_clear();
}

void vga_clear(void)
{
    for (size_t y = 0; y < VGA_HEIGHT; y++)
    {
        for (size_t x = 0; x < VGA_WIDTH; x++)
        {
            const size_t index = y * VGA_WIDTH + x;
            terminal_buffer[index] = vga_entry(' ', terminal_color);
        }
    }
    terminal_row = 0;
    terminal_column = 0;
}

void vga_setcolor(uint8_t color)
{
    terminal_color = color;
}

void vga_scroll(void)
{
    // Move all lines up by one
    for (size_t y = 0; y < VGA_HEIGHT - 1; y++)
    {
        for (size_t x = 0; x < VGA_WIDTH; x++)
        {
            const size_t dest_index = y * VGA_WIDTH + x;
            const size_t src_index = (y + 1) * VGA_WIDTH + x;
            terminal_buffer[dest_index] = terminal_buffer[src_index];
        }
    }

    // Clear the last line
    for (size_t x = 0; x < VGA_WIDTH; x++)
    {
        const size_t index = (VGA_HEIGHT - 1) * VGA_WIDTH + x;
        terminal_buffer[index] = vga_entry(' ', terminal_color);
    }
}

void vga_putchar(char c)
{
    if (c == '\n')
    {
        terminal_column = 0;
        terminal_row++;
    }
    else if (c == '\r')
    {
        terminal_column = 0;
    }
    else if (c == '\t')
    {
        // Tab to next 4-character boundary
        terminal_column = (terminal_column + 4) & ~3;
    }
    else
    {
        const size_t index = terminal_row * VGA_WIDTH + terminal_column;
        terminal_buffer[index] = vga_entry(c, terminal_color);
        terminal_column++;
    }

    // Handle line wrap
    if (terminal_column >= VGA_WIDTH)
    {
        terminal_column = 0;
        terminal_row++;
    }

    // Handle screen scroll
    if (terminal_row >= VGA_HEIGHT)
    {
        vga_scroll();
        terminal_row = VGA_HEIGHT - 1;
    }
}

void vga_write(const char *data)
{
    for (size_t i = 0; data[i] != '\0'; i++)
    {
        vga_putchar(data[i]);
    }
}

void vga_writestring(const char *data)
{
    vga_write(data);
}

void vga_set_cursor(size_t x, size_t y)
{
    if (x < VGA_WIDTH && y < VGA_HEIGHT)
    {
        terminal_column = x;
        terminal_row = y;
    }
}