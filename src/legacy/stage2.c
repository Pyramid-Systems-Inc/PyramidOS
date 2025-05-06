// =============================================================================
// Pyramid Bootloader - Stage 2 C Code (Minimal)
// =============================================================================

// Basic BIOS TTY Print Character function (using inline assembly or external asm helper)
// For simplicity here, let's assume an external assembly helper `bios_print_char_asm`
// void bios_print_char_asm(char c); // Needs to be defined in entry.asm or another asm file

// External assembly helper prototype (adjust name based on actual implementation)
extern void bios_print_char_asm(char c);

// Simple print string function using the helper
void print_string(const char* str) {
    while (*str) {
        bios_print_char_asm(*str);
        str++;
    }
}

// Main C entry point called from assembly (entry.asm)
void stage2_main(void) {
    // Print a startup message
    print_string("Pyramid Bootloader: Stage 2 C Entry\r\n");

    // TODO: Load kernel payload from disk (Phase 1 Goal)
    print_string("Halting system.\r\n");

    // Halt the system for now
    // Use inline assembly or an assembly helper for 'hlt'
    // Example using GCC-style inline assembly (syntax depends on compiler):
    // asm volatile ("cli; hlt");
    // For Watcom/NASM, likely need an external asm helper for hlt.
    while(1) {
        // Infinite loop as a fallback halt
    }
}
