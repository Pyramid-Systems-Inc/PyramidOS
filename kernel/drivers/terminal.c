#include "terminal.h"
#include "io.h"

#include <stddef.h>
#include <stdint.h>

#define VGA_TEXT_BUFFER_PHYS 0xB8000u
#define VGA_COLS 80u
#define VGA_ROWS 25u
#define VGA_DEFAULT_ATTR TERM_COLOR_WHITE

static volatile uint16_t *g_vga_buffer = (volatile uint16_t *)VGA_TEXT_BUFFER_PHYS;

static uint16_t g_cursor_x = 0u;
static uint16_t g_cursor_y = 0u;

static void term_update_cursor(uint16_t x, uint16_t y)
{
    uint16_t pos = (uint16_t)(y * VGA_COLS + x);

    /* VGA hardware cursor index register at 0x3D4, data register at 0x3D5. */
    outb(0x3D4u, 0x0Fu);
    outb(0x3D5u, (uint8_t)(pos & 0xFFu));

    outb(0x3D4u, 0x0Eu);
    outb(0x3D5u, (uint8_t)((pos >> 8) & 0xFFu));
}

void term_clear(void)
{
    for (uint32_t i = 0; i < (VGA_COLS * VGA_ROWS); i++)
    {
        g_vga_buffer[i] = (uint16_t)(((uint16_t)VGA_DEFAULT_ATTR << 8) | (uint16_t)' ');
    }

    g_cursor_x = 0u;
    g_cursor_y = 0u;
    term_update_cursor(g_cursor_x, g_cursor_y);
}

void term_init(void)
{
    /* For now this driver assumes VGA text mode and identity mapping for 0xB8000. */
    g_cursor_x = 0u;
    g_cursor_y = 0u;
    term_clear();
}

void term_print(const char *str, uint8_t color)
{
    if (str == NULL)
        return;

    for (uint32_t i = 0; str[i] != '\0'; i++)
    {
        char c = str[i];

        if (c == '\n')
        {
            g_cursor_x = 0u;
            g_cursor_y++;
        }
        else if (c == '\b')
        {
            if (g_cursor_x > 0u)
            {
                g_cursor_x--;
                uint32_t index = (uint32_t)g_cursor_y * VGA_COLS + (uint32_t)g_cursor_x;
                g_vga_buffer[index] = (uint16_t)(((uint16_t)VGA_DEFAULT_ATTR << 8) | (uint16_t)' ');
            }
        }
        else
        {
            uint32_t index = (uint32_t)g_cursor_y * VGA_COLS + (uint32_t)g_cursor_x;
            g_vga_buffer[index] = (uint16_t)(((uint16_t)color << 8) | (uint8_t)c);
            g_cursor_x++;
        }

        if (g_cursor_x >= VGA_COLS)
        {
            g_cursor_x = 0u;
            g_cursor_y++;
        }

        if (g_cursor_y >= VGA_ROWS)
        {
            /* Current behavior: clear and wrap. Later we can implement scrolling. */
            g_cursor_y = 0u;
            term_clear();
        }
    }

    term_update_cursor(g_cursor_x, g_cursor_y);
}

void term_print_hex(uint32_t n, uint8_t color)
{
    static const char hex_chars[] = "0123456789ABCDEF";

    term_print("0x", color);

    for (int shift = 28; shift >= 0; shift -= 4)
    {
        char c = hex_chars[(n >> (uint32_t)shift) & 0xFu];
        char tmp[2];
        tmp[0] = c;
        tmp[1] = '\0';
        term_print(tmp, color);
    }
}