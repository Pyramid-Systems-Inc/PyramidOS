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

#endif
