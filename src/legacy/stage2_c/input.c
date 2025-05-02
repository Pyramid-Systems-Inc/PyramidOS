// Placeholder for Input Functions
#include "stage2.h"

// Read a line of input from the keyboard
void read_line(char *buffer, int max_len) {
    int count = 0;
    unsigned short key_info;
    char ascii_char;
    // unsigned char scan_code; // If needed

    while (count < max_len - 1) { // Leave space for null terminator
        key_info = bios_read_key();
        ascii_char = (char)(key_info & 0xFF);
        // scan_code = (unsigned char)(key_info >> 8); // If needed

        if (ascii_char == '\r') { // Enter key
            print_newline_c(COLOR_NORMAL);
            break;
        } else if (ascii_char == '\b') { // Backspace
            if (count > 0) {
                count--;
                // Echo backspace, space, backspace
                print_char_c('\b', COLOR_NORMAL);
                print_char_c(' ', COLOR_NORMAL);
                print_char_c('\b', COLOR_NORMAL);
            }
        } else if (ascii_char >= ' ' && ascii_char <= '~') { // Printable ASCII
            buffer[count++] = ascii_char;
            print_char_c(ascii_char, COLOR_NORMAL); // Echo character
        }
        // Ignore other characters (like function keys, arrows, etc.) for now
    }
    buffer[count] = '\0'; // Null-terminate the string
}
