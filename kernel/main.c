/*
 * PyramidOS Kernel - Main Entry Point
 *
 * This is the first C function called by the bootloader's
 * 32-bit entry stub.
 */

// Placeholder for a VGA text-mode printing function
void k_print(const char *message)
{
    // This will eventually write to video memory at 0xB8000
    // For now, this is a stub.
    (void)message; // Suppress unused parameter warning
}

// Kernel's main function
void k_main(void)
{
    k_print("Welcome to PyramidOS!");

    // Infinite loop to halt the CPU
    for (;;)
    {
        // In the future, this will be the idle loop.
    }
}