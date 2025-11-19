/* =============================================================================
   PyramidOS Kernel - Main Entry Point
   ============================================================================= */

#include <stdint.h>
#include "bootinfo.h"

// VGA Text Mode Buffer Address (0xB8000)
volatile uint16_t* vga_buffer = (uint16_t*)0xB8000;

// VGA Constants
const int VGA_COLS = 80;
const int VGA_ROWS = 25;
const uint8_t COLOR_GREEN = 0x0A;
const uint8_t COLOR_WHITE = 0x0F;
const uint8_t COLOR_RED   = 0x0C;

// Global cursor position (simple)
int cursor_x = 0;
int cursor_y = 0;

/**
 * Helper: Clear Screen
 */
void term_clear(void) {
    for (int i = 0; i < VGA_COLS * VGA_ROWS; i++) {
        vga_buffer[i] = ((uint16_t)0x0F << 8) | ' ';
    }
    cursor_x = 0;
    cursor_y = 0;
}

/**
 * Helper: Print String
 */
void term_print(const char* str, uint8_t color) {
    for (int i = 0; str[i] != '\0'; i++) {
        // Handle newline
        if (str[i] == '\n') {
            cursor_x = 0;
            cursor_y++;
        } else {
            int index = (cursor_y * VGA_COLS) + cursor_x;
            vga_buffer[index] = ((uint16_t)color << 8) | str[i];
            cursor_x++;
        }

        // Wrap
        if (cursor_x >= VGA_COLS) {
            cursor_x = 0;
            cursor_y++;
        }
    }
}

/**
 * Helper: Print Hex (32-bit)
 */
void term_print_hex(uint32_t n, uint8_t color) {
    term_print("0x", color);
    char hex_chars[] = "0123456789ABCDEF";
    for (int i = 28; i >= 0; i -= 4) {
        char c = hex_chars[(n >> i) & 0xF];
        char str[2] = {c, '\0'};
        term_print(str, color);
    }
}

/**
 * Kernel Entry Point
 */
void k_main(void) {
    term_clear();
    term_print("PyramidOS Kernel v0.1\n", COLOR_GREEN);
    term_print("---------------------\n", COLOR_WHITE);

    // 1. Access BootInfo
    BootInfo* info = (BootInfo*)BOOT_INFO_ADDRESS;

    // 2. Validate Magic
    if (info->magic != 0x54424F4F) { // "BOOT" in Little Endian
        term_print("PANIC: Invalid BootInfo Magic!\n", COLOR_RED);
        while(1) asm volatile("hlt");
    }

    term_print("BootInfo Detected.\n", COLOR_WHITE);
    term_print("Kernel Size: ", COLOR_WHITE);
    term_print_hex(info->kernel_size, COLOR_WHITE);
    term_print(" bytes\n", COLOR_WHITE);

    term_print("Memory Map Entries: ", COLOR_WHITE);
    term_print_hex(info->mmap_count, COLOR_WHITE);
    term_print("\n", COLOR_WHITE);

    // 3. Iterate Memory Map
    E820Entry* mmap = (E820Entry*)info->mmap_addr;
    
    for (uint32_t i = 0; i < info->mmap_count; i++) {
        term_print("Region ", COLOR_WHITE);
        term_print_hex(i, COLOR_WHITE);
        term_print(": Base=", COLOR_WHITE);
        term_print_hex((uint32_t)mmap[i].base, COLOR_WHITE);
        term_print(" Len=", COLOR_WHITE);
        term_print_hex((uint32_t)mmap[i].length, COLOR_WHITE);
        term_print(" Type=", COLOR_WHITE);
        
        if (mmap[i].type == 1) {
            term_print(" (USABLE)\n", COLOR_GREEN);
        } else {
            term_print(" (RESERVED)\n", COLOR_RED);
        }
    }

    while(1) {
        __asm__ volatile("hlt");
    }
}