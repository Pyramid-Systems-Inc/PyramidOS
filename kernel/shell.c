#include "shell.h"
#include "keyboard.h"
#include "string.h"
#include "pmm.h"
#include "io.h"

// Helper to access term_print from main.c
extern void term_print(const char *str, uint8_t color);
extern void term_print_hex(uint32_t n, uint8_t color);
extern void term_clear(void);

#define CMD_BUF_SIZE 128
static char cmd_buffer[CMD_BUF_SIZE];
static int cmd_idx = 0;

void shell_init(void)
{
    term_print("\nWelcome to PyramidOS Shell (KShell v1.0)\n", 0x0B); // Cyan
    term_print("Type 'help' for a list of commands.\n\n", 0x07);
    term_print("PyramidOS> ", 0x0E); // Yellow Prompt
    cmd_idx = 0;
    memset(cmd_buffer, 0, CMD_BUF_SIZE);
}

void execute_command(void)
{
    term_print("\n", 0x07); // New line after user hits enter

    if (strcmp(cmd_buffer, "help") == 0)
    {
        term_print("Available Commands:\n", 0x0F);
        term_print("  help    - Show this list\n", 0x07);
        term_print("  clear   - Clear the screen\n", 0x07);
        term_print("  mem     - Show memory statistics\n", 0x07);
        term_print("  reboot  - Restart the system\n", 0x07);
    }
    else if (strcmp(cmd_buffer, "clear") == 0)
    {
        term_clear();
    }
    else if (strcmp(cmd_buffer, "mem") == 0)
    {
        term_print("Total RAM: ", 0x07);
        term_print_hex(pmm_get_total_memory(), 0x07);
        term_print("\nFree RAM:  ", 0x07);
        term_print_hex(pmm_get_free_memory(), 0x07);
        term_print("\n", 0x07);
    }
    else if (strcmp(cmd_buffer, "reboot") == 0)
    {
        term_print("Rebooting...\n", 0x0C);
        // Pulse Keyboard Controller to reset CPU
        uint8_t good = 0x02;
        while (good & 0x02)
            good = inb(0x64);
        outb(0x64, 0xFE);
        asm volatile("hlt");
    }
    else if (strlen(cmd_buffer) > 0)
    {
        term_print("Unknown command: ", 0x0C);
        term_print(cmd_buffer, 0x0C);
        term_print("\n", 0x0C);
    }

    // Reset Prompt
    term_print("PyramidOS> ", 0x0E);
    cmd_idx = 0;
    memset(cmd_buffer, 0, CMD_BUF_SIZE);
}

void shell_run(void)
{
    while (1)
    {
        char c = keyboard_get_char();

        if (c != 0)
        {
            // Handle Enter
            if (c == '\n')
            {
                cmd_buffer[cmd_idx] = '\0'; // Null terminate
                execute_command();
            }
            // Handle Backspace
            else if (c == '\b')
            {
                if (cmd_idx > 0)
                {
                    cmd_idx--;
                    cmd_buffer[cmd_idx] = '\0';
                    term_print("\b", 0x07); // Visual backspace
                }
            }
            // Handle Regular Character
            else if (cmd_idx < CMD_BUF_SIZE - 1)
            {
                cmd_buffer[cmd_idx] = c;
                cmd_idx++;

                // Echo character to screen
                char str[2] = {c, '\0'};
                term_print(str, 0x0F);
            }
        }

        asm volatile("hlt");
    }
}