// Placeholder for Command Processing Logic
#include "stage2.h"
#include <string.h> // For strcmp - Watcom should provide this for 16-bit

// --- Command Handlers ---

void do_help() {
    print_string_c("Available commands:\r\n", COLOR_NORMAL);
    print_string_c("  help   - Display this help text\r\n", COLOR_NORMAL);
    print_string_c("  clear  - Clear the screen\r\n", COLOR_NORMAL);
    print_string_c("  info   - Display system information\r\n", COLOR_NORMAL);
    print_string_c("  a20    - Enable A20 line\r\n", COLOR_NORMAL);
    print_string_c("  pmode  - Enter 32-bit protected mode\r\n", COLOR_NORMAL);
    print_string_c("  reboot - Reboot the system\r\n", COLOR_NORMAL);
    print_string_c("  fsinfo - Show FAT filesystem info\r\n", COLOR_NORMAL);
}

void do_clear() {
    clear_screen_c();
    bios_set_cursor(0, 0, 0); // Reset cursor
    print_string_c("Pyramid Bootloader - Stage 2 (C)\r\n", COLOR_TITLE); // Reprint title
}

void do_info() {
    // Declare variables at the top
    extern unsigned char g_boot_drive; 
    unsigned short mem_kb;
    unsigned long total_kb;
    unsigned long mem_mb;

    print_string_c("Pyramid Bootloader System Information\r\n", COLOR_NORMAL);
    print_string_c("---------------------------------\r\n", COLOR_NORMAL);
    print_string_c("Boot drive: 0x", COLOR_NORMAL);
    print_hex_word_c((unsigned short)g_boot_drive, COLOR_NORMAL);
    print_newline_c(COLOR_NORMAL);

    // Get memory size
    mem_kb = bios_get_memory_size();
    if (mem_kb == 0xFFFF) {
         print_string_c("System memory: Error detecting extended memory.\r\n", COLOR_ERROR);
    } else {
        // Simple KB to MB conversion (integer division) for display
        // Use UL suffix for constants
        total_kb = 1024UL + mem_kb; // Add 1MB base memory
        mem_mb = total_kb / 1024UL;
        // Watcom might not have long long or easy float printing, keep it simple
        print_string_c("System memory: Approx ", COLOR_NORMAL);
        // TODO: Need a simple integer to string conversion here for mem_mb
        // Placeholder: print hex KB for now
        print_hex_word_c((unsigned short)(total_kb >> 10), COLOR_NORMAL); // Rough MB
        print_string_c(" MB (", COLOR_NORMAL);
        print_hex_word_c((unsigned short)total_kb, COLOR_NORMAL);
        print_string_c(" KB total)\r\n", COLOR_NORMAL);
    }
}

void do_reboot() {
    print_string_c("Rebooting system...\r\n", COLOR_NORMAL);
    // TODO: Implement delay if needed?
    reboot_system(); // Call assembly helper - should not return
}

void do_a20_cmd() {
    enable_a20_line(); // Call function defined in a20.c
}

void do_pmode_cmd() {
    enter_protected_mode_c(); // Call function defined in pmode.c
}

void do_fsinfo() {
    display_fsinfo(); // Call function defined in fsinfo.c
}


// --- Command Dispatcher ---

// Simpler case-insensitive string compare for basic ASCII
int stricmp(const char *s1, const char *s2) {
    unsigned char c1, c2;
    while (1) {
        c1 = (unsigned char)*s1++;
        c2 = (unsigned char)*s2++;

        // Convert to lowercase
        if (c1 >= 'A' && c1 <= 'Z') {
            c1 += ('a' - 'A');
        }
        if (c2 >= 'A' && c2 <= 'Z') {
            c2 += ('a' - 'A');
        }

        // If characters differ or end of string reached
        if (c1 != c2 || c1 == '\0') {
            break; // Exit loop if different or end of string s1
        }
        // If c2 is end of string here, but c1 wasn't, they differ (handled by break)
    }
    // Return the difference between the characters that caused the loop to exit
    return (int)c1 - (int)c2;
}


void process_command(const char *command) {
    // Debug: Echo command
    print_string_c("Command received: ", COLOR_NORMAL);
    print_string_c(command, COLOR_NORMAL);
    print_newline_c(COLOR_NORMAL);

    if (stricmp(command, "help") == 0) {
        do_help();
    } else if (stricmp(command, "clear") == 0) {
        do_clear();
    } else if (stricmp(command, "info") == 0) {
        do_info();
    } else if (stricmp(command, "reboot") == 0) {
        do_reboot();
    } else if (stricmp(command, "a20") == 0) {
        do_a20_cmd();
    } else if (stricmp(command, "pmode") == 0) {
        do_pmode_cmd();
    } else if (stricmp(command, "fsinfo") == 0) {
        do_fsinfo();
    } else {
        print_string_c("Unknown command. Type \"help\".\r\n", COLOR_ERROR);
    }
}
