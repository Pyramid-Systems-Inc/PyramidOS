// Placeholder for Stage 2 Main C Logic
#include "stage2.h"

// Global variable to store boot drive (passed from assembly)
unsigned char g_boot_drive;

// Main entry point for Stage 2 C code
void stage2_main(unsigned char boot_drive) {
    char command_buffer[BUFFER_SIZE];
    int i; // Declare loop variable here for C89 compatibility
    
    g_boot_drive = boot_drive; // Save boot drive globally

    // Initial setup
    clear_screen_c();
    bios_set_cursor(0, 0, 0); // Set cursor to top-left

    // Print welcome messages
    print_string_c("Pyramid Bootloader - Stage 2 (C)\r\n", COLOR_TITLE);
    print_string_c("Version 0.7 - C Refactor\r\n", COLOR_NORMAL); // Example version
    print_string_c("System ready\r\n\r\n", COLOR_SUCCESS);

    // Command loop
    while (1) {
        print_string_c("> ", COLOR_PROMPT);
        
        // Clear buffer (simple way)
        for(i=0; i<BUFFER_SIZE; ++i) { // Use declared 'i'
             command_buffer[i] = 0; 
        }
        
        read_line(command_buffer, BUFFER_SIZE);

        // Basic check if command is not empty
        if (command_buffer[0] != '\0') {
            process_command(command_buffer);
        }
    }
}
