#ifndef CPU_H
#define CPU_H

#include <stdint.h>

// Structure of the stack passed by isr_common_stub (Assembly)
// CRITICAL: This matches the 'pusha' and 'push' order in idt_asm.asm
typedef struct
{
    uint32_t ds;                                     // Data segment pushed manually
    uint32_t edi, esi, ebp, esp, ebx, edx, ecx, eax; // Pushed by pusha
    uint32_t int_no, err_code;                       // Pushed by ISR stub
    uint32_t eip, cs, eflags, useresp, ss;           // Pushed by CPU
} Registers;

/* --------------------------------------------------------------------------
 * CPU control helpers (i386)
 * Keep asm centralized and consistent across the kernel.
 * -------------------------------------------------------------------------- */
static inline void cpu_cli(void)
{
    asm volatile("cli" ::: "memory");
}

static inline void cpu_sti(void)
{
    asm volatile("sti" ::: "memory");
}

static inline void cpu_hlt(void)
{
    asm volatile("hlt");
}

/* Idle the CPU until the next interrupt (enables interrupts first). */
static inline void cpu_idle(void)
{
    asm volatile("sti\n\thlt" ::: "memory");
}

#endif
