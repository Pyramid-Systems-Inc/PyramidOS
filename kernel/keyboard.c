#include "keyboard.h"
#include "io.h"

// External printing (temporary, until we have a full TTY driver)
extern void term_print(const char *str, uint8_t color);

// US QWERTY Scancode Set 1 (Indices 0x00 - 0x39)
// 0 = Error/Unknown
static char scancode_set1[] = {
    0, 27, '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', '\b', /* 0x00 - 0x0E */
    '\t', 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']', '\n',  /* 0x0F - 0x1C */
    0, 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', '\'', '`',          /* 0x1D - 0x29 */
    0, '\\', 'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/', 0,            /* 0x2A - 0x36 */
    '*', 0, ' '                                                              /* 0x37 - 0x39 */
};

void keyboard_init(void)
{
    // In the future, we can reset the keyboard controller here
}

void keyboard_handler(void)
{
    // 1. Read from the data port (CRITICAL: Clears the interrupt buffer)
    uint8_t scancode = inb(0x60);

    // 2. Check if this is a "Make Code" (Key Press)
    // Key Release codes have the top bit set (e.g., 0x80 + scancode)
    if (scancode < 0x80)
    {

        // 3. Bounds check and translate
        if (scancode < sizeof(scancode_set1))
        {
            char ascii = scancode_set1[scancode];

            if (ascii != 0)
            {
                char str[2] = {ascii, '\0'};
                term_print(str, 0x0F); // Print white text
            }
        }
    }
}