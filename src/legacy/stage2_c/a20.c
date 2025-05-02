// Placeholder for A20 Line Handling Logic
#include "stage2.h"

#include "stage2.h"

// Function to check and enable the A20 line
void enable_a20_line(void) {
    int a20_status;
    int kbc_status;

    print_string_c("Checking A20 line status...\r\n", COLOR_NORMAL);
    a20_status = check_a20_asm();

    if (a20_status == 1) {
        print_string_c("A20 line is already enabled.\r\n", COLOR_SUCCESS);
        return;
    }

    print_string_c("A20 line is disabled. Attempting to enable...\r\n", COLOR_NORMAL);

    // Try Keyboard Controller method first
    print_string_c("Trying Keyboard Controller method...\r\n", COLOR_NORMAL);
    kbc_status = enable_a20_kbc_asm();
    if (kbc_status == 0) { // Success is 0 from assembly helper
        // Verify
        a20_status = check_a20_asm();
        if (a20_status == 1) {
            print_string_c("A20 line enabled successfully (KBC method).\r\n", COLOR_SUCCESS);
            return;
        } else {
             print_string_c("KBC method reported success, but verification failed.\r\n", COLOR_ERROR);
        }
    } else {
        print_string_c("Keyboard Controller method failed or timed out.\r\n", COLOR_NORMAL);
    }

    // Try Fast A20 method
    print_string_c("Trying Fast A20 method...\r\n", COLOR_NORMAL);
    enable_a20_fast_asm();

    // Verify again
    a20_status = check_a20_asm();
    if (a20_status == 1) {
        print_string_c("A20 line enabled successfully (Fast A20 method).\r\n", COLOR_SUCCESS);
        return;
    }

    // Both methods failed
    print_string_c("Failed to enable A20 line using available methods.\r\n", COLOR_ERROR);
}
