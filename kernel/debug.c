#include "debug.h"
#include "io.h"

// External video helpers
extern void term_print(const char *str, uint8_t color);
extern void term_print_hex(uint32_t n, uint8_t color);
extern void term_clear(void);

// Helper: Freeze the computer
static void hang(void)
{
    // Disable interrupts to stop the flicker
    asm volatile("cli");
    while (1)
    {
        asm volatile("hlt");
    }
}

void panic(const char *message)
{
    term_print("\n\n*** KERNEL PANIC ***\n", 0x0C); // Red
    term_print("Reason: ", 0x0F);
    term_print(message, 0x0F);
    term_print("\n\nSystem Halted.", 0x0C);
    hang();
}

void panic_with_regs(const char *message, Registers *regs)
{
    term_print("\n\n*** KERNEL PANIC (Exception) ***\n", 0x0C);

    term_print("Reason: ", 0x0F);
    term_print(message, 0x0F);
    term_print("\n", 0x0F);

    // Dump CPU State
    term_print("INT: 0x", 0x0E);
    term_print_hex(regs->int_no, 0x0E);
    term_print("  ERR: 0x", 0x0E);
    term_print_hex(regs->err_code, 0x0E);
    term_print("\n", 0x0F);

    term_print("EIP: 0x", 0x0E);
    term_print_hex(regs->eip, 0x0E); // Instruction Pointer (Where it crashed)
    term_print("  CS:  0x", 0x0E);
    term_print_hex(regs->cs, 0x0E);
    term_print("\n", 0x0F);

    term_print("EAX: 0x", 0x07);
    term_print_hex(regs->eax, 0x07);
    term_print("  EBX: 0x", 0x07);
    term_print_hex(regs->ebx, 0x07);
    term_print("\n", 0x0F);

    term_print("ECX: 0x", 0x07);
    term_print_hex(regs->ecx, 0x07);
    term_print("  EDX: 0x", 0x07);
    term_print_hex(regs->edx, 0x07);
    term_print("\n", 0x0F);

    term_print("ESP: 0x", 0x07);
    term_print_hex(regs->esp, 0x07);
    term_print("  EBP: 0x", 0x07);
    term_print_hex(regs->ebp, 0x07);
    term_print("\n", 0x0F);

    term_print("\nSystem Halted.", 0x0C);
    hang();
}