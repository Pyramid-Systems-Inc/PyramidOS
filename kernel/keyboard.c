#include "keyboard.h"
#include "io.h"
#include <stdbool.h> // We need bool types

extern void term_print(const char *str, uint8_t color);

// Buffer Configuration
#define KB_BUFFER_SIZE 256
static char kb_buffer[KB_BUFFER_SIZE];
static volatile uint16_t write_ptr = 0;
static volatile uint16_t read_ptr = 0;

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
    write_ptr = 0;
    read_ptr = 0;
}

// Helper: Add char to buffer
static void buffer_write(char c)
{
    uint16_t next = (write_ptr + 1) % KB_BUFFER_SIZE;
    if (next != read_ptr)
    { // Check if full
        kb_buffer[write_ptr] = c;
        write_ptr = next;
    }
    // If full, drop the key (simple solution)
}

// Public: Read char from buffer
char keyboard_get_char(void)
{
    // While buffer is empty...
    while (read_ptr == write_ptr)
    {
        // HALT the CPU.
        // The CPU will wake up when an Interrupt occurs (IRQ1 Keyboard or IRQ0 Timer).
        // It will handle the ISR, then return exactly here.
        // Then the loop condition is checked again.
        asm volatile("hlt");
    }

    char c = kb_buffer[read_ptr];
    read_ptr = (read_ptr + 1) % KB_BUFFER_SIZE;
    return c;
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

    // --- Handle Key Presses ---
    if (scancode < 0x80)
    {
        // Normal Arrays logic...
        if (scancode < 58)
        { // 58 is approx size of our array
            char ascii = 0;
            bool use_upper = false;

            if (shift_pressed)
                use_upper = true;

            // Simple letter check for Caps Lock
            // (Assuming standard US layout where Q=0x10, P=0x19, A=0x1E, L=0x26, Z=0x2C, M=0x32)
            // We just check the base char from set1
            char base = scancode_set1[scancode];
            if (caps_lock && base >= 'a' && base <= 'z')
            {
                use_upper = !use_upper;
            }

            if (use_upper)
            {
                ascii = scancode_set1_shifted[scancode];
            }
            else
            {
                ascii = scancode_set1[scancode];
            }

            if (ascii != 0)
            {
                // CHANGED: Write to Buffer instead of Screen
                buffer_write(ascii);
            }
        }
    }
}