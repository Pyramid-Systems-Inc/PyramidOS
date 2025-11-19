#ifndef IDT_H
#define IDT_H

#include <stdint.h>

// --- Data Structures ---

// Structure of the stack passed by isr_common_stub (Assembly)
// CRITICAL: This matches the 'pusha' and 'push' order in idt_asm.asm
typedef struct
{
    uint32_t ds;                                     // Data segment pushed manually
    uint32_t edi, esi, ebp, esp, ebx, edx, ecx, eax; // Pushed by pusha
    uint32_t int_no, err_code;                       // Pushed by ISR stub
    uint32_t eip, cs, eflags, useresp, ss;           // Pushed by CPU
} Registers;

// --- IDT Structures ---

// IDT Gate Types
#define IDT_TASK_GATE 0x5
#define IDT_INT_GATE_16 0x6
#define IDT_TRAP_GATE_16 0x7
#define IDT_INT_GATE_32 0xE // We use this one (32-bit Interrupt)
#define IDT_TRAP_GATE_32 0xF

// The structure of an individual entry in the IDT
typedef struct __attribute__((packed))
{
    uint16_t offset_low;  // Lower 16 bits of the ISR address
    uint16_t selector;    // Kernel Code Segment Selector (0x08)
    uint8_t zero;         // Always 0
    uint8_t type_attr;    // Type and Attributes (Present, DPL, Type)
    uint16_t offset_high; // Upper 16 bits of the ISR address
} IdtEntry;

// The pointer structure given to the CPU (LIDT instruction)
typedef struct __attribute__((packed))
{
    uint16_t limit; // Size of IDT - 1
    uint32_t base;  // Linear address of the IDT array
} IdtPtr;

// --- API ---
void idt_init(void);
void idt_set_gate(int n, uint32_t handler, uint16_t selector, uint8_t type);

#endif