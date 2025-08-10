#include "keyboard.h"
#include "vga.h"
#include "stdint.h"

// Keyboard constants
#define KEYBOARD_DATA_PORT    0x60
#define KEYBOARD_STATUS_PORT  0x64

// Simple US QWERTY scancode to ASCII map (scancode set 1)
static const char scancode_to_ascii[] = {
    0,  27, '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', '\b',
    '\t', 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']', '\n',
    0,    'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', '\'', '`',
    0,    '\\', 'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/',
    0, '*', 0, ' '  // ... more keys can be added
};

// Shift modified characters
static const char scancode_to_ascii_shift[] = {
    0,  27, '!', '@', '#', '$', '%', '^', '&', '*', '(', ')', '_', '+', '\b',
    '\t', 'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', '{', '}', '\n',
    0,    'A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', ':', '"', '~',
    0,    '|', 'Z', 'X', 'C', 'V', 'B', 'N', 'M', '<', '>', '?',
    0, '*', 0, ' '
};

// Keyboard state
static uint8_t shift_pressed = 0;
static uint8_t ctrl_pressed = 0;
static uint8_t alt_pressed = 0;
static uint8_t caps_lock = 0;

// Simple command buffer
static char command_buffer[256];
static uint8_t command_length = 0;

void keyboard_init(void) {
    vga_writestring("[OK] Keyboard driver initialized\n");
}

void irq_keyboard_handler(void) {
    uint8_t scancode;
    
    // Read scancode from keyboard data port
    __asm__ volatile("inb %1, %0" : "=a"(scancode) : "Nd"(KEYBOARD_DATA_PORT));
    
    // Handle key release (bit 7 set)
    if (scancode & 0x80) {
        scancode &= 0x7F;  // Remove release bit
        
        // Handle modifier key releases
        switch (scancode) {
            case 0x2A:  // Left Shift
            case 0x36:  // Right Shift
                shift_pressed = 0;
                break;
            case 0x1D:  // Ctrl
                ctrl_pressed = 0;
                break;
            case 0x38:  // Alt
                alt_pressed = 0;
                break;
        }
        return;
    }
    
    // Handle key press
    switch (scancode) {
        case 0x2A:  // Left Shift
        case 0x36:  // Right Shift
            shift_pressed = 1;
            break;
        case 0x1D:  // Ctrl
            ctrl_pressed = 1;
            break;
        case 0x38:  // Alt
            alt_pressed = 1;
            break;
        case 0x3A:  // Caps Lock
            caps_lock = !caps_lock;
            break;
        case 0x0E:  // Backspace
            if (command_length > 0) {
                command_length--;
                command_buffer[command_length] = '\0';
                vga_putchar('\b');
                vga_putchar(' ');
                vga_putchar('\b');
            }
            break;
        case 0x1C:  // Enter
            command_buffer[command_length] = '\0';
            vga_putchar('\n');
            
            // Process command
            process_command(command_buffer);
            
            // Reset command buffer
            command_length = 0;
            command_buffer[0] = '\0';
            
            // Show prompt again
            vga_writestring("PyramidOS> ");
            break;
        default:
            // Convert scancode to ASCII
            if (scancode < sizeof(scancode_to_ascii)) {
                char ascii;
                
                if (shift_pressed) {
                    ascii = scancode_to_ascii_shift[scancode];
                } else {
                    ascii = scancode_to_ascii[scancode];
                    // Handle caps lock for letters
                    if (caps_lock && ascii >= 'a' && ascii <= 'z') {
                        ascii -= 32;  // Convert to uppercase
                    }
                }
                
                if (ascii != 0 && command_length < sizeof(command_buffer) - 1) {
                    command_buffer[command_length] = ascii;
                    command_length++;
                    vga_putchar(ascii);
                }
            }
            break;
    }
}

void process_command(const char* command) {
    if (command[0] == '\0') {
        return;  // Empty command
    }
    
    // Simple command processing
    if (strcmp(command, "help") == 0) {
        vga_writestring("Available commands:\n");
        vga_writestring("  help    - Show this help message\n");
        vga_writestring("  clear   - Clear the screen\n");
        vga_writestring("  uptime  - Show system uptime\n");
        vga_writestring("  reboot  - Restart the system\n");
        vga_writestring("  crash   - Test exception handling\n");
    }
    else if (strcmp(command, "clear") == 0) {
        vga_clear();
    }
    else if (strcmp(command, "uptime") == 0) {
        vga_writestring("System uptime: ");
        char time_str[16];
        itoa(timer_get_seconds(), time_str, 10);
        vga_writestring(time_str);
        vga_writestring(" seconds\n");
    }
    else if (strcmp(command, "reboot") == 0) {
        vga_writestring("Rebooting system...\n");
        // Triple fault to reboot
        __asm__ volatile("cli; hlt");
    }
    else if (strcmp(command, "crash") == 0) {
        vga_writestring("Testing exception handling...\n");
        // Trigger division by zero
        int x = 1 / 0;
        (void)x;  // Suppress unused variable warning
    }
    else {
        vga_writestring("Unknown command: ");
        vga_writestring(command);
        vga_writestring("\nType 'help' for available commands.\n");
    }
}

// Simple string comparison
int strcmp(const char* str1, const char* str2) {
    while (*str1 && (*str1 == *str2)) {
        str1++;
        str2++;
    }
    return *(unsigned char*)str1 - *(unsigned char*)str2;
}