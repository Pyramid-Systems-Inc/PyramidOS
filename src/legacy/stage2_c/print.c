// Placeholder for Printing Functions
#include "stage2.h"

// Simple clear screen using BIOS scroll
void clear_screen_c(void) {
    // AH=0x06, AL=0 (scroll all), BH=attr, CX=0, DH=24, DL=79
    bios_scroll_up(0, COLOR_NORMAL, 0, 0, 24, 79); 
}

// Print a single character
void print_char_c(char c, unsigned char color) {
    bios_print_char(c, color, 0); // Use page 0
}

// Print a null-terminated string
void print_string_c(const char *str, unsigned char color) {
    while (*str) {
        print_char_c(*str, color);
        str++;
    }
}

// Print a newline (CR+LF)
void print_newline_c(unsigned char color) {
    print_char_c('\r', color);
    print_char_c('\n', color);
}

// Print a 16-bit value in hexadecimal
void print_hex_word_c(unsigned short val, unsigned char color) {
    const char hex_digits[] = "0123456789ABCDEF";
    char buffer[5]; // 4 hex digits + null terminator
    int i;

    buffer[4] = '\0';
    for (i = 3; i >= 0; i--) {
        buffer[i] = hex_digits[val & 0x0F];
        val >>= 4;
    }
    print_string_c(buffer, color);
}
