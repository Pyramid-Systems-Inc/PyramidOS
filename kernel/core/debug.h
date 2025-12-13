#ifndef DEBUG_H
#define DEBUG_H

#include "idt.h" // For Registers struct

// Standard Panic (Just a message)
void panic(const char *message);

// Technical Panic (Message + CPU Registers)
void panic_with_regs(const char *message, Registers *regs);

#endif