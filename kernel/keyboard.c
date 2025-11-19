#include "keyboard.h"
#include "io.h"
#include <stdbool.h> // We need bool types

extern void term_print(const char *str, uint8_t color);

// State variables
static bool shift_pressed = false;
static bool caps_lock = false;

// Normal characters (Scancode Set 1)
static char scancode_set1[] = {
    0, 27, '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', '\b',
    '\t', 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']', '\n',
    0, 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', '\'', '`',
    0, '\\', 'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/', 0,
    '*', 0, ' '};

// Shifted characters (Symbols and Uppercase)
// Maps 1->!, a->A, etc.
static char scancode_set1_shifted[] = {
    0, 27, '!', '@', '#', '$', '%', '^', '&', '*', '(', ')', '_', '+', '\b',
    '\t', 'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', '{', '}', '\n',
    0, 'A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', ':', '"', '~',
    0, '|', 'Z', 'X', 'C', 'V', 'B', 'N', 'M', '<', '>', '?', 0,
    '*', 0, ' '};

void keyboard_init(void)
{
    // Reset states
    shift_pressed = false;
    caps_lock = false;
}

void keyboard_handler(void)
{
    uint8_t scancode = inb(0x60);

    // --- Handle Shift Keys ---
    if (scancode == 0x2A || scancode == 0x36)
    { // Left or Right Shift Pressed
        shift_pressed = true;
        return;
    }
    if (scancode == 0xAA || scancode == 0xB6)
    { // Left or Right Shift Released
        shift_pressed = false;
        return;
    }

    // --- Handle Caps Lock ---
    if (scancode == 0x3A)
    { // Caps Lock Pressed
        caps_lock = !caps_lock;
        return;
    }

    // --- Handle Key Presses (Make Codes) ---
    // Ignore Break Codes (high bit set) for regular keys
    if (scancode < 0x80)
    {

        if (scancode < sizeof(scancode_set1))
        {
            char ascii = 0;

            // Determine which table to use
            // Logic: If Shift is held OR Caps Lock is on (but acts differently for numbers)

            bool use_upper = false;

            // Simple logic: Shift inverts case
            if (shift_pressed)
            {
                use_upper = true;
            }

            // Caps lock affects letters only
            // We will handle caps lock by checking if the char is a letter 'a'-'z'
            char normal_char = scancode_set1[scancode];

            if (caps_lock)
            {
                if (normal_char >= 'a' && normal_char <= 'z')
                {
                    // Invert the shift logic for letters
                    // Shift+Caps = Lowercase 'a'
                    // NoShift+Caps = Uppercase 'A'
                    use_upper = !use_upper;
                }
            }

            if (use_upper)
            {
                ascii = scancode_set1_shifted[scancode];
            }
            else
            {
                ascii = normal_char;
            }

            if (ascii != 0)
            {
                char str[2] = {ascii, '\0'};
                term_print(str, 0x0F);
            }
        }
    }
}